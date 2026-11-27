import Foundation

struct Fraction: Equatable {
    let num: Int
    let den: Int

    init?(_ n: Int, _ d: Int) {
        guard d != 0 else { return nil }
        let g = Fraction.gcd(abs(n), abs(d))
        let s = d < 0 ? -1 : 1
        num = s * n / g
        den = s * d / g
    }

    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? max(a, 1) : gcd(b, a % b) }

    func add(_ o: Fraction) -> Fraction? { Fraction(num * o.den + o.num * den, den * o.den) }
    func sub(_ o: Fraction) -> Fraction? { Fraction(num * o.den - o.num * den, den * o.den) }
    func mul(_ o: Fraction) -> Fraction? { Fraction(num * o.num, den * o.den) }
    func div(_ o: Fraction) -> Fraction? { Fraction(num * o.den, den * o.num) }

    var value: Double { Double(num) / Double(den) }
    var text: String { den == 1 ? "\(num)" : "\(num)/\(den)" }
    var mixed: String {
        let whole = num / den, rem = abs(num) % den
        if den == 1 || whole == 0 { return text }
        return rem == 0 ? "\(whole)" : "\(whole) \(rem)/\(den)"
    }

    /// Best fraction for a decimal, via continued fractions.
    static func approximate(_ x: Double, maxDen: Int = 100_000) -> Fraction? {
        guard x.isFinite, abs(x) < 1e9 else { return nil }
        var h1 = 1, h0 = 0, k1 = 0, k0 = 1
        var b = abs(x)
        for _ in 0..<32 {
            let a = Int(b.rounded(.down))
            let h2 = a * h1 + h0, k2 = a * k1 + k0
            if k2 > maxDen { break }
            h0 = h1; h1 = h2; k0 = k1; k1 = k2
            if abs(Double(h1) / Double(k1) - abs(x)) < 1e-10 { break }
            let frac = b - Double(a)
            if frac < 1e-12 { break }
            b = 1 / frac
        }
        return Fraction(x < 0 ? -h1 : h1, k1)
    }
}
