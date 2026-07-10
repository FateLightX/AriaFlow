import AppKit

@MainActor
final class DockService {
    func update(activeCount: Int, progress: Double?) {
        NSApp.dockTile.badgeLabel = activeCount > 0 ? "\(activeCount)" : nil
        if activeCount > 0, let progress {
            NSApp.dockTile.contentView = DockProgressView(progress: min(max(progress, 0), 1))
        } else {
            NSApp.dockTile.contentView = nil
        }
        NSApp.dockTile.display()
    }
}

private final class DockProgressView: NSView {
    private let progress: Double

    init(progress: Double) {
        self.progress = progress
        super.init(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSApp.applicationIconImage.draw(in: bounds)

        let barFrame = NSRect(
            x: bounds.width * 0.16,
            y: bounds.height * 0.1,
            width: bounds.width * 0.68,
            height: bounds.height * 0.08
        )

        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: barFrame, xRadius: barFrame.height / 2, yRadius: barFrame.height / 2).fill()

        let fillFrame = NSRect(
            x: barFrame.minX,
            y: barFrame.minY,
            width: barFrame.width * progress,
            height: barFrame.height
        )
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: fillFrame, xRadius: fillFrame.height / 2, yRadius: fillFrame.height / 2).fill()
    }
}
