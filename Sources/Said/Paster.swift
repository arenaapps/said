import AppKit
import CoreGraphics

/// Types text into whatever app has focus by putting it on the clipboard,
/// pressing Cmd+V, then putting back whatever was on the clipboard before.
enum Paster {
    private static let vKey: CGKeyCode = 9
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func paste(_ text: String) {
        let board = NSPasteboard.general
        let saved = snapshot(board)

        board.clearContents()
        board.setString(text, forType: .string)
        // Tells clipboard managers to ignore this entry.
        board.setData(Data(), forType: transientType)
        let ourChange = board.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        usleep(5_000)
        up?.post(tap: .cghidEventTap)

        // Give the app time to read the clipboard, then restore it, unless the
        // user has copied something new in the meantime.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard board.changeCount == ourChange else { return }
            board.clearContents()
            if !saved.isEmpty { board.writeObjects(saved) }
        }
    }

    private static func snapshot(_ board: NSPasteboard) -> [NSPasteboardItem] {
        (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }
}
