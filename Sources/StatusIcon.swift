import AppKit

/// Draws the menu bar icon: a tiny drive with a working activity LED.
enum StatusIcon {
    static let readColor = NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.42, alpha: 1)
    static let writeColor = NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.10, alpha: 1)

    static func make(art: DriveArt, power: Bool, read: Double, write: Double) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: true) { _ in
            let ink = NSColor.labelColor.withAlphaComponent(power ? 0.95 : 0.5)
            let ledCenter: NSPoint
            if art.isFloppy {
                ledCenter = drawFloppyBezel(ink: ink, wide: art == .floppy525)
            } else {
                ledCenter = drawHardDrive(ink: ink)
            }
            drawLED(at: ledCenter, power: power, read: read, write: write, ink: ink)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Platter drive sounds"
        return image
    }

    private static func drawHardDrive(ink: NSColor) -> NSPoint {
        ink.setStroke()
        ink.setFill()
        let body = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 2.5, width: 19, height: 11), xRadius: 2.6, yRadius: 2.6)
        body.lineWidth = 1.3
        body.stroke()

        let platter = NSBezierPath(ovalIn: NSRect(x: 7.6 - 3.9, y: 8 - 3.9, width: 7.8, height: 7.8))
        platter.lineWidth = 1.1
        platter.stroke()
        NSBezierPath(ovalIn: NSRect(x: 7.6 - 0.95, y: 8 - 0.95, width: 1.9, height: 1.9)).fill()

        let arm = NSBezierPath()
        arm.move(to: NSPoint(x: 14.6, y: 11.0))
        arm.line(to: NSPoint(x: 9.9, y: 5.7))
        arm.lineWidth = 1.3
        arm.lineCapStyle = .round
        arm.stroke()
        NSBezierPath(ovalIn: NSRect(x: 14.6 - 1.2, y: 11.0 - 1.2, width: 2.4, height: 2.4)).fill()
        return NSPoint(x: 17.6, y: 5.6)
    }

    private static func drawFloppyBezel(ink: NSColor, wide: Bool) -> NSPoint {
        ink.setStroke()
        ink.setFill()
        let rect = wide ? NSRect(x: 1.5, y: 2.5, width: 19, height: 11) : NSRect(x: 1.5, y: 3.5, width: 19, height: 9)
        let body = NSBezierPath(roundedRect: rect, xRadius: 2.2, yRadius: 2.2)
        body.lineWidth = 1.3
        body.stroke()

        let slotY = wide ? 6.4 : 6.8
        let slot = NSBezierPath()
        slot.move(to: NSPoint(x: 4.5, y: slotY))
        slot.line(to: NSPoint(x: 17.5, y: slotY))
        slot.lineWidth = 1.6
        slot.lineCapStyle = .round
        slot.stroke()

        if wide {
            // door latch lever
            let lever = NSBezierPath(roundedRect: NSRect(x: 9.6, y: 4.0, width: 2.8, height: 6.2), xRadius: 1.2, yRadius: 1.2)
            lever.fill()
        } else {
            // eject button
            let eject = NSBezierPath(roundedRect: NSRect(x: 14.2, y: 9.0, width: 4.0, height: 1.8), xRadius: 0.9, yRadius: 0.9)
            eject.fill()
        }
        return NSPoint(x: wide ? 5.0 : 5.2, y: wide ? 10.6 : 9.9)
    }

    private static func drawLED(at p: NSPoint, power: Bool, read: Double, write: Double, ink: NSColor) {
        let level = max(read, write)
        let r: CGFloat = 1.6
        let rect = NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        let dot = NSBezierPath(ovalIn: rect)
        if level > 0.02 {
            let color = (write > read ? writeColor : readColor)
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = color.withAlphaComponent(CGFloat(0.9 * level))
            glow.shadowBlurRadius = 3
            glow.shadowOffset = .zero
            glow.set()
            color.withAlphaComponent(CGFloat(0.45 + 0.55 * level)).setFill()
            dot.fill()
            NSGraphicsContext.restoreGraphicsState()
        } else if power {
            ink.withAlphaComponent(0.28).setFill()
            dot.fill()
        } else {
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 0.35, dy: 0.35))
            ring.lineWidth = 0.8
            ink.withAlphaComponent(0.6).setStroke()
            ring.stroke()
        }
    }
}
