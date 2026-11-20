import Foundation
import ServiceManagement

/// The choices on the General and Claude tabs: open at login, tidying and the API key.
final class Preferences: ObservableObject {
    @Published var openAtLogin = false
    @Published var hasKey = false
    @Published var editingKey = false
    @Published var keyDraft = ""
    @Published var tidy = true

    /// Lets the menu bar's Tidy item stay in step.
    var onTidyChanged: (() -> Void)?

    static let tidyKey = "tidyWithClaude"
    static var tidyPreference: Bool {
        UserDefaults.standard.object(forKey: tidyKey) as? Bool ?? true
    }

    func refresh() {
        openAtLogin = SMAppService.mainApp.status == .enabled
        hasKey = Tidier.apiKey() != nil
        editingKey = !hasKey
        keyDraft = ""
        tidy = Self.tidyPreference
    }

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Trace.log("open at login: \(error.localizedDescription)")
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setTidy(_ on: Bool) {
        tidy = on
        UserDefaults.standard.set(on, forKey: Self.tidyKey)
        onTidyChanged?()
    }

    func saveKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, Tidier.saveAPIKey(key) else { return }
        keyDraft = ""
        hasKey = true
        editingKey = false
        setTidy(true)
    }
}
