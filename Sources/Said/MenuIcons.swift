import AppKit

/// Menu bar symbols, drawn on one line weight as template images so macOS
/// tints them for light and dark menu bars. Coordinates are a 16 pt square, y down.
enum MenuIcons {
    static let ready = make { strokeBars([(2, 6.5, 9.5), (5, 4, 12), (8, 2, 14), (11, 5, 11), (14, 7, 9)]) }

    static let listening = make {
        NSBezierPath(roundedRect: NSRect(x: 0.5, y: 0.5, width: 15, height: 15), xRadius: 4, yRadius: 4).fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        strokeBars([(4, 6.5, 9.5), (6.7, 4.5, 11.5), (9.3, 3.5, 12.5), (12, 6, 10)])
    }

    static let writing = make {
        NSColor.black.withAlphaComponent(0.45).setStroke()
        line(from: NSPoint(x: 2, y: 8), to: NSPoint(x: 14, y: 8))
        NSColor.black.setStroke()
        line(from: NSPoint(x: 2, y: 8), to: NSPoint(x: 8, y: 8))
    }

    static let problem = make {
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: 8, y: 2))
        triangle.line(to: NSPoint(x: 14.5, y: 13.5))
        triangle.line(to: NSPoint(x: 1.5, y: 13.5))
        triangle.close()
        triangle.lineWidth = 1.6
        triangle.lineJoinStyle = .round
        triangle.stroke()
        strokeBars([(8, 6.5, 9.5), (8, 11.6, 11.7)])
    }

    private static func make(_ draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.set()
            draw()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Said"
        return image
    }

    private static func strokeBars(_ bars: [(x: CGFloat, top: CGFloat, bottom: CGFloat)]) {
        for bar in bars { line(from: NSPoint(x: bar.x, y: bar.top), to: NSPoint(x: bar.x, y: bar.bottom)) }
    }

    private static func line(from a: NSPoint, to b: NSPoint) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        path.stroke()
    }
}
