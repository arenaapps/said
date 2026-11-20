import AppKit
import CoreGraphics

/// Watches the Fn (Globe) key system-wide. Holding it down starts a dictation,
/// letting go ends it. If another key is pressed while Fn is held (Fn+arrow,
/// Fn+Delete and so on), the dictation is cancelled so normal shortcuts still work.
final class Hotkey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var onCancel: () -> Void = {}

    private var tap: CFMachPort?
    private var fnDown = false
    private var usedAsModifier = false

    private static let fnKeyCode: Int64 = 63

    var isRunning: Bool { tap != nil }

    /// Returns false until the user grants Input Monitoring.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
                me.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else { Trace.log("hotkey: tap not allowed yet"); return false }
        Trace.log("hotkey: listening")
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Trace.log("hotkey: listener enabled \(CGEvent.tapIsEnabled(tap: tap))")
        }
        return true
    }

    private var seen = 0

    private func handle(type: CGEventType, event: CGEvent) {
        if seen < 30 { seen += 1; Trace.log("event: type \(type.rawValue)") }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it ever looks stuck; switch it back on.
            Trace.log("hotkey: macOS switched the listener off (\(type.rawValue)), switching back on")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            Trace.log("key: flags changed, keycode \(event.getIntegerValueField(.keyboardEventKeycode)), fn \(event.flags.contains(.maskSecondaryFn))")
            guard event.getIntegerValueField(.keyboardEventKeycode) == Hotkey.fnKeyCode else { return }
            let down = event.flags.contains(.maskSecondaryFn)
            if down && !fnDown {
                fnDown = true
                usedAsModifier = false
                DispatchQueue.main.async { self.onPress() }
            } else if !down && fnDown {
                fnDown = false
                if !usedAsModifier { DispatchQueue.main.async { self.onRelease() } }
            }
        case .keyDown:
            if fnDown && !usedAsModifier {
                usedAsModifier = true
                Trace.log("key: other key while Fn held, cancelling")
                DispatchQueue.main.async { self.onCancel() }
            }
        default:
            break
        }
    }
}
