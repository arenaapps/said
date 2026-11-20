import AppKit
import AVFoundation
import SwiftUI

/// What Said needs before it can work, for the Setup tab of the Said window:
/// three permissions, the Fn key setting and the speech model. The model
/// download lives here, so it carries on if the window is closed.
final class Setup: ObservableObject {
    @Published var mic = false
    @Published var input = false
    @Published var access = false
    @Published var fn = false
    @Published var model = false
    @Published var received: Int64 = 0
    @Published var total: Int64 = ModelStore.expectedBytes
    @Published var downloading = false
    @Published var downloadFailed = false
    @Published var openedKeyboardSettings = false
    @Published var fnKnown = true
    @Published var practice = ""

    /// Called once the model has finished downloading.
    var onModelReady: (() -> Void)?

    private let download = ModelDownload()

    private static let fnConfirmedKey = "fnKeyConfirmed"

    /// Microphone, the two privacy settings and the model. Without these Said can't work at all.
    var essentialsMissing: Bool { !(mic && input && access && model) }
    var allDone: Bool { mic && input && access && fn && model }
    /// How many rows still need doing, shown on the Setup tab.
    var remaining: Int { [mic, input, access, fn, model].filter { !$0 }.count }

    init() {
        download.onProgress = { [weak self] received, total in
            self?.received = received
            self?.total = total
        }
        download.onFinish = { [weak self] error in
            guard let self else { return }
            self.downloading = false
            self.downloadFailed = error != nil
            self.refresh()
            if error == nil { self.onModelReady?() }
        }
        refresh()
    }

    func refresh() {
        mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        input = CGPreflightListenEventAccess()
        access = AXIsProcessTrusted()
        model = ModelStore.isInstalled
        let setting = Self.fnDoesNothing()
        fnKnown = setting != nil
        fn = setting ?? UserDefaults.standard.bool(forKey: Self.fnConfirmedKey)
    }

    /// Reads System Settings › Keyboard › "Press fn key to". nil means macOS has never saved a choice.
    static func fnDoesNothing() -> Bool? {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        guard let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? Int else { return nil }
        return value == 0
    }

    func startDownloadIfNeeded() {
        guard !ModelStore.isInstalled, !download.isRunning else { return }
        downloading = true
        downloadFailed = false
        received = 0
        download.start()
    }

    // MARK: Actions

    func allowMic() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in DispatchQueue.main.async { self.refresh() } }
        } else {
            openPrivacy("Privacy_Microphone")
        }
    }

    func openInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openPrivacy("Privacy_ListenEvent")
    }

    func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }

    func openKeyboardSettings() {
        openedKeyboardSettings = true
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    /// For Macs where macOS hasn't stored the Fn setting, so Said can't read it.
    func confirmFn() {
        UserDefaults.standard.set(true, forKey: Self.fnConfirmedKey)
        refresh()
    }

    private func openPrivacy(_ anchor: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }
}
