import SwiftUI

// Efeitos do widget (DESIGN_SYSTEM / swiftui-effects), implementados APENAS com
// TimelineView + Canvas: redesenham dentro de frames fixos sem animar layout.
// Animações SwiftUI `repeatForever` são proibidas aqui — o MenuBarExtra(.window)
// recalcula o tamanho da janela a cada quadro e o popover treme (bug já corrigido).

/// Pseudo-random determinístico para partículas.
private func rnd(_ n: Double) -> Double {
    let s = sin(n) * 43758.5453
    return s - s.rounded(.down)
}

/// Poeira luminosa subindo (aurora §2 do skill) — Canvas a 30 fps.
struct WidgetParticleField: View {
    var tint: Color
    var count = 26

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let fi = Double(i)
                    let speed = 6 + rnd(fi * 7.7) * 14
                    let x = rnd(fi * 1.3) * size.width + sin(t * 0.25 + fi * 2) * 24
                    var y = (rnd(fi * 2.7) * size.height - t * speed)
                        .truncatingRemainder(dividingBy: size.height)
                    if y < 0 { y += size.height }
                    let alpha = 0.04 + 0.13 * (0.5 + 0.5 * sin(t * 1.6 + fi * 3.1))
                    let r = 0.8 + rnd(fi * 4.2) * 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color((i % 3 == 0 ? tint : .white).opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Varredura de luz sobre um card (LightSweep §5) — TimelineView, sem layout.
struct WidgetLightSweep: View {
    var cornerRadius: CGFloat = 18
    var period: Double = 5.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            GeometryReader { geo in
                let t = tl.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: period)) / period
                let x = -80 + (geo.size.width + 160) * phase
                LinearGradient(colors: [.clear, .white.opacity(0.07), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90)
                    .rotationEffect(.degrees(18))
                    .offset(x: x)
                    .blendMode(.plusLighter)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .allowsHitTesting(false)
    }
}

/// Shimmer de botão primário (§5) — brilho atravessando em loop, via TimelineView.
struct WidgetShimmer: View {
    var period: Double = 3.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            GeometryReader { geo in
                let t = tl.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: period)) / period
                let x = -60 + (geo.size.width + 120) * phase
                LinearGradient(colors: [.clear, .white.opacity(0.45), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 42)
                    .rotationEffect(.degrees(22))
                    .offset(x: x)
                    .blendMode(.plusLighter)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .allowsHitTesting(false)
    }
}

/// Ponto "ao vivo" pulsando — opacidade e halo derivados do tempo (sem animação
/// de layout; o frame é fixo).
struct WidgetLiveDot: View {
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2.4)   // 0…1 num ciclo ~2.6 s
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .opacity(0.55 + 0.45 * pulse)
                .shadow(color: color.opacity(0.35 + 0.4 * pulse), radius: 3 + 3 * pulse)
        }
        .frame(width: 13, height: 13)   // frame externo FIXO: nunca relayouta
    }
}
