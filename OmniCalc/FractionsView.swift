import SwiftUI

/// Embedded in the Calculate tab (no NavigationStack of its own).
struct FractionsView: View {
    @Environment(\.theme) private var theme
    @AppStorage("sigDigits") private var sigDigits = 0
    @State private var an = "1"
    @State private var ad = "2"
    @State private var bn = "1"
    @State private var bd = "3"
    @State private var op = "+"
    @State private var decimal = "0.375"

    private var a: Fraction? { Fraction(Int(an) ?? 0, Int(ad) ?? 0) }
    private var b: Fraction? { Fraction(Int(bn) ?? 0, Int(bd) ?? 0) }
    private var result: Fraction? {
        guard let a, let b else { return nil }
        switch op {
        case "+": return a.add(b)
        case "−": return a.sub(b)
        case "×": return a.mul(b)
        default: return a.div(b)
        }
    }
    private var fromDecimal: Fraction? {
        guard let d = Double(decimal.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return Fraction.approximate(d)
    }

    var body: some View {
        Form {
            Section("Calculate") {
                HStack(spacing: 12) {
                    FractionField(num: $an, den: $ad)
                    Picker("", selection: $op) { ForEach(["+", "−", "×", "÷"], id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.menu).labelsHidden()
                    FractionField(num: $bn, den: $bd)
                }.frame(maxWidth: .infinity)
                if let r = result {
                    row("Fraction", r.text)
                    row("Mixed number", r.mixed)
                    row("Decimal", ExpressionEngine.format(r.value))
                } else {
                    Text("Check the denominators (can't be 0) and the divisor.").foregroundStyle(.secondary)
                }
            }
            Section("Decimal → fraction") {
                TextField("Decimal", text: $decimal).numericKeyboard()
                if let f = fromDecimal {
                    row("Fraction", f.text)
                    row("Mixed number", f.mixed)
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: result)
        .themedForm()
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(theme.accent)
                .contentTransition(.numericText()).textSelection(.enabled)
        }
    }
}

struct FractionField: View {
    @Environment(\.theme) private var theme
    @Binding var num: String
    @Binding var den: String

    var body: some View {
        VStack(spacing: 4) {
            TextField("n", text: $num)
            Divider()
            TextField("d", text: $den)
        }
        .numericKeyboard().multilineTextAlignment(.center)
        .frame(width: 70).padding(8)
        .background(theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
