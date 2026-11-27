import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    /// A colour that adapts to light / dark mode on every platform.
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #endif
    }
}

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: Color
    let lightTop: UInt32, lightBottom: UInt32, darkTop: UInt32, darkBottom: UInt32

    static func == (a: AppTheme, b: AppTheme) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var background: LinearGradient {
        LinearGradient(colors: [Color(light: Color(hex: lightTop), dark: Color(hex: darkTop)),
                                Color(light: Color(hex: lightBottom), dark: Color(hex: darkBottom))],
                       startPoint: .top, endPoint: .bottom)
    }
    var card: Color { Color(light: .white.opacity(0.72), dark: .white.opacity(0.07)) }
    var keyFill: Color { Color(light: .white.opacity(0.92), dark: .white.opacity(0.11)) }

    static let all: [AppTheme] = [
        AppTheme(id: "default", name: "Default", accent: Color(hex: 0x4F6BED), lightTop: 0xF4F6FC, lightBottom: 0xE3E8F6, darkTop: 0x12141C, darkBottom: 0x1C2030),
        AppTheme(id: "matcha", name: "Matcha", accent: Color(hex: 0x6E9A52), lightTop: 0xF5F8EE, lightBottom: 0xE0EAD0, darkTop: 0x10150F, darkBottom: 0x1B261A),
        AppTheme(id: "ocean", name: "Ocean", accent: Color(hex: 0x1E9BB4), lightTop: 0xF0F8FA, lightBottom: 0xD6EDF2, darkTop: 0x0C1618, darkBottom: 0x12262B),
        AppTheme(id: "sunset", name: "Sunset", accent: Color(hex: 0xE8734A), lightTop: 0xFFF6F0, lightBottom: 0xFBE0D2, darkTop: 0x1A110D, darkBottom: 0x2A1A14),
        AppTheme(id: "lavender", name: "Lavender", accent: Color(hex: 0x8B6FD6), lightTop: 0xF6F2FD, lightBottom: 0xE6DEF7, darkTop: 0x140F1E, darkBottom: 0x211A33),
        AppTheme(id: "rose", name: "Rose", accent: Color(hex: 0xD9578A), lightTop: 0xFEF1F6, lightBottom: 0xF7DAE6, darkTop: 0x1C0F15, darkBottom: 0x2E1722),
        AppTheme(id: "mocha", name: "Mocha", accent: Color(hex: 0xA9744F), lightTop: 0xF9F3ED, lightBottom: 0xE9D9C7, darkTop: 0x1A1310, darkBottom: 0x2A2019),
        AppTheme(id: "graphite", name: "Graphite", accent: Color(hex: 0x5A6270), lightTop: 0xF5F6F7, lightBottom: 0xE2E4E8, darkTop: 0x0F1011, darkBottom: 0x1C1E21),
    ]

    static func named(_ id: String) -> AppTheme { all.first { $0.id == id } ?? all[0] }
}

private struct ThemeKey: EnvironmentKey { static let defaultValue = AppTheme.all[0] }
extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct CardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}

struct ThemedScroll: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(ThemeBackdrop().ignoresSafeArea())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Calculator keys: springy squash plus a quick light flash.
struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(configuration.isPressed ? 0.28 : 0)))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Big call-to-action button with a soft glow.
struct GlowButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(.white)
            .padding(.vertical, 15).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: theme.accent.opacity(isEnabled ? 0.35 : 0), radius: configuration.isPressed ? 4 : 14, y: configuration.isPressed ? 2 : 7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Slow drifting colour glows behind everything. Static when Reduce Motion is on.
struct ThemeBackdrop: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle().fill(theme.background)
            if reduceMotion {
                glows(t: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
                    glows(t: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func glows(t: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                glow(theme.accent, 0.22, size: w * 0.95)
                    .offset(x: CGFloat(sin(t / 7)) * w * 0.25 - w * 0.2,
                            y: CGFloat(cos(t / 9)) * h * 0.12 - h * 0.3)
                glow(theme.accent, 0.15, size: w * 0.8)
                    .offset(x: CGFloat(cos(t / 8)) * w * 0.25 + w * 0.25,
                            y: CGFloat(sin(t / 11)) * h * 0.12 + h * 0.3)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .allowsHitTesting(false)
    }

    private func glow(_ c: Color, _ opacity: Double, size: CGFloat) -> some View {
        Circle().fill(c.opacity(opacity)).frame(width: size, height: size).blur(radius: 70)
    }
}

/// Side-to-side wobble for errors.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 9
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(shakes * .pi * 4), y: 0))
    }
}

/// Moving highlight for loading placeholders.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6)
                        .offset(x: phase * g.size.width * 1.6)
                }
                .mask(content)
            )
            .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}

/// Fades and slides a view up when it first appears, one after another.
struct StaggerIn: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.09)) { shown = true }
            }
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
    func themedForm() -> some View { formStyle(.grouped).modifier(ThemedScroll()) }
    func themedList() -> some View { modifier(ThemedScroll()) }
    func shimmer() -> some View { modifier(Shimmer()) }
    func staggerIn(_ index: Int) -> some View { modifier(StaggerIn(index: index)) }
}
