import SwiftUI

struct UnitOption: Identifiable {
    var id: String { name }
    let name: String
    let unit: Dimension
}

private func opts<U: Dimension>(_ items: [(String, U)]) -> [UnitOption] {
    items.map { UnitOption(name: $0.0, unit: $0.1) }
}

enum UnitCategory: String, CaseIterable, Identifiable {
    case currency = "Currency", length = "Length", mass = "Mass", temperature = "Temperature"
    case power = "Power", energy = "Energy", speed = "Speed", pressure = "Pressure"
    case volume = "Volume", area = "Area", time = "Time"
    var id: String { rawValue }

    var units: [UnitOption] {
        switch self {
        case .currency: return []
        case .length: return opts([("Meters", UnitLength.meters), ("Kilometers", .kilometers), ("Centimeters", .centimeters), ("Millimeters", .millimeters), ("Inches", .inches), ("Feet", .feet), ("Yards", .yards), ("Miles", .miles), ("Nautical miles", .nauticalMiles)])
        case .mass: return opts([("Kilograms", UnitMass.kilograms), ("Grams", .grams), ("Milligrams", .milligrams), ("Pounds", .pounds), ("Ounces", .ounces), ("Stones", .stones)])
        case .temperature: return opts([("Celsius", UnitTemperature.celsius), ("Fahrenheit", .fahrenheit), ("Kelvin", .kelvin)])
        case .power: return opts([("Watts", UnitPower.watts), ("Kilowatts", .kilowatts), ("Megawatts", .megawatts), ("Milliwatts", .milliwatts), ("Horsepower", .horsepower)])
        case .energy: return opts([("Joules", UnitEnergy.joules), ("Kilojoules", .kilojoules), ("Calories", .calories), ("Kilocalories", .kilocalories), ("Kilowatt-hours", .kilowattHours)])
        case .speed: return opts([("m/s", UnitSpeed.metersPerSecond), ("km/h", .kilometersPerHour), ("mph", .milesPerHour), ("Knots", .knots)])
        case .pressure: return opts([("Kilopascals", UnitPressure.kilopascals), ("Hectopascals", .hectopascals), ("Bar", .bars), ("PSI", .poundsForcePerSquareInch), ("mmHg", .millimetersOfMercury)])
        case .volume: return opts([("Liters", UnitVolume.liters), ("Milliliters", .milliliters), ("Cubic meters", .cubicMeters), ("Gallons (US)", .gallons), ("Pints", .pints), ("Cups", .cups), ("Fluid ounces", .fluidOunces), ("Tablespoons", .tablespoons), ("Teaspoons", .teaspoons)])
        case .area: return opts([("Square meters", UnitArea.squareMeters), ("Square km", .squareKilometers), ("Square feet", .squareFeet), ("Square miles", .squareMiles), ("Acres", .acres), ("Hectares", .hectares)])
        case .time: return opts([("Seconds", UnitDuration.seconds), ("Minutes", .minutes), ("Hours", .hours), ("Milliseconds", .milliseconds)])
        }
    }
}

struct ConvertView: View {
    @Environment(\.theme) private var theme
    @State private var fx = CurrencyService()
    @State private var category = UnitCategory.length
    @State private var amount = "1"
    @State private var from = "Meters"
    @State private var to = "Feet"
    @State private var swapTurns = 0.0
    @State private var copied = false
    @AppStorage("sigDigits") private var sigDigits = 0

    private var names: [String] {
        category == .currency ? fx.rates.keys.sorted() : category.units.map(\.name)
    }

    private var amountValue: Double? { Double(amount.replacingOccurrences(of: ",", with: ".")) }

    private func convert(_ v: Double, to target: String) -> Double? {
        if category == .currency {
            guard let a = fx.rates[from], let b = fx.rates[target] else { return nil }
            return v / a * b
        }
        let units = category.units
        guard let f = units.first(where: { $0.name == from }), let t = units.first(where: { $0.name == target }) else { return nil }
        return Measurement(value: v, unit: f.unit).converted(to: t.unit).value
    }

    private func display(_ x: Double) -> String {
        category == .currency ? x.formatted(.number.precision(.fractionLength(2...4))) : ExpressionEngine.format(x)
    }

    private var result: String? {
        guard let v = amountValue, let x = convert(v, to: to) else { return nil }
        return display(x)
    }

    private var others: [(String, String)] {
        guard let v = amountValue else { return [] }
        let popular = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "NZD", "CNY", "INR", "SGD"].filter { fx.rates[$0] != nil }
        let targets = category == .currency ? popular : category.units.map(\.name)
        return targets.filter { $0 != from }.compactMap { t in convert(v, to: t).map { (t, display($0)) } }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { chips }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                Section {
                    TextField("Amount", text: $amount).numericKeyboard()
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                    Picker("From", selection: $from) { ForEach(names, id: \.self) { Text($0).tag($0) } }
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.smooth) { swap(&from, &to); swapTurns += 1 }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill").font(.title)
                                .rotationEffect(.degrees(swapTurns * 180))
                        }.buttonStyle(PressableStyle())
                        Spacer()
                    }
                    Picker("To", selection: $to) { ForEach(names, id: \.self) { Text($0).tag($0) } }
                }
                Section("Result") {
                    HStack {
                        Text(result.map { "\($0) \(to)" } ?? "—")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.accent).minimumScaleFactor(0.5).lineLimit(1)
                            .contentTransition(.numericText()).textSelection(.enabled)
                        Spacer()
                        if let r = result {
                            Button { copyToClipboard(r); copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                                .buttonStyle(PressableStyle())
                        }
                    }
                }
                if !others.isEmpty {
                    Section("Also equals") {
                        ForEach(others, id: \.0) { LabeledContent($0.0, value: $0.1) }
                    }
                }
                if category == .currency {
                    Section {
                        if let u = fx.updated { Text("Rates updated \(u.formatted(date: .abbreviated, time: .shortened))") }
                        if let e = fx.error { Text(e).foregroundStyle(.orange) }
                        Button("Refresh rates") { Task { await fx.refresh() } }
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: category)
            .animation(.snappy(duration: 0.2), value: result)
            .themedForm()
            .navigationTitle("Convert")
            .onChange(of: category) { _, _ in setDefaults() }
            .task { await fx.refresh() }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UnitCategory.allCases) { c in
                    Button { withAnimation(.smooth) { category = c } } label: {
                        Text(c.rawValue).font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(category == c ? theme.accent : Color.primary.opacity(0.08), in: Capsule())
                            .foregroundStyle(category == c ? Color.white : Color.primary)
                    }.buttonStyle(PressableStyle())
                }
            }.padding(.horizontal, 4)
        }
    }

    private func setDefaults() {
        if category == .currency { from = "USD"; to = "EUR"; return }
        let n = names
        from = n.first ?? ""
        to = n.dropFirst().first ?? from
    }
}
