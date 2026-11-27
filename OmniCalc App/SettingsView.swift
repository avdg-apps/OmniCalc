import SwiftUI

struct SettingsView: View {
    let model: CalculatorModel
    @Environment(\.theme) private var theme
    @AppStorage("theme") private var themeID = "default"
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("haptics") private var haptics = true
    @AppStorage("angleDegrees") private var degrees = true
    @AppStorage("sciDefault") private var sciDefault = false
    @AppStorage("sigDigits") private var sigDigits = 0
    @AppStorage("aiModel") private var aiModel = ""
    @AppStorage("favFormulas") private var favRaw = ""
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") { swatches }
                Section("Appearance") {
                    Picker("Mode", selection: $appearance.animation(.smooth)) {
                        Text("System").tag(0); Text("Light").tag(1); Text("Dark").tag(2)
                    }.pickerStyle(.segmented)
                }
                Section("Calculator") {
                    Picker("Angle unit", selection: $degrees) { Text("Degrees").tag(true); Text("Radians").tag(false) }
                    Toggle("Show scientific keys by default", isOn: $sciDefault)
                    Picker("Precision", selection: $sigDigits) {
                        Text("Automatic").tag(0)
                        ForEach([4, 6, 8, 10], id: \.self) { Text("\($0) significant digits").tag($0) }
                    }
                    #if os(iOS)
                    Toggle("Haptic feedback", isOn: $haptics)
                    #endif
                }
                Section {
                    LabeledContent("API key", value: AIConfig.isMissingKey ? "Not set" : "Added")
                    TextField("Model", text: $aiModel, prompt: Text(AIConfig.model))
                } header: { Text("AI Solver") } footer: {
                    Text("Your key lives in Secrets.swift. Leave the model blank to use the default.")
                }
                Section("Data") {
                    Button("Clear calculator history") { model.history = [] }
                    Button("Clear formula favourites") { favRaw = "" }
                    Button("Reset all settings", role: .destructive) { confirmReset = true }
                }
                Section("About") {
                    LabeledContent("OmniCalc", value: "1.0")
                    LabeledContent("Platforms", value: "iPhone · iPad · Mac · Vision")
                }
            }
            .themedForm()
            .navigationTitle("Settings")
            .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) {
                    withAnimation(.smooth) {
                        themeID = "default"; appearance = 0; haptics = true; degrees = true
                        sciDefault = false; sigDigits = 0; aiModel = ""
                    }
                }
            }
        }
    }

    private var swatches: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 16) {
            ForEach(AppTheme.all) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.45)) { themeID = t.id }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [t.accent, t.accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                            if themeID == t.id {
                                Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .overlay(Circle().strokeBorder(themeID == t.id ? t.accent : Color.clear, lineWidth: 3).padding(-5))
                        Text(t.name).font(.caption).foregroundStyle(themeID == t.id ? Color.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.vertical, 6)
    }
}
