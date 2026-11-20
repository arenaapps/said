import AppKit
import AVFoundation
import os

/// Ties the pieces together: hold Fn → record → whisper → (Claude) → paste.
/// While dictating, a pill at the bottom of the screen shows it's listening,
/// then writing (Figma sketch v1, 20 Nov 2026).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State { case loading, idle, recording, working }

    private let log = Logger(subsystem: "com.arenaapps.said", category: "dictation")
    private let hotkey = Hotkey()
    private let recorder = Recorder()
    private let transcriber = Transcriber()
    private let indicator = Indicator()
    private let setup = Setup()
    private let preferences = Preferences()
    private lazy var saidWindow = SaidWindow(setup: setup, preferences: preferences)
    private var levelTimer: Timer?
    private let whisperQueue = DispatchQueue(label: "com.arenaapps.said.whisper", qos: .userInitiated)

    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let timingLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let tidyItem = NSMenuItem(title: "Tidy with Claude", action: #selector(toggleTidy), keyEquivalent: "")

    private var state: State = .loading { didSet { refresh() } }
    private var pressedAt = Date()
    private var problem: String?
    private var session: LiveSession?

    private var tidyEnabled: Bool {
        get { Preferences.tidyPreference }
        set { UserDefaults.standard.set(newValue, forKey: Preferences.tidyKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        setup.onModelReady = { [weak self] in self?.loadModel() }
        saidWindow.onEditWordList = { [weak self] in self?.editVocabulary() }
        preferences.onTidyChanged = { [weak self] in self?.refresh() }
        indicator.onOpenSettings = {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
        startHotkey()
        loadModel()
        openSetupIfNeeded()
        // `Said --open setup|general|claude` opens the window on that tab straight away, for checking the layout.
        if let i = CommandLine.arguments.firstIndex(of: "--open"), i + 1 < CommandLine.arguments.count {
            saidWindow.show(SaidWindow.Tab(rawValue: CommandLine.arguments[i + 1].capitalized) ?? .setup)
        }
    }

    // MARK: Setup

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        statusLine.isEnabled = false
        timingLine.isEnabled = false
        timingLine.isHidden = true
        tidyItem.target = self
        let settingsItem = NSMenuItem(title: "Said…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        // When something is missing the status line says what, and clicking it opens setup.
        statusLine.action = #selector(openSetup)
        statusLine.target = self
        menu.autoenablesItems = false
        menu.addItem(statusLine)
        menu.addItem(timingLine)
        menu.addItem(.separator())
        menu.addItem(tidyItem)
        let words = NSMenuItem(title: "Edit Word List…", action: #selector(editVocabulary), keyEquivalent: "")
        words.target = self
        menu.addItem(words)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Said", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refresh()
    }

    /// First launch, or something Said can't work without is missing.
    /// Opens the Said window on Setup when something it can't work without is missing.
    private func openSetupIfNeeded() {
        setup.refresh()
        if setup.essentialsMissing { saidWindow.show(.setup) }
    }

    private func startHotkey() {
        Trace.log("permissions: input monitoring \(CGPreflightListenEventAccess()), accessibility \(AXIsProcessTrusted()), mic \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
        hotkey.onPress = { [weak self] in self?.begin() }
        hotkey.onRelease = { [weak self] in self?.finish() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        if hotkey.start() { return }
        problem = "Allow Said in Input Monitoring…"
        refresh()
        // Keep trying until the permission is granted.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, self.hotkey.start() else { return }
            timer.invalidate()
            self.problem = nil
            self.refresh()
        }
    }

    private func loadModel() {
        guard let path = Transcriber.defaultModelPath() else {
            problem = "Downloading the speech model…"
            refresh()
            return
        }
        if problem?.hasPrefix("Downloading") == true { problem = nil }
        whisperQueue.async {
            let ok = self.transcriber.load(path: path)
            Trace.log("model: \((path as NSString).lastPathComponent) \(ok ? "loaded" : "failed to load")")
            DispatchQueue.main.async {
                if !ok { self.problem = "Speech model failed to load" }
                self.state = .idle
            }
        }
    }

    // MARK: Dictation

    private func begin() {
        Trace.log("begin: state \(state), problem \(problem ?? "none"), mic \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue), accessibility \(AXIsProcessTrusted())")
        guard state == .idle, problem == nil else { return }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            // Without access macOS hands over silence, so say so instead of failing quietly.
            log.error("microphone not allowed")
            problem = "Allow Said to use the Microphone…"
            refresh()
            indicator.show(.permission("Said needs the microphone"))
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { self.problem = nil; self.refresh() }
                }
            }
            return
        }
        do {
            try recorder.start()
            pressedAt = Date()
            state = .recording
            let session = LiveSession(transcriber: transcriber, queue: whisperQueue,
                                      vocabulary: Vocabulary.load()) { [recorder] in recorder.samples(from: $0) }
            session.start()
            self.session = session
            indicator.show(.listening)
            startLevels()
        } catch {
            log.error("mic failed: \(error.localizedDescription, privacy: .public)")
            problem = "Microphone unavailable"
            refresh()
        }
    }

    private func cancel() {
        guard state == .recording else { return }
        stopLevels()
        indicator.hide()
        _ = recorder.stop()
        session?.cancel()
        session = nil
        state = .idle
    }

    private func finish() {
        guard state == .recording, let session else { return }
        self.session = nil
        stopLevels()
        let samples = recorder.stop()
        let releasedAt = Date()
        let seconds = Double(samples.count) / Recorder.sampleRate
        Trace.log(String(format: "finish: %.2f s of audio, level %.4f", seconds, Speech.rms(samples)))
        guard releasedAt.timeIntervalSince(pressedAt) >= Speech.minimumSeconds, !Speech.isSilent(samples) else {
            session.cancel()
            log.info("skipped: \(seconds, privacy: .public) s, level \(Speech.rms(samples), privacy: .public)")
            timingLine.title = String(format: "Last: skipped, too short or too quiet (%.1f s)", seconds)
            timingLine.isHidden = false
            state = .idle
            indicator.show(.message("Didn't catch that"))
            return
        }
        state = .working
        indicator.show(.writing)
        let tidy = tidyEnabled
        let vocabulary = Vocabulary.load()
        LastRecording.save(samples)

        session.finish(all: samples) { raw, chunks in
            // Time spent after the key was let go, which is what the user waits for.
            let speechTime = Date().timeIntervalSince(releasedAt)
            Trace.log(String(format: "speech: %d characters, %d chunks, %.2f s after release", raw.count, chunks, speechTime))
            Task {
                var text = raw
                var tidyTime: TimeInterval?
                if tidy, !raw.isEmpty, let key = Tidier.apiKey() {
                    let t1 = Date()
                    do {
                        text = try await Tidier().tidy(raw, apiKey: key, vocabulary: vocabulary)
                    } catch {
                        self.log.error("tidy failed, pasting raw: \(String(describing: error), privacy: .public)")
                    }
                    tidyTime = Date().timeIntervalSince(t1)
                }
                let finalText = text
                let finalTidyTime = tidyTime
                await MainActor.run {
                    Trace.log("paste: \(finalText.count) characters, tidy \(finalTidyTime.map { String(format: "%.2f s", $0) } ?? "off")")
                    self.indicator.hide()
                    if finalText.isEmpty {
                        self.indicator.show(.message("Didn't catch that"))
                    } else {
                        Paster.paste(finalText + " ")
                    }
                    self.showTiming(audio: seconds, speech: speechTime, tidy: finalTidyTime)
                    self.state = .idle
                }
            }
        }
    }

    /// Feeds the pill's bars about 20 times a second while recording.
    private func startLevels() {
        levelTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let level = Speech.barLevel(self.recorder.recentLevel())
            self.indicator.push(level: level, seconds: Int(Date().timeIntervalSince(self.pressedAt)))
        }
        RunLoop.main.add(timer, forMode: .common)
        levelTimer = timer
    }

    private func stopLevels() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func showTiming(audio: Double, speech: Double, tidy: Double?) {
        var line = String(format: "Last: %.1f s of audio, speech %.1f s", audio, speech)
        if let tidy { line += String(format: ", tidy %.1f s", tidy) }
        timingLine.title = line
        timingLine.isHidden = false
        log.info("\(line, privacy: .public)")
    }

    // MARK: Menu

    @objc private func editVocabulary() {
        _ = Vocabulary.load()
        NSWorkspace.shared.open(Vocabulary.fileURL)
    }

    @objc private func openSettings() { saidWindow.show() }
    @objc private func openSetup() { saidWindow.show(.setup) }

    @objc private func toggleTidy() {
        tidyEnabled.toggle()
        refresh()
    }

    private func refresh() {
        tidyItem.state = tidyEnabled ? .on : .off
        let icon: NSImage
        if let problem {
            statusLine.title = problem
            statusLine.isEnabled = true
            icon = MenuIcons.problem
        } else {
            switch state {
            case .loading: statusLine.isEnabled = false; statusLine.title = "Loading speech model…"; icon = MenuIcons.writing
            case .idle: statusLine.isEnabled = false; statusLine.title = "Hold Fn to dictate"; icon = MenuIcons.ready
            case .recording: statusLine.isEnabled = false; statusLine.title = "Listening…"; icon = MenuIcons.listening
            case .working: statusLine.isEnabled = false; statusLine.title = "Writing…"; icon = MenuIcons.writing
            }
        }
        statusItem?.button?.image = icon
    }
}
