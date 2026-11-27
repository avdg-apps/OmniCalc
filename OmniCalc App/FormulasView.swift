import SwiftUI

enum Favourites {
    static func set(_ raw: String) -> Set<String> { Set(raw.split(separator: "|").map(String.init)) }
    static func toggled(_ name: String, in raw: String) -> String {
        var s = set(raw)
        if s.contains(name) { s.remove(name) } else { s.insert(name) }
        return s.sorted().joined(separator: "|")
    }
}

extension Formula {
    static func icon(for category: String) -> String {
        switch category {
        case "Geometry": return "triangle"
        case "Algebra": return "x.squareroot"
        case "Trigonometry": return "angle"
        case "Vectors": return "arrow.up.right"
        case "Physics": return "atom"
        default: return "dollarsign.circle"
        }
    }
}

struct FormulasView: View {
    @Environment(\.theme) private var theme
    @State private var query = ""
    @AppStorage("favFormulas") private var favRaw = ""

    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    private var results: [Formula] {
        Formula.all.map { ($0, Fuzzy.score(query, in: $0)) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if !searching {
                    let favs = Favourites.set(favRaw)
                    if !favs.isEmpty {
                        Section("★ Favourites") { ForEach(Formula.all.filter { favs.contains($0.name) }) { row($0) } }
                    }
                    ForEach(Formula.categories, id: \.self) { cat in
                        Section(cat) { ForEach(Formula.all.filter { $0.category == cat }) { row($0) } }
                    }
                } else if results.isEmpty {
                    Text("No formulas match “\(query)”").foregroundStyle(.secondary)
                } else {
                    ForEach(results) { row($0) }
                }
            }
            .animation(.smooth(duration: 0.25), value: query)
            .animation(.smooth(duration: 0.25), value: favRaw)
            .themedList()
            .navigationTitle("Formulas")
            .searchable(text: $query, prompt: "Try “circle”, “mgh”, “loan”…")
        }
    }

    private func row(_ f: Formula) -> some View {
        NavigationLink {
            FormulaDetailView(formula: f)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: Formula.icon(for: f.category))
                    .foregroundStyle(theme.accent).frame(width: 30, height: 30)
                    .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name)
                    Text(f.expression).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if Favourites.set(favRaw).contains(f.name) {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                }
            }
        }
    }
}

struct FormulaDetailView: View {
    let formula: Formula
    @Environment(\.theme) private var theme
    @State private var inputs: [String: String]
    @State private var solveFor = ""        // "" = compute the result
    @State private var targetLabel = ""
    @AppStorage("favFormulas") private var favRaw = ""
    @AppStorage("sigDigits") private var sigDigits = 0

    init(formula: Formula) {
        self.formula = formula
        _inputs = State(initialValue: formula.defaults.mapValues { ExpressionEngine.format($0) })
    }

    private var targets: [String] { formula.outputLabels }
    private var activeTarget: String { targetLabel.isEmpty ? (targets.first ?? "") : targetLabel }

    private func number(_ key: String) -> Double? {
        Double((inputs[key] ?? "").replacingOccurrences(of: ",", with: "."))
    }

    /// Numeric values of every variable except the one being solved for.
    private var known: [String: Double]? {
        var d: [String: Double] = [:]
        for v in formula.vars where v.id != solveFor {
            guard let x = number(v.id) else { return nil }
            d[v.id] = x
        }
        return d
    }

    private func field(_ label: String, _ key: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: Binding(get: { inputs[key] ?? "" }, set: { inputs[key] = $0 }))
                .multilineTextAlignment(.trailing).numericKeyboard().frame(width: 120)
        }
    }

    var body: some View {
        Form {
            Section {
                Text(formula.expression)
                    .font(.system(.title2, design: .monospaced)).foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
            }
            if formula.canReverse {
                Section("Solve for") {
                    Picker("Find", selection: $solveFor.animation(.smooth)) {
                        Text("Result").tag("")
                        ForEach(formula.vars) { Text($0.label).tag($0.id) }
                    }
                }
            }
            Section("Inputs") {
                ForEach(formula.vars.filter { $0.id != solveFor }) { v in field(v.label, v.id) }
                if !solveFor.isEmpty {
                    if targets.count > 1 {
                        Picker("Known result", selection: $targetLabel) {
                            ForEach(targets, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    field(activeTarget + " (known)", "__target")
                }
            }
            Section("Result") { resultRows }
        }
        .animation(.smooth(duration: 0.25), value: solveFor)
        .themedForm()
        .navigationTitle(formula.name).inlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { favRaw = Favourites.toggled(formula.name, in: favRaw) } label: {
                    Image(systemName: Favourites.set(favRaw).contains(formula.name) ? "star.fill" : "star")
                }
            }
        }
        .onChange(of: solveFor) { _, _ in targetLabel = "" }
    }

    private func value(_ label: String, _ text: String) -> some View {
        LabeledContent(label) {
            Text(text).font(.title3.weight(.semibold)).foregroundStyle(theme.accent)
                .contentTransition(.numericText()).textSelection(.enabled)
        }
    }

    @ViewBuilder private var resultRows: some View {
        if let k = known {
            if solveFor.isEmpty {
                ForEach(formula.solve(Vals(d: k))) { o in
                    value(o.label, o.value.isNaN ? "—" : ExpressionEngine.format(o.value))
                }
            } else if let t = number("__target") {
                let name = formula.vars.first { $0.id == solveFor }?.label ?? solveFor
                let roots = ReverseSolver.solve(formula, for: solveFor, target: activeTarget, targetValue: t, known: k)
                if roots.isEmpty {
                    Text("No solution found for these values").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(roots.enumerated()), id: \.offset) { i, r in
                        value(roots.count > 1 ? "\(name) (option \(i + 1))" : name, ExpressionEngine.format(r))
                    }
                }
            } else { Text("Enter all values").foregroundStyle(.secondary) }
        } else { Text("Enter all values").foregroundStyle(.secondary) }
    }
}
