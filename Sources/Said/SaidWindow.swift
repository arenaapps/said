import AppKit
import SwiftUI

/// The one Said window (Figma "Said window v3: one window, three tabs"):
/// Setup, General and Claude. First launch opens it on Setup.
final class SaidWindow: ObservableObject {
    enum Tab: String, CaseIterable { case setup = "Setup", general = "General", claude = "Claude" }

    @Published var tab: Tab = .setup {
        didSet { if tab != oldValue { DispatchQueue.main.async { self.fitToContent(animate: true) } } }
    }

    let setup: Setup
    let preferences: Preferences
    var onEditWordList: (() -> Void)?

    private var window: NSWindow?
    private var hosting: NSHostingController<PinnedToTop>?
    private var timer: Timer?

    init(setup: Setup, preferences: Preferences) {
        self.setup = setup
        self.preferences = preferences
    }

    func show(_ tab: Tab? = nil) {
        setup.refresh()
        setup.startDownloadIfNeeded()
        preferences.refresh()
        if let tab { self.tab = tab }
        if window == nil {
            let hosting = NSHostingController(rootView: PinnedToTop(content: content))
            hosting.sizingOptions = []
            window = Brand.window(title: "Said", content: hosting.view)
            window?.contentViewController = hosting
            self.hosting = hosting
        }
        fitToContent(animate: false)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        // Coming back from System Settings ticks the row straight away.
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.window?.isVisible == true { self.setup.refresh() } else { self.timer?.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private var content: SaidView { SaidView(window: self, setup: setup, preferences: preferences) }

    /// Resizes the window to the current tab, keeping its top edge where it is. The content is
    /// pinned to the top, so while the window grows or shrinks only the bottom edge moves.
    func fitToContent(animate: Bool) {
        guard let window, hosting != nil else { return }
        // Measured on its own, because the window's view always fills whatever size the window is.
        let height = NSHostingController(rootView: content).sizeThatFits(in: NSSize(width: 520, height: 2000)).height
        let content = NSSize(width: 520, height: min(height, 2000))
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: animate && window.isVisible)
    }
}

/// Keeps the Said view at the top of the window while it resizes, instead of centred.
struct PinnedToTop: View {
    let content: SaidView

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Brand.background)
            .ignoresSafeArea()
    }
}

struct SaidView: View {
    @ObservedObject var window: SaidWindow
    @ObservedObject var setup: Setup
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .padding(-4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Said").font(.system(size: 20, weight: .bold))
                    Text("Hold Fn, talk, let go.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            TabBar(selection: $window.tab, remaining: setup.remaining)

            switch window.tab {
            case .setup: SetupTab(setup: setup)
            case .general: GeneralTab(preferences: preferences) { window.onEditWordList?() }
            case .claude: ClaudeTab(preferences: preferences)
            }
        }
        .buttonStyle(PillButtonStyle())
        .focusEffectDisabled()
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 520, alignment: .top)
        .background(Brand.background)
        // The content already leaves room for the traffic lights, so skip the title bar's safe area.
        .ignoresSafeArea()
        .onChange(of: setup.downloadFailed) { window.fitToContent(animate: false) }
    }
}

/// Pill-shaped tabs; the selected one is filled blue. Setup shows what's left, then a tick.
private struct TabBar: View {
    @Binding var selection: SaidWindow.Tab
    let remaining: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SaidWindow.Tab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button { selection = tab } label: {
                    HStack(spacing: 6) {
                        Text(tab.rawValue).font(.system(size: 13, weight: .semibold))
                        if tab == .setup {
                            if remaining > 0 {
                                Text("\(remaining)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(selected ? Color.white.opacity(0.25) : Brand.blue))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(selected ? Color.white : Brand.blueText)
                            }
                        }
                    }
                    .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(selected ? Brand.blue : Color.clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Brand.track.opacity(0.65)))
    }
}

// MARK: Setup

private struct SetupTab: View {
    @ObservedObject var setup: Setup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandCard {
                SetupRow(icon: "mic", title: "Microphone", detail: "So Said can hear you", done: setup.mic) {
                    Button("Allow") { setup.allowMic() }
                }
                CardDivider()
                SetupRow(icon: "keyboard", title: "Input Monitoring", detail: "So Said notices when you hold Fn", done: setup.input) {
                    Button("Open Settings") { setup.openInputMonitoring() }
                }
                CardDivider()
                SetupRow(icon: "doc.on.clipboard", title: "Accessibility", detail: "So Said can paste the text for you", done: setup.access) {
                    Button("Open Settings") { setup.openAccessibility() }
                }
                CardDivider()
                SetupRow(icon: "globe", title: "Fn key", detail: "Set “Press 🌐 key to” to Do Nothing", done: setup.fn) {
                    if setup.openedKeyboardSettings && !setup.fnKnown {
                        Button("It's set") { setup.confirmFn() }
                    } else {
                        Button("Open Keyboard Settings") { setup.openKeyboardSettings() }
                    }
                }
                CardDivider()
                SetupRow(icon: "arrow.down.to.line", title: "Speech model",
                         detail: setup.downloadFailed ? "Couldn't download it. Check your internet connection."
                                                      : "Runs on this Mac, so audio never leaves it",
                         done: setup.model) {
                    if setup.downloadFailed {
                        Button("Try Again") { setup.startDownloadIfNeeded() }
                    } else {
                        VStack(alignment: .trailing, spacing: 4) {
                            BrandProgress(fraction: Double(setup.received) / Double(max(setup.total, 1)))
                            Text("\(setup.received / 1_048_576) of \(setup.total / 1_048_576) MB")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try it").font(.system(size: 13, weight: .semibold))
                BrandField(placeholder: "Hold Fn and say something. It'll appear here.", text: $setup.practice)
            }
            .padding(.top, 4)
        }
    }
}

private struct SetupRow<Action: View>: View {
    let icon: String
    let title: String
    let detail: String
    let done: Bool
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Brand.blueText)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Brand.tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if done { BrandCheck() } else { action().fixedSize() }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
    }
}

// MARK: General and Claude

private struct GeneralTab: View {
    @ObservedObject var preferences: Preferences
    let editWordList: () -> Void
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandCard {
                SettingsRow(title: "Open Said when you log in") {
                    BrandSwitch(isOn: preferences.openAtLogin) { preferences.setOpenAtLogin($0) }
                }
            }
            BrandCard {
                SettingsRow(title: "Speech model", detail: "Balanced (small.en, 466 MB). Runs on this Mac.") { EmptyView() }
                CardDivider()
                SettingsRow(title: "Word list", detail: "Names and words Said should spell your way.") {
                    Button("Edit…", action: editWordList)
                }
            }
            if !version.isEmpty {
                Text("Version \(version)").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }
}

private struct ClaudeTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        BrandCard {
            SettingsRow(title: "Tidy with Claude",
                        detail: "Takes out filler words and stutters, and fixes names from your word list. Only the text is sent, never your audio.") {
                BrandSwitch(isOn: preferences.tidy && preferences.hasKey) { preferences.setTidy($0) }
                    .disabled(!preferences.hasKey)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Anthropic API key").font(.system(size: 12, weight: .medium)).foregroundStyle(.primary.opacity(0.8))
                HStack(spacing: 8) {
                    if preferences.editingKey {
                        SecureField("Paste your key", text: $preferences.keyDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .brandFieldBox()
                            .onSubmit { preferences.saveKey() }
                        Button("Save") { preferences.saveKey() }
                            .disabled(preferences.keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Text("sk-ant-…  saved")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .brandFieldBox()
                        Button("Replace") { preferences.editingKey = true }
                    }
                }
                Text("Stored in your Keychain. Get a key at console.anthropic.com. Without one, Said pastes exactly what it heard.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 330, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing().fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct BrandSwitch: View {
    let isOn: Bool
    let set: (Bool) -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: set))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(Brand.blue)
    }
}

/// Full-width hairline between rows in a card.
private struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Brand.cardStroke).frame(height: 0.5)
    }
}
