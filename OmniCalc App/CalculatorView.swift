import SwiftUI
import Observation

struct HistoryItem: Identifiable { let id = UUID(); let expr: String; let result: String }

@Observable
final class CalculatorModel {
    var expression = ""
    var history: [HistoryItem] = []
    var degrees = true
    var errorMessage: String?
    @ObservationIgnored private var ans = 0.0
    @ObservationIgnored private var justEvaluated = false
    @ObservationIgnored private let functions: Set<String> = ["sin", "cos", "tan", "asin", "acos", "atan", "ln", "log", "√"]
    @ObservationIgnored private let operators: Set<String> = ["+", "−", "×", "÷", "^", "%", "!"]

    /// Derived, never stored: always matches the current expression.
    var preview: String {
        if let e = errorMessage { return e }
        guard !expression.isEmpty, !justEvaluated, let v = try? engine().evaluate(expression) else { return "" }
        return ExpressionEngine.format(v)
    }

    func press(_ key: String) {
        if key == "=" { equals(); return }
        errorMessage = nil
        switch key {
        case "AC": expression = ""; justEvaluated = false
        case "⌫": backspace()
        default:
            if justEvaluated {
                if !operators.contains(key) { expression = "" }
                justEvaluated = false
            }
            expression += functions.contains(key) ? key + "(" : key
        }
    }

    func load(_ expr: String) { errorMessage = nil; expression = expr; justEvaluated = false }

    private func backspace() {
        if justEvaluated { expression = ""; justEvaluated = false; return }
        guard !expression.isEmpty else { return }
        if expression.hasSuffix("(") {
            expression.removeLast()
            while let l = expression.last, l.isLetter || l == "√" { expression.removeLast() }
        } else { expression.removeLast() }
    }

    private func engine() -> ExpressionEngine { var e = ExpressionEngine(); e.degrees = degrees; e.ans = ans; return e }

    private func equals() {
        guard !expression.isEmpty else { return }
        do {
            let v = try engine().evaluate(expression)
            let r = ExpressionEngine.format(v)
            history.insert(HistoryItem(expr: expression, result: r), at: 0)
            ans = v
            expression = r.contains("e") ? "Ans" : r
            errorMessage = nil
            justEvaluated = true
        } catch { errorMessage = error.localizedDescription }
    }
}

struct CalculatorView: View {
    let model: CalculatorModel
    @Environment(\.theme) private var theme
    @AppStorage("angleDegrees") private var degrees = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sigDigits") private var sigDigits = 0
    @State private var scientific: Bool
    @State private var showHistory = false
    @State private var mode = Mode.calculator
    @State private var tick = 0
    @FocusState private var keysFocused: Bool

    enum Mode: String, CaseIterable, Identifiable {
        case calculator = "Calculator", fractions = "Fractions"
        var id: String { rawValue }
    }

    init(model: CalculatorModel) {
        self.model = model
        _scientific = State(initialValue: UserDefaults.standard.bool(forKey: "sciDefault"))
    }

    private let sciRows = [["sin", "cos", "tan", "^", "√"], ["asin", "acos", "atan", "ln", "log"], ["(", ")", "π", "e", "!"]]
    private let mainRows = [["AC", "⌫", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["Ans", "0", ".", "="]]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                switch mode {
                case .calculator: calculator.transition(.opacity)
                case .fractions: FractionsView().transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.35), value: mode)
            .navigationTitle("Calculator").inlineTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(width: 230)
                }
                ToolbarItem(placement: .navigation) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .disabled(mode != .calculator)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { scientific.toggle() } label: {
                        Image(systemName: scientific ? "function" : "square.grid.3x3")
                    }.disabled(mode != .calculator)
                }
            }
            .sheet(isPresented: $showHistory) { HistorySheet(model: model) }
        }
        .onChange(of: degrees, initial: true) { model.degrees = degrees }
        .sensoryFeedback(trigger: tick) { _, _ in haptics ? SensoryFeedback.impact(weight: .light) : nil }
    }

    private var calculator: some View {
        VStack(spacing: 12) {
            display
            if scientific { keyGrid(sciRows, height: 46).transition(.move(edge: .top).combined(with: .opacity)) }
            keyGrid(mainRows, height: 62)
        }
        .animation(.smooth(duration: 0.3), value: scientific)
        .padding(.horizontal).padding(.bottom, 8)
        .frame(maxWidth: 460).frame(maxWidth: .infinity)
        .focusable()
        .focused($keysFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handle($0) }
        .onAppear { keysFocused = true }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Button { degrees.toggle() } label: {
                    Text(degrees ? "DEG" : "RAD").font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(theme.accent)
                }.buttonStyle(PressableStyle())
                Spacer()
            }
            Spacer(minLength: 0)
            Text(model.expression.isEmpty ? "0" : model.expression)
                .font(.system(size: 46, weight: .light, design: .rounded))
                .minimumScaleFactor(0.4).lineLimit(2).multilineTextAlignment(.trailing)
                .foregroundStyle(model.expression.isEmpty ? Color.secondary : Color.primary)
                .contentTransition(.numericText())
            Text(model.preview.isEmpty ? " " : "= " + model.preview)
                .font(.title3.weight(.medium))
                .foregroundStyle(model.errorMessage == nil ? theme.accent : Color.red)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .trailing)
        .cardStyle()
        .animation(.snappy(duration: 0.2), value: model.expression)
        .animation(.snappy(duration: 0.2), value: model.preview)
    }

    /// Defer model changes out of the current view update.
    private func send(_ key: String) {
        tick += 1
        DispatchQueue.main.async { model.press(key) }
    }

    /// Hardware keyboard support (Mac, iPad, Vision Pro).
    private func handle(_ p: KeyPress) -> KeyPress.Result {
        switch p.key {
        case .return: send("="); return .handled
        case .delete, .deleteForward: send("⌫"); return .handled
        case .escape: send("AC"); return .handled
        default: break
        }
        guard let c = p.characters.first else { return .ignored }
        let map: [Character: String] = ["*": "×", "/": "÷", "-": "−", "=": "=", "x": "×"]
        if c.isNumber || ".+()^!%".contains(c) { send(String(c)); return .handled }
        if let m = map[c] { send(m); return .handled }
        return .ignored
    }

    private func keyGrid(_ rows: [[String]], height: CGFloat) -> some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(label: key, height: height) { send(key) }
                    }
                }
            }
        }
    }
}

struct KeyButton: View {
    @Environment(\.theme) private var theme
    let label: String
    let height: CGFloat
    let action: () -> Void

    private var isOp: Bool { ["÷", "×", "−", "+"].contains(label) }
    private var isUtil: Bool { ["AC", "⌫", "%"].contains(label) }
    private var isDigit: Bool { label.first?.isNumber == true || label == "." || label == "Ans" }
    private var fill: Color {
        if label == "=" { return theme.accent }
        if isOp { return theme.accent.opacity(0.18) }
        if isUtil { return Color.primary.opacity(0.10) }
        if isDigit { return theme.keyFill }
        return Color.primary.opacity(0.06)
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: height > 50 ? 26 : 18, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: height)
                .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(isDigit ? 0.06 : 0), radius: 3, y: 1)
                .foregroundStyle(label == "=" ? Color.white : (isOp ? theme.accent : Color.primary))
        }
        .buttonStyle(PressableStyle())
    }
}

struct HistorySheet: View {
    let model: CalculatorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.history) { item in
                Button { model.load(item.expr); dismiss() } label: {
                    VStack(alignment: .trailing) {
                        Text(item.expr).foregroundStyle(.secondary)
                        Text(item.result).font(.title3.weight(.medium))
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .themedList()
            .overlay { if model.history.isEmpty { Text("No history yet").foregroundStyle(.secondary) } }
            .navigationTitle("History").inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Clear") { model.history = [] } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .frame(minWidth: 320, minHeight: 420)
    }
}
