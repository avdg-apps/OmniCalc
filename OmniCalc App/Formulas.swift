import Foundation

struct Vals {
    let d: [String: Double]
    subscript(_ k: String) -> Double { d[k] ?? 0 }
}

struct Variable: Identifiable { let id: String; let label: String }
struct Output: Identifiable {
    var id: String { label }
    let label: String; let value: Double
    init(_ label: String, _ value: Double) { self.label = label; self.value = value }
}

struct Formula: Identifiable {
    let id = UUID()
    let name: String, category: String, expression: String
    let keywords: [String]
    let vars: [Variable]
    let defaults: [String: Double]
    let solve: (Vals) -> [Output]

    init(_ name: String, _ category: String, _ expression: String, _ keywords: [String],
         _ vars: [(String, String)], defaults: [String: Double] = [:], solve: @escaping (Vals) -> [Output]) {
        self.name = name; self.category = category; self.expression = expression
        self.keywords = keywords; self.vars = vars.map { Variable(id: $0.0, label: $0.1) }; self.defaults = defaults; self.solve = solve
    }
}

enum Fuzzy {
    static func score(_ query: String, in f: Formula) -> Int {
        let hay = ([f.name, f.category, f.expression] + f.keywords).map { $0.lowercased() }
        var total = 0
        for token in query.lowercased().split(separator: " ") {
            let t = String(token)
            var best = 0
            for h in hay {
                if h.split(whereSeparator: { !$0.isLetter }).contains(where: { $0.hasPrefix(t) }) { best = max(best, 5) }
                else if h.contains(t) || h.replacingOccurrences(of: " ", with: "").contains(t) { best = max(best, 4) }
                else if t.count >= 3, isSubsequence(t, of: h) { best = max(best, 1) }
            }
            if best == 0 { return 0 }
            total += best
        }
        return total
    }

    private static func isSubsequence(_ s: String, of text: String) -> Bool {
        var it = text.makeIterator()
        for c in s { var found = false; while let n = it.next() { if n == c { found = true; break } }; if !found { return false } }
        return true
    }
}

extension Formula {
    static let categories = ["Geometry", "Algebra", "Trigonometry", "Vectors", "Physics", "Finance"]

    static let all: [Formula] = [
        // Geometry
        Formula("Area of a circle", "Geometry", "A = πr²", ["circle", "round", "pi r squared"], [("r", "Radius")]) { v in [Output("Area", .pi * v["r"] * v["r"])] },
        Formula("Circumference of a circle", "Geometry", "C = 2πr", ["circle", "perimeter"], [("r", "Radius")]) { v in [Output("Circumference", 2 * .pi * v["r"])] },
        Formula("Area of a triangle", "Geometry", "A = ½ b h", ["triangle", "base height"], [("b", "Base"), ("h", "Height")]) { v in [Output("Area", 0.5 * v["b"] * v["h"])] },
        Formula("Pythagorean theorem", "Geometry", "c = √(a² + b²)", ["right angle", "hypotenuse", "triangle"], [("a", "Side a"), ("b", "Side b")]) { v in [Output("Hypotenuse c", (v["a"] * v["a"] + v["b"] * v["b"]).squareRoot())] },
        Formula("Volume of a sphere", "Geometry", "V = 4/3 πr³", ["ball", "sphere"], [("r", "Radius")]) { v in [Output("Volume", 4.0 / 3.0 * .pi * pow(v["r"], 3))] },
        Formula("Volume of a cylinder", "Geometry", "V = πr²h", ["can", "tube", "cylinder"], [("r", "Radius"), ("h", "Height")]) { v in [Output("Volume", .pi * v["r"] * v["r"] * v["h"])] },
        Formula("Area of a trapezium", "Geometry", "A = ½(a + b)h", ["trapezoid", "trapezium"], [("a", "Parallel side a"), ("b", "Parallel side b"), ("h", "Height")]) { v in [Output("Area", 0.5 * (v["a"] + v["b"]) * v["h"])] },
        // Algebra
        Formula("Quadratic formula", "Algebra", "x = (−b ± √(b² − 4ac)) / 2a", ["quadratic", "roots", "discriminant", "ax2 bx c"], [("a", "a"), ("b", "b"), ("c", "c")]) { v in
            let a = v["a"], b = v["b"], c = v["c"]
            guard a != 0 else { return [Output("Error: a can't be 0", .nan)] }
            let d = b * b - 4 * a * c
            guard d >= 0 else { return [Output("Discriminant (no real roots)", d)] }
            return [Output("Discriminant", d), Output("x₁", (-b + d.squareRoot()) / (2 * a)), Output("x₂", (-b - d.squareRoot()) / (2 * a))]
        },
        Formula("Slope of a line", "Algebra", "m = (y₂ − y₁) / (x₂ − x₁)", ["gradient", "rise run"], [("x1", "x₁"), ("y1", "y₁"), ("x2", "x₂"), ("y2", "y₂")]) { v in [Output("Slope m", (v["y2"] - v["y1"]) / (v["x2"] - v["x1"]))] },
        Formula("Distance between two points", "Algebra", "d = √((x₂−x₁)² + (y₂−y₁)²)", ["coordinates", "length"], [("x1", "x₁"), ("y1", "y₁"), ("x2", "x₂"), ("y2", "y₂")]) { v in [Output("Distance", (pow(v["x2"] - v["x1"], 2) + pow(v["y2"] - v["y1"], 2)).squareRoot())] },
        // Trigonometry
        Formula("Law of cosines", "Trigonometry", "c² = a² + b² − 2ab cos C", ["triangle", "side", "angle"], [("a", "Side a"), ("b", "Side b"), ("C", "Angle C (degrees)")]) { v in
            [Output("Side c", (v["a"] * v["a"] + v["b"] * v["b"] - 2 * v["a"] * v["b"] * cos(v["C"] * .pi / 180)).squareRoot())] },
        Formula("Triangle area (two sides + angle)", "Trigonometry", "A = ½ab sin C", ["sas", "sine"], [("a", "Side a"), ("b", "Side b"), ("C", "Angle C (degrees)")]) { v in [Output("Area", 0.5 * v["a"] * v["b"] * sin(v["C"] * .pi / 180))] },
        // Vectors
        Formula("Vector magnitude (2D)", "Vectors", "|v| = √(x² + y²)", ["vector", "length", "direction", "bearing"], [("x", "x"), ("y", "y")]) { v in
            [Output("Magnitude", (v["x"] * v["x"] + v["y"] * v["y"]).squareRoot()), Output("Direction (° from +x)", atan2(v["y"], v["x"]) * 180 / .pi)] },
        Formula("Dot product (2D)", "Vectors", "a·b = aₓbₓ + a_y b_y", ["vector", "scalar product"], [("ax", "aₓ"), ("ay", "a_y"), ("bx", "bₓ"), ("by", "b_y")]) { v in [Output("a · b", v["ax"] * v["bx"] + v["ay"] * v["by"])] },
        // Physics
        Formula("Speed", "Physics", "v = d / t", ["velocity", "distance", "time"], [("d", "Distance"), ("t", "Time")]) { v in [Output("Speed", v["d"] / v["t"])] },
        Formula("Force (Newton's 2nd law)", "Physics", "F = m a", ["newton", "acceleration"], [("m", "Mass (kg)"), ("a", "Acceleration (m/s²)")]) { v in [Output("Force (N)", v["m"] * v["a"])] },
        Formula("Kinetic energy", "Physics", "KE = ½ m v²", ["energy", "motion"], [("m", "Mass (kg)"), ("v", "Speed (m/s)")]) { v in [Output("Energy (J)", 0.5 * v["m"] * v["v"] * v["v"])] },
        Formula("Gravitational potential energy", "Physics", "PE = m g h", ["gpe", "mgh", "height", "gravity"], [("m", "Mass (kg)"), ("g", "Gravity (m/s²)"), ("h", "Height (m)")], defaults: ["g": 9.81]) { v in [Output("Energy (J)", v["m"] * v["g"] * v["h"])] },
        Formula("Ohm's law", "Physics", "V = I R", ["voltage", "current", "resistance", "electric"], [("I", "Current (A)"), ("R", "Resistance (Ω)")]) { v in [Output("Voltage (V)", v["I"] * v["R"])] },
        Formula("Electrical power", "Physics", "P = V I", ["watts", "voltage", "current"], [("V", "Voltage (V)"), ("I", "Current (A)")]) { v in [Output("Power (W)", v["V"] * v["I"])] },
        Formula("Appliance energy & cost", "Physics", "kWh = W × h / 1000", ["watts", "electricity bill", "power usage"], [("P", "Power (W)"), ("t", "Hours used"), ("c", "Price per kWh")]) { v in
            let kwh = v["P"] * v["t"] / 1000
            return [Output("Energy (kWh)", kwh), Output("Cost", kwh * v["c"])] },
        Formula("Density", "Physics", "ρ = m / V", ["mass", "volume"], [("m", "Mass"), ("V", "Volume")]) { v in [Output("Density", v["m"] / v["V"])] },
        Formula("Momentum", "Physics", "p = m v", ["mass", "velocity"], [("m", "Mass (kg)"), ("v", "Velocity (m/s)")]) { v in [Output("Momentum", v["m"] * v["v"])] },
        Formula("Work done", "Physics", "W = F d", ["force", "distance", "joules"], [("F", "Force (N)"), ("d", "Distance (m)")]) { v in [Output("Work (J)", v["F"] * v["d"])] },
        // Finance
        Formula("Simple interest", "Finance", "I = P r t", ["savings", "loan", "interest"], [("P", "Principal"), ("r", "Rate (% per year)"), ("t", "Years")]) { v in [Output("Interest", v["P"] * v["r"] / 100 * v["t"])] },
        Formula("Compound interest", "Finance", "A = P(1 + r/n)^(nt)", ["savings", "investment", "growth"], [("P", "Principal"), ("r", "Rate (% per year)"), ("n", "Times per year"), ("t", "Years")]) { v in
            let a = v["P"] * pow(1 + v["r"] / 100 / v["n"], v["n"] * v["t"])
            return [Output("Final amount", a), Output("Interest earned", a - v["P"])] },
        Formula("Percentage change", "Finance", "% = (new − old) / old × 100", ["increase", "decrease", "percent"], [("old", "Old value"), ("new", "New value")]) { v in [Output("Change (%)", (v["new"] - v["old"]) / v["old"] * 100)] },
        Formula("Loan repayment", "Finance", "M = P r / (1 − (1+r)^−n)", ["mortgage", "monthly payment", "car loan"], [("P", "Loan amount"), ("rate", "Rate (% per year)"), ("y", "Years")]) { v in
            let r = v["rate"] / 100 / 12, n = v["y"] * 12
            let m = r == 0 ? v["P"] / n : v["P"] * r / (1 - pow(1 + r, -n))
            return [Output("Monthly payment", m), Output("Total repaid", m * n)] },
        // More
        Formula("Area of a rectangle", "Geometry", "A = l w", ["rectangle", "square", "length width"], [("l", "Length"), ("w", "Width")]) { v in [Output("Area", v["l"] * v["w"]), Output("Perimeter", 2 * (v["l"] + v["w"]))] },
        Formula("Volume of a cone", "Geometry", "V = ⅓ π r² h", ["cone"], [("r", "Radius"), ("h", "Height")]) { v in [Output("Volume", .pi * v["r"] * v["r"] * v["h"] / 3)] },
        Formula("Surface area of a sphere", "Geometry", "A = 4πr²", ["sphere", "ball"], [("r", "Radius")]) { v in [Output("Surface area", 4 * .pi * v["r"] * v["r"])] },
        Formula("Acceleration", "Physics", "a = (v − u) / t", ["velocity change", "speed up"], [("u", "Initial speed"), ("v", "Final speed"), ("t", "Time")]) { v in [Output("Acceleration", (v["v"] - v["u"]) / v["t"])] },
        Formula("Pressure", "Physics", "P = F / A", ["force", "area", "pascal"], [("F", "Force (N)"), ("A", "Area (m²)")]) { v in [Output("Pressure (Pa)", v["F"] / v["A"])] },
        Formula("Wave speed", "Physics", "v = f λ", ["frequency", "wavelength", "sound", "light"], [("f", "Frequency (Hz)"), ("l", "Wavelength (m)")]) { v in [Output("Speed (m/s)", v["f"] * v["l"])] },
        Formula("Power (work over time)", "Physics", "P = W / t", ["watts", "energy", "joules"], [("W", "Work / energy (J)"), ("t", "Time (s)")]) { v in [Output("Power (W)", v["W"] / v["t"])] },
        Formula("Discount price", "Finance", "price = original × (1 − d%)", ["sale", "percent off"], [("p", "Original price"), ("d", "Discount (%)")]) { v in [Output("Sale price", v["p"] * (1 - v["d"] / 100)), Output("You save", v["p"] * v["d"] / 100)] },
        Formula("Add tax (GST / VAT)", "Finance", "total = price × (1 + t%)", ["gst", "vat", "sales tax"], [("p", "Price before tax"), ("t", "Tax rate (%)")]) { v in [Output("Total with tax", v["p"] * (1 + v["t"] / 100)), Output("Tax amount", v["p"] * v["t"] / 100)] },
    ]
}
