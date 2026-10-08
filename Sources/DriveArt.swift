import SwiftUI

// MARK: - Animated drive in the hero card

struct DriveStage: View {
    let art: DriveArt
    @EnvironmentObject var telemetry: Telemetry

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let f = telemetry.frame(at: timeline.date, floppy: art.isFloppy)
                switch art {
                case .floppy35: DriveDrawing.floppy35(&ctx, size, f)
                case .floppy525: DriveDrawing.floppy525(&ctx, size, f)
                default: DriveDrawing.hardDrive(&ctx, size, f, art: art)
                }
            }
        }
    }
}

private extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
}

enum DriveDrawing {
    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func led(_ ctx: inout GraphicsContext, at p: CGPoint, r: CGFloat, f: Telemetry.Frame) {
        let level = max(f.read, f.write)
        let color: Color = f.write > f.read ? .ledAmber : .ledGreen
        ctx.fill(circle(p, r + 1.2), with: .color(.black.opacity(0.7)))
        if level > 0.02 {
            ctx.fill(circle(p, r * 4.5), with: .radialGradient(
                Gradient(colors: [color.opacity(0.55 * level), color.opacity(0)]),
                center: p, startRadius: 0, endRadius: r * 4.5))
            ctx.fill(circle(p, r), with: .color(color.opacity(0.5 + 0.5 * level)))
            ctx.fill(circle(CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.3), r * 0.38), with: .color(.white.opacity(0.7 * level)))
        } else {
            ctx.fill(circle(p, r), with: .color(Color(red: 0.12, green: 0.2, blue: 0.14).opacity(f.power ? 1 : 0.6)))
        }
    }

    static func screw(_ ctx: inout GraphicsContext, _ p: CGPoint, _ r: CGFloat) {
        ctx.fill(circle(p, r), with: .linearGradient(Gradient(colors: [Color(white: 0.62), Color(white: 0.32)]),
                                                     startPoint: CGPoint(x: p.x - r, y: p.y - r),
                                                     endPoint: CGPoint(x: p.x + r, y: p.y + r)))
        var slot = Path()
        slot.move(to: CGPoint(x: p.x - r * 0.6, y: p.y + r * 0.6))
        slot.addLine(to: CGPoint(x: p.x + r * 0.6, y: p.y - r * 0.6))
        ctx.stroke(slot, with: .color(.black.opacity(0.45)), lineWidth: 0.8)
    }

    // MARK: Hard drive

    static func hardDrive(_ ctx: inout GraphicsContext, _ size: CGSize, _ f: Telemetry.Frame, art: DriveArt) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)

        let (topTone, bottomTone): (Color, Color) = {
            switch art {
            case .stepper: return (Color(red: 0.40, green: 0.36, blue: 0.30), Color(red: 0.20, green: 0.18, blue: 0.15))
            case .server:  return (Color(red: 0.26, green: 0.30, blue: 0.38), Color(red: 0.11, green: 0.13, blue: 0.18))
            default:       return (Color(white: 0.42), Color(white: 0.22))
            }
        }()

        // chassis
        let body = Path(roundedRect: rect, cornerRadius: w * 0.12, style: .continuous)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [topTone, bottomTone]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        let inner = Path(roundedRect: rect.insetBy(dx: w * 0.035, dy: h * 0.035), cornerRadius: w * 0.095, style: .continuous)
        ctx.fill(inner, with: .linearGradient(Gradient(colors: [Color(white: 0.15), Color(white: 0.08)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        ctx.stroke(body, with: .color(.white.opacity(0.12)), lineWidth: 1)
        for p in [CGPoint(x: w * 0.085, y: h * 0.085), CGPoint(x: w * 0.915, y: h * 0.085), CGPoint(x: w * 0.085, y: h * 0.915)] {
            screw(&ctx, p, w * 0.028)
        }

        // platter
        let c = CGPoint(x: w * 0.43, y: h * 0.45)
        let r = w * 0.37
        let platter = circle(c, r)
        ctx.fill(circle(c, r + 1.5), with: .color(.black.opacity(0.5)))
        ctx.fill(platter, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(white: 0.93), location: 0.0),
                .init(color: Color(white: 0.70), location: 0.35),
                .init(color: Color(white: 0.84), location: 0.7),
                .init(color: Color(white: 0.58), location: 1.0),
            ]), center: c, startRadius: 0, endRadius: r))
        // anisotropic reflection that turns with the platter
        let sheenAlpha = 0.28 + 0.27 * f.spin
        ctx.fill(platter, with: .conicGradient(
            Gradient(colors: [
                .white.opacity(0), .white.opacity(sheenAlpha), .white.opacity(0), .black.opacity(0.16),
                .white.opacity(0), .white.opacity(sheenAlpha * 0.8), .white.opacity(0), .black.opacity(0.14),
                .white.opacity(0),
            ]), center: c, angle: .radians(f.angle)))
        for k in 0..<5 {
            let rr = r * (0.42 + 0.12 * CGFloat(k))
            ctx.stroke(circle(c, rr), with: .color(.black.opacity(0.05)), lineWidth: 0.6)
        }
        ctx.stroke(platter, with: .color(.black.opacity(0.35)), lineWidth: 1)

        // spindle hub with screws that show the rotation
        let hr = r * 0.25
        ctx.fill(circle(c, hr + 1), with: .color(.black.opacity(0.35)))
        ctx.fill(circle(c, hr), with: .radialGradient(Gradient(colors: [Color(white: 0.88), Color(white: 0.52)]), center: CGPoint(x: c.x - hr * 0.3, y: c.y - hr * 0.3), startRadius: 0, endRadius: hr * 1.3))
        for i in 0..<6 {
            let a = f.angle + Double(i) * .pi / 3
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * hr * 0.62, y: c.y + CGFloat(sin(a)) * hr * 0.62)
            ctx.fill(circle(p, hr * 0.13), with: .color(Color(white: 0.30)))
        }
        ctx.fill(circle(c, hr * 0.22), with: .color(Color(white: 0.40)))

        // voice coil / magnet block
        let magnet = CGRect(x: w * 0.69, y: h * 0.69, width: w * 0.26, height: h * 0.25)
        ctx.fill(Path(roundedRect: magnet, cornerRadius: w * 0.05, style: .continuous),
                 with: .linearGradient(Gradient(colors: [Color(white: 0.30), Color(white: 0.12)]), startPoint: CGPoint(x: magnet.minX, y: magnet.minY), endPoint: CGPoint(x: magnet.maxX, y: magnet.maxY)))

        // ramp for parked heads
        var ramp = Path()
        ramp.addRoundedRect(in: CGRect(x: w * 0.78, y: h * 0.06, width: w * 0.08, height: h * 0.20), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(ramp, with: .color(Color(white: 0.22)))

        // actuator arm: solve for the head radius so the arm swings like the real thing
        let pivot = CGPoint(x: w * 0.84, y: h * 0.83)
        let headR: CGFloat = f.head < 0
            ? r * (0.94 + 0.24 * CGFloat(min(1, -f.head / 0.08)))
            : r * (0.92 - 0.62 * CGFloat(min(1, max(0, f.head))))
        let d = hypot(c.x - pivot.x, c.y - pivot.y)
        let L = w * 0.62
        let base = atan2(Double(c.y - pivot.y), Double(c.x - pivot.x))
        let cosA = Double((d * d + L * L - headR * headR) / (2 * d * L))
        let phi = base + acos(max(-1, min(1, cosA)))
        let dir = CGPoint(x: CGFloat(cos(phi)), y: CGFloat(sin(phi)))
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let tip = pivot + dir * L

        var shadow = Path()
        let off = CGPoint(x: 2, y: 3)
        shadow.move(to: pivot + perp * (w * 0.055) + off)
        shadow.addLine(to: tip + perp * (w * 0.016) + off)
        shadow.addLine(to: tip - perp * (w * 0.016) + off)
        shadow.addLine(to: pivot - perp * (w * 0.055) + off)
        shadow.closeSubpath()
        ctx.fill(shadow, with: .color(.black.opacity(0.25)))

        var arm = Path()
        arm.move(to: pivot + perp * (w * 0.06))
        arm.addLine(to: tip + perp * (w * 0.016))
        arm.addLine(to: tip - perp * (w * 0.016))
        arm.addLine(to: pivot - perp * (w * 0.06))
        arm.closeSubpath()
        ctx.fill(arm, with: .linearGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.58)]),
                                            startPoint: pivot + perp * (w * 0.06), endPoint: pivot - perp * (w * 0.06)))
        ctx.stroke(arm, with: .color(.black.opacity(0.25)), lineWidth: 0.6)
        // lightening hole and slider
        ctx.fill(circle(pivot + dir * (L * 0.42), w * 0.022), with: .color(Color(white: 0.35)))
        ctx.fill(circle(tip, w * 0.026), with: .color(Color(white: 0.20)))
        ctx.fill(circle(tip, w * 0.012), with: .color(Color(red: 0.75, green: 0.55, blue: 0.25)))
        // pivot bearing
        ctx.fill(circle(pivot, w * 0.07), with: .radialGradient(Gradient(colors: [Color(white: 0.9), Color(white: 0.45)]), center: CGPoint(x: pivot.x - 2, y: pivot.y - 2), startRadius: 0, endRadius: w * 0.08))
        ctx.fill(circle(pivot, w * 0.022), with: .color(Color(white: 0.3)))

        led(&ctx, at: CGPoint(x: w * 0.12, y: h * 0.88), r: w * 0.03, f: f)
    }

    // MARK: 3.5 inch floppy

    static func floppy35(_ ctx: inout GraphicsContext, _ size: CGSize, _ f: Telemetry.Frame) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let body = Path(roundedRect: rect, cornerRadius: w * 0.12, style: .continuous)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(white: 0.30), Color(white: 0.14)]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        ctx.fill(Path(roundedRect: rect.insetBy(dx: w * 0.035, dy: h * 0.035), cornerRadius: w * 0.095, style: .continuous),
                 with: .color(Color(white: 0.09)))
        ctx.stroke(body, with: .color(.white.opacity(0.12)), lineWidth: 1)

        // head rails
        let c = CGPoint(x: w * 0.40, y: h * 0.48)
        let r = w * 0.36
        for dy in [-0.13, 0.13] {
            var rail = Path()
            rail.move(to: CGPoint(x: c.x + r * 0.15, y: c.y + h * CGFloat(dy)))
            rail.addLine(to: CGPoint(x: w * 0.95, y: c.y + h * CGFloat(dy)))
            ctx.stroke(rail, with: .color(Color(white: 0.55)), lineWidth: 1.4)
        }
        // stepper motor
        let mc = CGPoint(x: w * 0.86, y: h * 0.84)
        ctx.fill(circle(mc, w * 0.085), with: .radialGradient(Gradient(colors: [Color(white: 0.5), Color(white: 0.2)]), center: mc, startRadius: 0, endRadius: w * 0.09))
        ctx.stroke(circle(mc, w * 0.05), with: .color(.black.opacity(0.4)), lineWidth: 0.8)

        // media
        let disk = circle(c, r)
        ctx.fill(disk, with: .radialGradient(Gradient(colors: [Color(red: 0.25, green: 0.19, blue: 0.14), Color(red: 0.10, green: 0.075, blue: 0.06)]), center: c, startRadius: r * 0.2, endRadius: r))
        ctx.fill(disk, with: .conicGradient(Gradient(colors: [
            .white.opacity(0), .white.opacity(0.10 + 0.08 * f.spin), .white.opacity(0), .white.opacity(0.06), .white.opacity(0)
        ]), center: c, angle: .radians(f.angle)))
        ctx.stroke(disk, with: .color(.black.opacity(0.6)), lineWidth: 1)

        // metal hub with an offset drive hole that shows the rotation
        let hr = r * 0.30
        ctx.fill(circle(c, hr), with: .radialGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.55)]), center: CGPoint(x: c.x - hr * 0.3, y: c.y - hr * 0.3), startRadius: 0, endRadius: hr * 1.4))
        ctx.fill(Path(roundedRect: CGRect(x: c.x - hr * 0.18, y: c.y - hr * 0.18, width: hr * 0.36, height: hr * 0.36), cornerRadius: 1), with: .color(Color(white: 0.25)))
        let a = f.angle
        let hole = CGPoint(x: c.x + CGFloat(cos(a)) * hr * 0.58, y: c.y + CGFloat(sin(a)) * hr * 0.58)
        var holeCtx = ctx
        holeCtx.translateBy(x: hole.x, y: hole.y)
        holeCtx.rotate(by: .radians(a))
        holeCtx.fill(Path(roundedRect: CGRect(x: -hr * 0.2, y: -hr * 0.13, width: hr * 0.4, height: hr * 0.26), cornerRadius: 1), with: .color(Color(white: 0.2)))

        // head carriage, track 0 is the outer edge
        let headX = c.x + r * (0.90 - 0.55 * CGFloat(max(0, min(1, f.head))))
        let carriage = CGRect(x: headX - w * 0.025, y: c.y - h * 0.17, width: w * 0.19, height: h * 0.34)
        ctx.fill(Path(roundedRect: carriage.offsetBy(dx: 2, dy: 3), cornerRadius: 3), with: .color(.black.opacity(0.3)))
        ctx.fill(Path(roundedRect: carriage, cornerRadius: 3), with: .linearGradient(Gradient(colors: [Color(white: 0.82), Color(white: 0.55)]), startPoint: CGPoint(x: carriage.minX, y: carriage.minY), endPoint: CGPoint(x: carriage.minX, y: carriage.maxY)))
        ctx.fill(Path(roundedRect: CGRect(x: headX - w * 0.018, y: c.y - h * 0.035, width: w * 0.05, height: h * 0.07), cornerRadius: 1.5), with: .color(Color(white: 0.18)))

        led(&ctx, at: CGPoint(x: w * 0.12, y: h * 0.88), r: w * 0.03, f: f)
    }

    // MARK: 5.25 inch floppy

    static func floppy525(_ ctx: inout GraphicsContext, _ size: CGSize, _ f: Telemetry.Frame) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let body = Path(roundedRect: rect, cornerRadius: w * 0.12, style: .continuous)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(red: 0.42, green: 0.40, blue: 0.36), Color(red: 0.22, green: 0.21, blue: 0.19)]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        ctx.fill(Path(roundedRect: rect.insetBy(dx: w * 0.035, dy: h * 0.035), cornerRadius: w * 0.095, style: .continuous),
                 with: .color(Color(white: 0.08)))
        ctx.stroke(body, with: .color(.white.opacity(0.12)), lineWidth: 1)

        let c = CGPoint(x: w * 0.47, y: h * 0.50)
        let r = w * 0.42
        // media
        let disk = circle(c, r)
        ctx.fill(disk, with: .radialGradient(Gradient(colors: [Color(red: 0.20, green: 0.17, blue: 0.14), Color(red: 0.08, green: 0.07, blue: 0.06)]), center: c, startRadius: r * 0.3, endRadius: r))
        ctx.fill(disk, with: .conicGradient(Gradient(colors: [
            .white.opacity(0), .white.opacity(0.09 + 0.07 * f.spin), .white.opacity(0), .white.opacity(0.05), .white.opacity(0)
        ]), center: c, angle: .radians(f.angle)))
        ctx.stroke(disk, with: .color(.black.opacity(0.6)), lineWidth: 1)
        // index hole
        let a = f.angle
        let idx = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.40, y: c.y + CGFloat(sin(a)) * r * 0.40)
        ctx.fill(circle(idx, w * 0.016), with: .color(Color(white: 0.04)))
        // reinforcement ring and clamp cone
        ctx.fill(circle(c, r * 0.36), with: .color(Color(red: 0.36, green: 0.34, blue: 0.30)))
        ctx.fill(circle(c, r * 0.27), with: .color(Color(white: 0.05)))
        ctx.fill(circle(c, r * 0.22), with: .radialGradient(Gradient(colors: [Color(white: 0.85), Color(white: 0.45)]), center: CGPoint(x: c.x - 3, y: c.y - 3), startRadius: 0, endRadius: r * 0.25))
        for i in 0..<3 {
            let aa = f.angle + Double(i) * 2 * .pi / 3
            ctx.fill(circle(CGPoint(x: c.x + CGFloat(cos(aa)) * r * 0.13, y: c.y + CGFloat(sin(aa)) * r * 0.13), r * 0.03), with: .color(Color(white: 0.3)))
        }

        // head carriage on the upper side, track 0 outermost
        let headX = c.x + r * (0.88 - 0.42 * CGFloat(max(0, min(1, f.head))))
        var rail = Path()
        rail.move(to: CGPoint(x: c.x + r * 0.35, y: c.y - h * 0.22))
        rail.addLine(to: CGPoint(x: w * 0.96, y: c.y - h * 0.22))
        ctx.stroke(rail, with: .color(Color(white: 0.6)), lineWidth: 1.6)
        let carriage = CGRect(x: headX - w * 0.03, y: c.y - h * 0.31, width: w * 0.16, height: h * 0.22)
        ctx.fill(Path(roundedRect: carriage.offsetBy(dx: 2, dy: 3), cornerRadius: 3), with: .color(.black.opacity(0.3)))
        ctx.fill(Path(roundedRect: carriage, cornerRadius: 3), with: .linearGradient(Gradient(colors: [Color(white: 0.85), Color(white: 0.55)]), startPoint: CGPoint(x: carriage.minX, y: carriage.minY), endPoint: CGPoint(x: carriage.minX, y: carriage.maxY)))
        ctx.fill(Path(roundedRect: CGRect(x: headX - w * 0.02, y: c.y - h * 0.16, width: w * 0.05, height: h * 0.06), cornerRadius: 1.5), with: .color(Color(white: 0.15)))

        led(&ctx, at: CGPoint(x: w * 0.12, y: h * 0.88), r: w * 0.03, f: f)
    }
}

// MARK: - Small picker icons

struct MiniDriveIcon: View {
    let art: DriveArt
    let selected: Bool

    var body: some View {
        Canvas { ctx, size in
            let ink: Color = selected ? .accentColor : .secondary
            let w = size.width, h = size.height
            switch art {
            case .floppy35:
                var p = Path()
                let x0 = w * 0.14, y0 = h * 0.12, x1 = w * 0.86, y1 = h * 0.88, cut = w * 0.1
                p.move(to: CGPoint(x: x0 + 2, y: y0))
                p.addLine(to: CGPoint(x: x1 - cut, y: y0))
                p.addLine(to: CGPoint(x: x1, y: y0 + cut))
                p.addLine(to: CGPoint(x: x1, y: y1 - 2))
                p.addQuadCurve(to: CGPoint(x: x1 - 2, y: y1), control: CGPoint(x: x1, y: y1))
                p.addLine(to: CGPoint(x: x0 + 2, y: y1))
                p.addQuadCurve(to: CGPoint(x: x0, y: y1 - 2), control: CGPoint(x: x0, y: y1))
                p.addLine(to: CGPoint(x: x0, y: y0 + 2))
                p.addQuadCurve(to: CGPoint(x: x0 + 2, y: y0), control: CGPoint(x: x0, y: y0))
                ctx.fill(p, with: .color(ink.opacity(0.14)))
                ctx.stroke(p, with: .color(ink), lineWidth: 1.4)
                ctx.fill(Path(CGRect(x: w * 0.32, y: y0, width: w * 0.36, height: h * 0.28)), with: .color(ink.opacity(0.85)))
                ctx.stroke(Path(roundedRect: CGRect(x: w * 0.26, y: h * 0.52, width: w * 0.48, height: h * 0.36), cornerRadius: 1.5), with: .color(ink), lineWidth: 1)
            case .floppy525:
                let r = CGRect(x: w * 0.1, y: h * 0.1, width: w * 0.8, height: h * 0.8)
                ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(ink.opacity(0.14)))
                ctx.stroke(Path(roundedRect: r, cornerRadius: 2), with: .color(ink), lineWidth: 1.4)
                ctx.stroke(DriveDrawing.circle(CGPoint(x: w * 0.5, y: h * 0.45), w * 0.13), with: .color(ink), lineWidth: 1.3)
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.44, y: h * 0.64, width: w * 0.12, height: h * 0.2), cornerRadius: 2), with: .color(ink))
                ctx.fill(DriveDrawing.circle(CGPoint(x: w * 0.68, y: h * 0.45), w * 0.035), with: .color(ink))
            default:
                let r = CGRect(x: w * 0.06, y: h * 0.16, width: w * 0.88, height: h * 0.68)
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(ink.opacity(0.14)))
                ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(ink), lineWidth: 1.4)
                let c = CGPoint(x: w * 0.40, y: h * 0.5)
                ctx.stroke(DriveDrawing.circle(c, w * 0.21), with: .color(ink), lineWidth: 1.2)
                ctx.fill(DriveDrawing.circle(c, w * 0.05), with: .color(ink))
                var arm = Path()
                arm.move(to: CGPoint(x: w * 0.80, y: h * 0.70))
                arm.addLine(to: CGPoint(x: w * 0.52, y: h * 0.38))
                ctx.stroke(arm, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                ctx.fill(DriveDrawing.circle(CGPoint(x: w * 0.80, y: h * 0.70), w * 0.055), with: .color(ink))
                if art == .server {
                    for i in 0..<3 {
                        let x = w * (0.70 + 0.07 * CGFloat(i))
                        var fin = Path(); fin.move(to: CGPoint(x: x, y: h * 0.24)); fin.addLine(to: CGPoint(x: x, y: h * 0.40))
                        ctx.stroke(fin, with: .color(ink), lineWidth: 1)
                    }
                } else if art == .stepper {
                    ctx.stroke(Path(roundedRect: CGRect(x: w * 0.68, y: h * 0.24, width: w * 0.18, height: h * 0.16), cornerRadius: 1), with: .color(ink), lineWidth: 1)
                }
            }
        }
    }
}
