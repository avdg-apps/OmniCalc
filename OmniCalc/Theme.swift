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
        content.scrollContentBackground(.hidden).background(theme.background.ignoresSafeArea())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
    func themedForm() -> some View { formStyle(.grouped).modifier(ThemedScroll()) }
    func themedList() -> some View { modifier(ThemedScroll()) }
}
