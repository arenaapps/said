import AppKit
import SwiftUI

/// The dark pill at the bottom of the screen that shows Said is listening,
/// then writing. It floats over every app and space, never takes focus, and
/// lets clicks through except on its Open Settings button.
final class Indicator {
    enum Mode: Equatable {
        case hidden
        case listening
        case writing
        case message(String)
        case permission(String)
    }

    final class Model: ObservableObject {
        @Published var mode: Mode = .hidden
        @Published var levels: [CGFloat] = Array(repeating: 0, count: Indicator.barCount)
        @Published var seconds = 0
    }

    static let barCount = 9
    static let size = NSSize(width: 460, height: 84)

    let model = Model()
    var onOpenSettings: (() -> Void)?
    private var panel: NSPanel?
    private var hideTimer: Timer?

    /// Shows the pill in a mode. Messages fade out by themselves.
    func show(_ mode: Mode) {
        hideTimer?.invalidate()
        if mode == .listening {
            model.levels = Array(repeating: 0, count: Self.barCount)
            model.seconds = 0
        }
        model.mode = mode
        let panel = self.panel ?? makePanel()
        panel.ignoresMouseEvents = !(mode.isPermission)
        place(panel)
        if !panel.isVisible || panel.alphaValue < 1 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        }
        switch mode {
        case .message: hide(after: 1.5)
        case .permission: hide(after: 6)
        default: break
        }
    }

    func hide(after delay: TimeInterval = 0) {
        hideTimer?.invalidate()
        guard delay > 0 else { fadeOut(); return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.fadeOut() }
    }

    /// Adds the newest microphone level (0...1) and scrolls the bars along.
    func push(level: CGFloat, seconds: Int) {
        var levels = model.levels
        levels.removeFirst()
        levels.append(level)
        model.levels = levels
        if model.seconds != seconds { model.seconds = seconds }
    }

    private func fadeOut() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; panel.animator().alphaValue = 0 }) {
            if panel.alphaValue == 0 {
                panel.orderOut(nil)
                self.model.mode = .hidden
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: PillView(model: model) { [weak self] in
            self?.onOpenSettings?()
            self?.hide()
        })
        self.panel = panel
        return panel
    }

    /// Bottom centre of the screen the pointer is on.
    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.midX - Self.size.width / 2, y: area.minY + 12))
    }
}

private extension Indicator.Mode {
    var isPermission: Bool { if case .permission = self { return true } else { return false } }
}

private struct PillView: View {
    @ObservedObject var model: Indicator.Model
    let openSettings: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if model.mode != .hidden { pill }
        }
        .frame(width: Indicator.size.width, height: Indicator.size.height)
    }

    private var pill: some View {
        content
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.leading, 16)
            .padding(.trailing, model.mode.isPermission ? 8 : 16)
            .frame(height: 40)
            .background(Capsule().fill(Color(red: 0.09, green: 0.09, blue: 0.1).opacity(0.94)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
            .padding(.bottom, 20)
    }

    @ViewBuilder private var content: some View {
        switch model.mode {
        case .hidden:
            EmptyView()
        case .listening:
            HStack(spacing: 10) {
                Bars(levels: model.levels)
                Text(String(format: "%d:%02d", model.seconds / 60, model.seconds % 60))
                    .monospacedDigit()
                    .opacity(0.6)
            }
        case .writing:
            HStack(spacing: 10) {
                FillingLine()
                Text("Writing").opacity(0.85)
            }
        case .message(let text):
            Text(text).opacity(0.85)
        case .permission(let text):
            HStack(spacing: 10) {
                Text(text).opacity(0.85)
                Button(action: openSettings) {
                    Text("Open Settings")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Bars that follow the microphone level, newest on the right.
private struct Bars: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.95))
                    .frame(width: 3, height: 4 + 16 * levels[i])
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.08), value: levels)
    }
}

/// A short line sliding along a track while the text is being written.
private struct FillingLine: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: 22)
                    .offset(x: -22 + (48 + 22) * phase)
            }
            .frame(width: 48, height: 3)
            .clipShape(Capsule())
        }
    }
}
