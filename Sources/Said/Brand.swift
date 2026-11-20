import AppKit
import SwiftUI

/// Said's look for its own windows (Figma "Setup window v2: branded"): the icon's
/// blue as the accent, soft cards, blue pill buttons. Every colour follows light and dark mode.
enum Brand {
    static let blue = Color(red: 0.172, green: 0.294, blue: 1)
    /// Blue text and icons; lighter in dark mode so it stays readable.
    static let blueText = adaptive(light: NSColor(srgbRed: 0.172, green: 0.294, blue: 1, alpha: 1),
                                   dark: NSColor(srgbRed: 0.56, green: 0.63, blue: 1, alpha: 1))
    static let tint = adaptive(light: NSColor(srgbRed: 0.172, green: 0.294, blue: 1, alpha: 0.1),
                               dark: NSColor(srgbRed: 0.172, green: 0.294, blue: 1, alpha: 0.22))
    static let background = adaptive(light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.985, alpha: 1),
                                     dark: NSColor(srgbRed: 0.125, green: 0.125, blue: 0.135, alpha: 1))
    static let card = adaptive(light: .white, dark: NSColor(white: 1, alpha: 0.05))
    static let cardStroke = adaptive(light: NSColor(white: 0, alpha: 0.07), dark: NSColor(white: 1, alpha: 0.08))
    static let field = adaptive(light: .white, dark: NSColor(white: 1, alpha: 0.06))
    static let fieldStroke = adaptive(light: NSColor(white: 0, alpha: 0.12), dark: NSColor(white: 1, alpha: 0.12))
    static let track = adaptive(light: NSColor(white: 0, alpha: 0.1), dark: NSColor(white: 1, alpha: 0.1))

    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// A window whose content runs up under the traffic lights, with no title text.
    static func window(title: String, content: NSView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: content.fittingSize),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.125, green: 0.125, blue: 0.135, alpha: 1)
                : NSColor(srgbRed: 0.98, green: 0.98, blue: 0.985, alpha: 1)
        }
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// Small blue pill, for actions inside a row.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Brand.blueText)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Brand.tint))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Solid blue pill for the main action of a window.
struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryPill(configuration: configuration)
    }

    private struct PrimaryPill: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .background(Capsule().fill(Brand.blue.opacity(isEnabled ? 1 : 0.35)))
                .opacity(configuration.isPressed ? 0.8 : 1)
                .contentShape(Capsule())
        }
    }
}

/// Rounded card that groups rows.
struct BrandCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.cardStroke, lineWidth: 0.5))
    }
}

/// Blue tick in a filled circle.
struct BrandCheck: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(.white, Brand.blue)
    }
}

/// Thin blue progress bar.
struct BrandProgress: View {
    let fraction: Double
    var width: CGFloat = 120

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Brand.track)
            Capsule().fill(Brand.blue).frame(width: max(5, width * min(1, max(0, fraction))))
        }
        .frame(width: width, height: 5)
    }
}

extension View {
    /// The rounded box Said draws around text fields.
    func brandFieldBox() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Brand.field))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Brand.fieldStroke, lineWidth: 0.5))
    }
}

/// Text field with Said's rounded look; outlined in blue once it has text.
struct BrandField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Brand.field))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(text.isEmpty ? Brand.fieldStroke : Brand.blue.opacity(0.7), lineWidth: text.isEmpty ? 0.5 : 1.5))
    }
}
