import SwiftUI

struct GenreCardView: View {
    let genre: Genre
    let coverURLs: [URL]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if coverURLs.isEmpty {
                styledBackground
            } else {
                coverCollage
            }

            VStack {
                Spacer()
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)

                    Text(genre.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    // MARK: - Cover Collage

    private var coverCollage: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(coverURLs.prefix(3).enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle().fill(baseGradient)
                        case .empty:
                            Rectangle().fill(Color.gray.opacity(0.2))
                        @unknown default:
                            Rectangle().fill(baseGradient)
                        }
                    }
                    .frame(
                        width: geometry.size.width / CGFloat(min(coverURLs.count, 3)),
                        height: geometry.size.height
                    )
                    .clipped()
                }
            }
        }
    }

    private var baseGradient: LinearGradient {
        let p = palette
        return LinearGradient(
            colors: [p.bg1, p.bg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Styled Background

    private struct IP {
        let cx: CGFloat
        let cy: CGFloat
        let s: CGFloat
        let stroke: GraphicsContext.Shading
        let fill: GraphicsContext.Shading
    }

    private var styledBackground: some View {
        Canvas { context, size in
            let p = palette
            fillBase(&context, size: size, p: p)

            let cx = size.width * 0.5
            let cy = size.height * 0.40
            let s = min(size.width, size.height) * 0.28
            let tl = CGPoint(x: cx - s, y: cy - s)
            let br = CGPoint(x: cx + s, y: cy + s)

            let ip = IP(
                cx: cx, cy: cy, s: s,
                stroke: .linearGradient(
                    Gradient(colors: [p.c1.opacity(0.55), p.c2.opacity(0.30)]),
                    startPoint: tl, endPoint: br
                ),
                fill: .linearGradient(
                    Gradient(colors: [p.c1.opacity(0.15), p.c2.opacity(0.06)]),
                    startPoint: tl, endPoint: br
                )
            )

            // Ambient glow
            let glowR = s * 1.5
            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [p.c1.opacity(0.12), .clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: glowR
                )
            )

            switch genre.topic {
            case "fiction":         drawBook(&context, ip, p)
            case "science fiction": drawPlanet(&context, ip, p)
            case "mystery":         drawMagnifier(&context, ip, p)
            case "adventure":       drawCompass(&context, ip, p)
            case "romance":         drawHeart(&context, ip, p)
            case "horror":          drawMoon(&context, ip, p)
            case "philosophy":      drawEye(&context, ip, p)
            case "poetry":          drawQuill(&context, ip, p)
            case "history":         drawHourglass(&context, ip, p)
            case "biography":       drawCameo(&context, ip, p)
            case "science":         drawAtom(&context, ip, p)
            case "children":        drawStar(&context, ip, p)
            case "short stories":   drawPages(&context, ip, p)
            case "drama":           drawMasks(&context, ip, p)
            default:                drawBook(&context, ip, p)
            }
        }
    }

    private func fillBase(_ ctx: inout GraphicsContext, size: CGSize, p: Palette) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [p.bg1, p.bg2]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
    }

    // MARK: - Fiction: Open Book

    private func drawBook(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let top = CGPoint(x: cx, y: cy - s * 0.8)
        let bot = CGPoint(x: cx, y: cy + s * 0.8)

        // Left page fill
        var lf = Path()
        lf.move(to: top)
        lf.addQuadCurve(to: bot, control: CGPoint(x: cx - s * 1.15, y: cy))
        lf.closeSubpath()
        ctx.fill(lf, with: ip.fill)

        // Right page fill
        var rf = Path()
        rf.move(to: top)
        rf.addQuadCurve(to: bot, control: CGPoint(x: cx + s * 1.15, y: cy))
        rf.closeSubpath()
        ctx.fill(rf, with: ip.fill)

        // Left page stroke
        var ls = Path()
        ls.move(to: top)
        ls.addQuadCurve(to: bot, control: CGPoint(x: cx - s * 1.15, y: cy))
        ctx.stroke(ls, with: ip.stroke, lineWidth: 1.5)

        // Right page stroke
        var rs = Path()
        rs.move(to: top)
        rs.addQuadCurve(to: bot, control: CGPoint(x: cx + s * 1.15, y: cy))
        ctx.stroke(rs, with: ip.stroke, lineWidth: 1.5)

        // Spine
        var spine = Path()
        spine.move(to: top)
        spine.addLine(to: bot)
        ctx.stroke(spine, with: .color(p.c3.opacity(0.3)), lineWidth: 1)
    }

    // MARK: - Science Fiction: Ringed Planet

    private func drawPlanet(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let planetR = s * 0.45

        // Planet fill
        let planetRect = CGRect(x: cx - planetR, y: cy - planetR, width: planetR * 2, height: planetR * 2)
        ctx.fill(Path(ellipseIn: planetRect), with: ip.fill)
        ctx.stroke(Path(ellipseIn: planetRect), with: ip.stroke, lineWidth: 1.5)

        // Ring (tilted ellipse)
        var ctx2 = ctx
        ctx2.translateBy(x: cx, y: cy)
        ctx2.rotate(by: .degrees(-20))
        let ringRx = s * 0.9, ringRy = s * 0.22
        let ringRect = CGRect(x: -ringRx, y: -ringRy, width: ringRx * 2, height: ringRy * 2)
        ctx2.stroke(Path(ellipseIn: ringRect), with: ip.stroke, lineWidth: 1.5)
    }

    // MARK: - Mystery: Magnifying Glass

    private func drawMagnifier(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let glassCx = cx - s * 0.12, glassCy = cy - s * 0.12
        let glassR = s * 0.48

        // Lens fill (subtle radial for glass effect)
        let lensRect = CGRect(x: glassCx - glassR, y: glassCy - glassR, width: glassR * 2, height: glassR * 2)
        ctx.fill(Path(ellipseIn: lensRect), with: .radialGradient(
            Gradient(colors: [p.c1.opacity(0.08), p.c2.opacity(0.03)]),
            center: CGPoint(x: glassCx - glassR * 0.2, y: glassCy - glassR * 0.2),
            startRadius: 0, endRadius: glassR
        ))
        ctx.stroke(Path(ellipseIn: lensRect), with: ip.stroke, lineWidth: 1.5)

        // Handle
        let handleStart = CGPoint(x: glassCx + glassR * 0.65, y: glassCy + glassR * 0.65)
        let handleEnd = CGPoint(x: cx + s * 0.7, y: cy + s * 0.7)
        var handle = Path()
        handle.move(to: handleStart)
        handle.addLine(to: handleEnd)
        ctx.stroke(handle, with: ip.stroke, lineWidth: 2.5)
    }

    // MARK: - Adventure: Compass

    private func drawCompass(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let outerR = s * 0.72, innerR = s * 0.18

        // Outer circle
        let circleRect = CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
        ctx.stroke(Path(ellipseIn: circleRect), with: .color(p.c3.opacity(0.20)), lineWidth: 1)

        // Four-pointed star (compass rose)
        let pts: [CGPoint] = [
            CGPoint(x: cx, y: cy - outerR * 0.85),       // N
            CGPoint(x: cx + innerR, y: cy - innerR),      // NE inner
            CGPoint(x: cx + outerR * 0.85, y: cy),        // E
            CGPoint(x: cx + innerR, y: cy + innerR),      // SE inner
            CGPoint(x: cx, y: cy + outerR * 0.85),        // S
            CGPoint(x: cx - innerR, y: cy + innerR),      // SW inner
            CGPoint(x: cx - outerR * 0.85, y: cy),        // W
            CGPoint(x: cx - innerR, y: cy - innerR),      // NW inner
        ]
        var rose = Path()
        rose.move(to: pts[0])
        for i in 1..<pts.count { rose.addLine(to: pts[i]) }
        rose.closeSubpath()
        ctx.fill(rose, with: ip.fill)
        ctx.stroke(rose, with: ip.stroke, lineWidth: 1.5)

        // Fill north triangle brighter
        var north = Path()
        north.move(to: pts[0])
        north.addLine(to: pts[1])
        north.addLine(to: CGPoint(x: cx, y: cy))
        north.addLine(to: pts[7])
        north.closeSubpath()
        ctx.fill(north, with: .color(p.c1.opacity(0.25)))
    }

    // MARK: - Romance: Heart

    private func drawHeart(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s

        var heart = Path()
        heart.move(to: CGPoint(x: cx, y: cy + s * 0.75))
        heart.addCurve(
            to: CGPoint(x: cx, y: cy - s * 0.15),
            control1: CGPoint(x: cx + s * 0.05, y: cy + s * 0.35),
            control2: CGPoint(x: cx + s * 0.65, y: cy - s * 0.6)
        )
        heart.addCurve(
            to: CGPoint(x: cx, y: cy + s * 0.75),
            control1: CGPoint(x: cx - s * 0.65, y: cy - s * 0.6),
            control2: CGPoint(x: cx - s * 0.05, y: cy + s * 0.35)
        )
        heart.closeSubpath()

        ctx.fill(heart, with: ip.fill)
        ctx.stroke(heart, with: ip.stroke, lineWidth: 1.5)
    }

    // MARK: - Horror: Crescent Moon + Stars

    private func drawMoon(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s

        // Crescent via even-odd fill of two overlapping circles
        let outerR = s * 0.55
        let innerR = s * 0.45
        let outerRect = CGRect(x: cx - s * 0.1 - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
        let innerRect = CGRect(x: cx + s * 0.15 - innerR, y: cy - s * 0.05 - innerR, width: innerR * 2, height: innerR * 2)

        var crescent = Path()
        crescent.addEllipse(in: outerRect)
        crescent.addEllipse(in: innerRect)
        ctx.fill(crescent, with: ip.fill, style: FillStyle(eoFill: true))
        // Stroke just the outer circle for definition
        ctx.stroke(Path(ellipseIn: outerRect), with: .color(p.c1.opacity(0.30)), lineWidth: 1.5)

        // Stars (small dots)
        let stars: [(CGFloat, CGFloat, CGFloat)] = [
            (cx + s * 0.55, cy - s * 0.45, 2.0),
            (cx + s * 0.70, cy + s * 0.10, 1.5),
            (cx + s * 0.40, cy + s * 0.55, 1.8),
        ]
        for star in stars {
            let r = star.2
            ctx.fill(
                Path(ellipseIn: CGRect(x: star.0 - r, y: star.1 - r, width: r * 2, height: r * 2)),
                with: .color(p.c2.opacity(0.50))
            )
        }
    }

    // MARK: - Philosophy: Eye of Wisdom

    private func drawEye(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let eyeW = s * 0.95, eyeH = s * 0.45

        // Almond shape
        var eye = Path()
        eye.move(to: CGPoint(x: cx - eyeW, y: cy))
        eye.addQuadCurve(to: CGPoint(x: cx + eyeW, y: cy), control: CGPoint(x: cx, y: cy - eyeH))
        eye.addQuadCurve(to: CGPoint(x: cx - eyeW, y: cy), control: CGPoint(x: cx, y: cy + eyeH))
        eye.closeSubpath()
        ctx.fill(eye, with: ip.fill)
        ctx.stroke(eye, with: ip.stroke, lineWidth: 1.5)

        // Iris
        let irisR = s * 0.24
        let irisRect = CGRect(x: cx - irisR, y: cy - irisR, width: irisR * 2, height: irisR * 2)
        ctx.stroke(Path(ellipseIn: irisRect), with: ip.stroke, lineWidth: 1.5)

        // Pupil
        let pupilR = s * 0.09
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - pupilR, y: cy - pupilR, width: pupilR * 2, height: pupilR * 2)),
            with: .color(p.c1.opacity(0.50))
        )
    }

    // MARK: - Poetry: Quill Feather

    private func drawQuill(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let tipPt = CGPoint(x: cx + s * 0.3, y: cy + s * 0.75)
        let topPt = CGPoint(x: cx - s * 0.25, y: cy - s * 0.75)
        let ctrlPt = CGPoint(x: cx + s * 0.15, y: cy - s * 0.05)

        // Feather outline (leaf shape)
        var feather = Path()
        feather.move(to: tipPt)
        feather.addQuadCurve(to: topPt, control: CGPoint(x: cx - s * 0.5, y: cy - s * 0.05))
        feather.addQuadCurve(to: tipPt, control: CGPoint(x: cx + s * 0.35, y: cy + s * 0.05))
        feather.closeSubpath()
        ctx.fill(feather, with: ip.fill)
        ctx.stroke(feather, with: ip.stroke, lineWidth: 1.5)

        // Central shaft
        var shaft = Path()
        shaft.move(to: tipPt)
        shaft.addQuadCurve(to: topPt, control: ctrlPt)
        ctx.stroke(shaft, with: .color(p.c3.opacity(0.30)), lineWidth: 1)
    }

    // MARK: - History: Hourglass

    private func drawHourglass(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let hw = s * 0.5, hh = s * 0.7

        // Top triangle
        var top = Path()
        top.move(to: CGPoint(x: cx - hw, y: cy - hh))
        top.addLine(to: CGPoint(x: cx + hw, y: cy - hh))
        top.addLine(to: CGPoint(x: cx, y: cy))
        top.closeSubpath()
        ctx.fill(top, with: ip.fill)
        ctx.stroke(top, with: ip.stroke, lineWidth: 1.5)

        // Bottom triangle
        var bot = Path()
        bot.move(to: CGPoint(x: cx, y: cy))
        bot.addLine(to: CGPoint(x: cx + hw, y: cy + hh))
        bot.addLine(to: CGPoint(x: cx - hw, y: cy + hh))
        bot.closeSubpath()
        ctx.fill(bot, with: ip.fill)
        ctx.stroke(bot, with: ip.stroke, lineWidth: 1.5)

        // Top and bottom bars
        for yOff in [-hh, hh] {
            var bar = Path()
            bar.move(to: CGPoint(x: cx - hw - s * 0.08, y: cy + yOff))
            bar.addLine(to: CGPoint(x: cx + hw + s * 0.08, y: cy + yOff))
            ctx.stroke(bar, with: ip.stroke, lineWidth: 2)
        }
    }

    // MARK: - Biography: Portrait Cameo

    private func drawCameo(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let frameR = s * 0.65

        // Frame circle
        let frameRect = CGRect(x: cx - frameR, y: cy - frameR, width: frameR * 2, height: frameR * 2)
        ctx.fill(Path(ellipseIn: frameRect), with: ip.fill)
        ctx.stroke(Path(ellipseIn: frameRect), with: ip.stroke, lineWidth: 1.5)

        // Head
        let headR = s * 0.20
        let headCy = cy - s * 0.18
        let headRect = CGRect(x: cx - headR, y: headCy - headR, width: headR * 2, height: headR * 2)
        ctx.stroke(Path(ellipseIn: headRect), with: ip.stroke, lineWidth: 1.5)

        // Shoulders curve
        var shoulders = Path()
        shoulders.move(to: CGPoint(x: cx - s * 0.45, y: cy + s * 0.48))
        shoulders.addQuadCurve(
            to: CGPoint(x: cx + s * 0.45, y: cy + s * 0.48),
            control: CGPoint(x: cx, y: cy + s * 0.05)
        )
        ctx.stroke(shoulders, with: ip.stroke, lineWidth: 1.5)
    }

    // MARK: - Science: Atom Orbits

    private func drawAtom(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let center = CGPoint(x: cx, y: cy)

        let orbits: [(rx: CGFloat, ry: CGFloat, angle: Double)] = [
            (0.78, 0.32, -20),
            (0.62, 0.28, 30),
            (0.88, 0.22, 55),
        ]
        for orbit in orbits {
            var ctx2 = ctx
            ctx2.translateBy(x: center.x, y: center.y)
            ctx2.rotate(by: .degrees(orbit.angle))
            let rx = s * orbit.rx, ry = s * orbit.ry
            let orbitRect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
            ctx2.stroke(Path(ellipseIn: orbitRect), with: ip.stroke, lineWidth: 1.5)
        }

        // Center dot
        let dotR: CGFloat = 4
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
            with: .color(p.c2.opacity(0.6))
        )
    }

    // MARK: - Children's: Star

    private func drawStar(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let outerR = s * 0.70, innerR = s * 0.28

        var star = Path()
        for i in 0..<10 {
            let angle = -.pi / 2 + CGFloat(i) * .pi / 5
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()

        ctx.fill(star, with: ip.fill)
        ctx.stroke(star, with: ip.stroke, lineWidth: 1.5)
    }

    // MARK: - Short Stories: Stacked Pages

    private func drawPages(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let pageW = s * 0.60, pageH = s * 0.85
        let step: CGFloat = 5

        for i in (0...2).reversed() {
            let ox = CGFloat(i) * step
            let oy = CGFloat(i) * step
            let rect = CGRect(x: cx - pageW / 2 + ox, y: cy - pageH / 2 + oy, width: pageW, height: pageH)
            let rr = Path(roundedRect: rect, cornerRadius: 3)
            let alpha = 0.15 + Double(2 - i) * 0.13
            ctx.fill(rr, with: .color(p.c1.opacity(alpha * 0.4)))
            ctx.stroke(rr, with: .color(p.c1.opacity(alpha + 0.15)), lineWidth: 1.5)
        }
    }

    // MARK: - Drama: Comedy & Tragedy Masks

    private func drawMasks(_ ctx: inout GraphicsContext, _ ip: IP, _ p: Palette) {
        let cx = ip.cx, cy = ip.cy, s = ip.s
        let maskR = s * 0.38
        let gap = s * 0.28

        // Happy mask (left)
        let lx = cx - gap
        let happyRect = CGRect(x: lx - maskR, y: cy - maskR, width: maskR * 2, height: maskR * 2)
        ctx.fill(Path(ellipseIn: happyRect), with: ip.fill)
        ctx.stroke(Path(ellipseIn: happyRect), with: ip.stroke, lineWidth: 1.5)

        // Happy eyes
        let eyeR: CGFloat = 2
        for dx in [-maskR * 0.30, maskR * 0.30] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: lx + dx - eyeR, y: cy - maskR * 0.18 - eyeR, width: eyeR * 2, height: eyeR * 2)),
                with: .color(p.c1.opacity(0.50))
            )
        }
        // Smile
        var smile = Path()
        smile.move(to: CGPoint(x: lx - maskR * 0.25, y: cy + maskR * 0.12))
        smile.addQuadCurve(
            to: CGPoint(x: lx + maskR * 0.25, y: cy + maskR * 0.12),
            control: CGPoint(x: lx, y: cy + maskR * 0.42)
        )
        ctx.stroke(smile, with: ip.stroke, lineWidth: 1.2)

        // Sad mask (right)
        let rx = cx + gap
        let sadRect = CGRect(x: rx - maskR, y: cy - maskR, width: maskR * 2, height: maskR * 2)
        ctx.fill(Path(ellipseIn: sadRect), with: ip.fill)
        ctx.stroke(Path(ellipseIn: sadRect), with: ip.stroke, lineWidth: 1.5)

        // Sad eyes
        for dx in [-maskR * 0.30, maskR * 0.30] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: rx + dx - eyeR, y: cy - maskR * 0.18 - eyeR, width: eyeR * 2, height: eyeR * 2)),
                with: .color(p.c2.opacity(0.50))
            )
        }
        // Frown
        var frown = Path()
        frown.move(to: CGPoint(x: rx - maskR * 0.25, y: cy + maskR * 0.28))
        frown.addQuadCurve(
            to: CGPoint(x: rx + maskR * 0.25, y: cy + maskR * 0.28),
            control: CGPoint(x: rx, y: cy + maskR * 0.02)
        )
        ctx.stroke(frown, with: ip.stroke, lineWidth: 1.2)
    }

    // MARK: - Palette

    private struct Palette {
        let bg1: Color, bg2: Color
        let c1: Color, c2: Color, c3: Color
    }

    private var palette: Palette {
        switch genre.topic {
        case "fiction":
            return Palette(
                bg1: Color(red: 0.10, green: 0.08, blue: 0.25),
                bg2: Color(red: 0.18, green: 0.12, blue: 0.35),
                c1: Color(red: 0.55, green: 0.30, blue: 0.85),
                c2: Color(red: 0.20, green: 0.60, blue: 0.80),
                c3: Color(red: 0.40, green: 0.25, blue: 0.75)
            )
        case "science fiction":
            return Palette(
                bg1: Color(red: 0.04, green: 0.06, blue: 0.15),
                bg2: Color(red: 0.08, green: 0.10, blue: 0.25),
                c1: Color(red: 0.00, green: 0.70, blue: 0.90),
                c2: Color(red: 0.20, green: 0.85, blue: 1.00),
                c3: Color(red: 0.10, green: 0.90, blue: 0.50)
            )
        case "mystery":
            return Palette(
                bg1: Color(red: 0.10, green: 0.10, blue: 0.14),
                bg2: Color(red: 0.12, green: 0.12, blue: 0.20),
                c1: Color(red: 0.85, green: 0.65, blue: 0.20),
                c2: Color(red: 0.70, green: 0.50, blue: 0.15),
                c3: Color(red: 0.60, green: 0.45, blue: 0.20)
            )
        case "adventure":
            return Palette(
                bg1: Color(red: 0.08, green: 0.18, blue: 0.15),
                bg2: Color(red: 0.10, green: 0.25, blue: 0.22),
                c1: Color(red: 0.90, green: 0.55, blue: 0.15),
                c2: Color(red: 0.25, green: 0.65, blue: 0.45),
                c3: Color(red: 0.15, green: 0.45, blue: 0.35)
            )
        case "romance":
            return Palette(
                bg1: Color(red: 0.30, green: 0.10, blue: 0.18),
                bg2: Color(red: 0.25, green: 0.08, blue: 0.22),
                c1: Color(red: 0.95, green: 0.45, blue: 0.60),
                c2: Color(red: 0.85, green: 0.35, blue: 0.50),
                c3: Color(red: 0.75, green: 0.30, blue: 0.55)
            )
        case "horror":
            return Palette(
                bg1: Color(red: 0.08, green: 0.04, blue: 0.04),
                bg2: Color(red: 0.18, green: 0.05, blue: 0.05),
                c1: Color(red: 0.80, green: 0.10, blue: 0.10),
                c2: Color(red: 0.60, green: 0.08, blue: 0.08),
                c3: Color(red: 0.70, green: 0.20, blue: 0.05)
            )
        case "philosophy":
            return Palette(
                bg1: Color(red: 0.14, green: 0.16, blue: 0.18),
                bg2: Color(red: 0.18, green: 0.20, blue: 0.25),
                c1: Color(red: 0.50, green: 0.65, blue: 0.60),
                c2: Color(red: 0.40, green: 0.55, blue: 0.65),
                c3: Color(red: 0.60, green: 0.70, blue: 0.65)
            )
        case "poetry":
            return Palette(
                bg1: Color(red: 0.20, green: 0.10, blue: 0.30),
                bg2: Color(red: 0.25, green: 0.12, blue: 0.35),
                c1: Color(red: 0.65, green: 0.45, blue: 0.80),
                c2: Color(red: 0.75, green: 0.40, blue: 0.65),
                c3: Color(red: 0.55, green: 0.35, blue: 0.70)
            )
        case "history":
            return Palette(
                bg1: Color(red: 0.20, green: 0.14, blue: 0.08),
                bg2: Color(red: 0.25, green: 0.18, blue: 0.10),
                c1: Color(red: 0.80, green: 0.60, blue: 0.25),
                c2: Color(red: 0.65, green: 0.50, blue: 0.30),
                c3: Color(red: 0.70, green: 0.55, blue: 0.20)
            )
        case "biography":
            return Palette(
                bg1: Color(red: 0.06, green: 0.16, blue: 0.18),
                bg2: Color(red: 0.08, green: 0.22, blue: 0.20),
                c1: Color(red: 0.20, green: 0.70, blue: 0.55),
                c2: Color(red: 0.30, green: 0.60, blue: 0.50),
                c3: Color(red: 0.15, green: 0.50, blue: 0.40)
            )
        case "science":
            return Palette(
                bg1: Color(red: 0.05, green: 0.08, blue: 0.18),
                bg2: Color(red: 0.08, green: 0.15, blue: 0.22),
                c1: Color(red: 0.20, green: 0.80, blue: 0.40),
                c2: Color(red: 0.10, green: 0.70, blue: 0.70),
                c3: Color(red: 0.00, green: 0.60, blue: 0.85)
            )
        case "children":
            return Palette(
                bg1: Color(red: 0.90, green: 0.45, blue: 0.25),
                bg2: Color(red: 0.85, green: 0.35, blue: 0.30),
                c1: Color(red: 1.00, green: 0.80, blue: 0.20),
                c2: Color(red: 0.95, green: 0.40, blue: 0.55),
                c3: Color(red: 0.30, green: 0.70, blue: 0.90)
            )
        case "short stories":
            return Palette(
                bg1: Color(red: 0.15, green: 0.10, blue: 0.30),
                bg2: Color(red: 0.20, green: 0.12, blue: 0.35),
                c1: Color(red: 0.95, green: 0.65, blue: 0.45),
                c2: Color(red: 0.85, green: 0.50, blue: 0.40),
                c3: Color(red: 0.75, green: 0.40, blue: 0.55)
            )
        case "drama":
            return Palette(
                bg1: Color(red: 0.25, green: 0.08, blue: 0.12),
                bg2: Color(red: 0.20, green: 0.08, blue: 0.20),
                c1: Color(red: 0.85, green: 0.65, blue: 0.20),
                c2: Color(red: 0.75, green: 0.20, blue: 0.25),
                c3: Color(red: 0.65, green: 0.15, blue: 0.30)
            )
        default:
            return Palette(
                bg1: Color(red: 0.15, green: 0.12, blue: 0.20),
                bg2: Color(red: 0.20, green: 0.15, blue: 0.28),
                c1: Color(red: 0.55, green: 0.40, blue: 0.70),
                c2: Color(red: 0.40, green: 0.55, blue: 0.65),
                c3: Color(red: 0.50, green: 0.35, blue: 0.60)
            )
        }
    }
}
