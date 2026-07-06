import SwiftUI

// MARK: - Card "vidro" com borda gradiente, sombra e hover flutuante

struct GlassCard: ViewModifier {
    var hoverLift = true
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.card.opacity(0.85))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: [.white.opacity(0.05), .clear],
                                           startPoint: .topLeading, endPoint: .center)
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(hovering ? 0.35 : 0.16),
                                     .white.opacity(0.03),
                                     Theme.accent.opacity(hovering ? 0.35 : 0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: hovering ? 22 : 12, y: hovering ? 12 : 6)
            .shadow(color: Theme.accent.opacity(hovering ? 0.12 : 0), radius: 24)
            .offset(y: hovering && hoverLift ? -3 : 0)
            .animation(.spring(duration: 0.35), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func glassCard(hoverLift: Bool = true) -> some View {
        modifier(GlassCard(hoverLift: hoverLift))
    }
}

// MARK: - Fundo com brilhos radiais animados

struct AuroraBackground: View {
    var top: Color
    var tint: Color
    var boost = false
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)

            // manchas de luz que derivam lentamente
            Circle()
                .fill(tint.opacity(boost ? 0.25 : 0.12))
                .frame(width: 520, height: 520)
                .blur(radius: 130)
                .offset(x: drift ? -180 : -320, y: drift ? -220 : -120)

            Circle()
                .fill(Color(red: 0.30, green: 0.55, blue: 0.95).opacity(0.10))
                .frame(width: 460, height: 460)
                .blur(radius: 140)
                .offset(x: drift ? 320 : 200, y: drift ? 180 : 320)

            Circle()
                .fill(tint.opacity(0.07))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: drift ? 60 : -60, y: drift ? 300 : 160)

            // poeira luminosa flutuando
            ParticleField(tint: tint)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Aparição em cascata (fade + slide)

struct AppearReveal: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .onAppear {
                withAnimation(.spring(duration: 0.7).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func reveal(delay: Double) -> some View { modifier(AppearReveal(delay: delay)) }
}

// MARK: - Brilho pulsante

struct PulseGlow: ViewModifier {
    let color: Color
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(pulse ? 0.65 : 0.25), radius: pulse ? 42 : 22)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

extension View {
    func pulseGlow(_ color: Color) -> some View { modifier(PulseGlow(color: color)) }
}

// MARK: - Campo de partículas flutuantes (poeira luminosa)

private func rnd(_ n: Double) -> Double {
    let s = sin(n) * 43758.5453
    return s - s.rounded(.down)
}

struct ParticleField: View {
    var tint: Color
    var count = 38

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let fi = Double(i)
                    let speed = 6 + rnd(fi * 7.7) * 14
                    let x = rnd(fi * 1.3) * size.width + sin(t * 0.25 + fi * 2) * 24
                    var y = rnd(fi * 2.7) * size.height - t * speed
                    y = y.truncatingRemainder(dividingBy: size.height)
                    if y < 0 { y += size.height }

                    let twinkle = 0.5 + 0.5 * sin(t * 1.6 + fi * 3.1)
                    let alpha = 0.05 + 0.16 * twinkle
                    let r = 0.8 + rnd(fi * 4.2) * 1.8

                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let color = i % 3 == 0 ? tint : Color.white
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Vórtice: partículas sugadas para o centro

struct VortexField: View {
    var tint: Color
    var active: Bool
    var count = 30

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                guard active else { return }
                let t = tl.date.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<count {
                    let fi = Double(i)
                    // ciclo 0→1: da borda ao centro
                    var cycle = (t * (0.35 + rnd(fi * 3.3) * 0.4) + rnd(fi * 1.7))
                        .truncatingRemainder(dividingBy: 1)
                    if cycle < 0 { cycle += 1 }

                    let maxR = Double(size.width) / 2.0 - 6.0
                    let radius = (1 - cycle) * maxR + 10
                    let angle = rnd(fi * 5.1) * .pi * 2 + t * 1.1 + cycle * 5.5
                    let p = CGPoint(x: c.x + cos(angle) * radius,
                                    y: c.y + sin(angle) * radius)

                    // some perto do centro, brilha no meio do caminho
                    let alpha = cycle < 0.12 ? cycle / 0.12
                              : cycle > 0.82 ? (1 - cycle) / 0.18
                              : 1.0
                    let r = 1.2 + rnd(fi * 9.4) * 2.2

                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    let color = i % 4 == 0 ? Color.white : tint
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha * 0.85)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Varredura de luz periódica (sobre cards)

struct LightSweep: View {
    var cornerRadius: CGFloat = 18
    var period: Double = 5.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let phase = (t / period).truncatingRemainder(dividingBy: 1)
                let x = phase * (geo.size.width + 320) - 160

                LinearGradient(colors: [.clear, .white.opacity(0.07), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 150, height: geo.size.height * 2)
                    .rotationEffect(.degrees(18))
                    .offset(x: x, y: -geo.size.height / 2)
                    .blendMode(.plusLighter)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Shimmer em botões (brilho que atravessa)

struct ShimmerCapsule: ViewModifier {
    var period: Double = 3.2

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let phase = (t / period).truncatingRemainder(dividingBy: 1)
                    let x = phase * (geo.size.width + 120) - 60

                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 42, height: geo.size.height * 3)
                        .rotationEffect(.degrees(22))
                        .offset(x: x, y: -geo.size.height)
                        .blendMode(.plusLighter)
                }
            }
            .clipShape(Capsule())
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func shimmer(period: Double = 3.2) -> some View { modifier(ShimmerCapsule(period: period)) }
}

// MARK: - Tilt 3D que segue o mouse (perspectiva)

struct Tilt3D: ViewModifier {
    var maxAngle: Double = 6
    @State private var size: CGSize = .zero
    @State private var tilt: CGPoint = .zero      // -1...1 em cada eixo
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.onAppear { size = geo.size }
                    .onChange(of: geo.size) { _, s in size = s }
            })
            .rotation3DEffect(.degrees(Double(-tilt.y) * maxAngle),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(Double(tilt.x) * maxAngle),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .scaleEffect(hovering ? 1.01 : 1)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p):
                    guard size.width > 0, size.height > 0 else { return }
                    hovering = true
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                        tilt = CGPoint(x: (p.x / size.width - 0.5) * 2,
                                       y: (p.y / size.height - 0.5) * 2)
                    }
                case .ended:
                    hovering = false
                    withAnimation(.spring(duration: 0.5)) { tilt = .zero }
                }
            }
    }
}

extension View {
    func tilt3D(maxAngle: Double = 6) -> some View { modifier(Tilt3D(maxAngle: maxAngle)) }
}

// MARK: - Transição de flip 3D

struct Flip3D: ViewModifier {
    var angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0),
                              anchor: .center, perspective: 0.5)
            .opacity(angle > 60 ? 0 : 1 - angle / 90)
    }
}

extension AnyTransition {
    static var flip3D: AnyTransition {
        .modifier(active: Flip3D(angle: 75), identity: Flip3D(angle: 0))
    }
}
