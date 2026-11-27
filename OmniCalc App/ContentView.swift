import SwiftUI

struct ContentView: View {
    @AppStorage("theme") private var themeID = "default"
    @AppStorage("appearance") private var appearance = 0   // 0 system, 1 light, 2 dark
    @State private var calc = CalculatorModel()

    private var theme: AppTheme { .named(themeID) }

    var body: some View {
        TabView {
            CalculatorView(model: calc).tabItem { Label("Calculate", systemImage: "plus.forwardslash.minus") }
            ConvertView().tabItem { Label("Convert", systemImage: "arrow.left.arrow.right") }
            FormulasView().tabItem { Label("Formulas", systemImage: "function") }
            SolveView().tabItem { Label("Solve", systemImage: "sparkles") }
            SettingsView(model: calc).tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .environment(\.theme, theme)
        .tint(theme.accent)
        .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
        .animation(.easeInOut(duration: 0.45), value: themeID)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 720)
        #endif
    }
}
