import Foundation

extension Formula {
    /// Labels of the outputs, found by probing the formula with dummy inputs.
    var outputLabels: [String] {
        solve(Vals(d: Dictionary(uniqueKeysWithValues: vars.map { ($0.id, 1.0) }))).map(\.label)
    }
    /// Formulas with branching outputs (e.g. quadratic) can't be solved backwards.
    var canReverse: Bool { name != "Quadratic formula" }
}

/// Solves "which value of `key` makes output `target` equal `targetValue`?" for ANY formula
/// by scanning for sign changes across a wide log-spaced grid, then bisecting each one.
enum ReverseSolver {
    static func solve(_ f: Formula, for key: String, target: String,
                      targetValue: Double, known: [String: Double]) -> [Double] {
        func g(_ x: Double) -> Double {
            var d = known; d[key] = x
            guard let o = f.solve(Vals(d: d)).first(where: { $0.label == target }) else { return .nan }
            return o.value - targetValue
        }
        var xs: [Double] = [0]
        for k in -12...24 { let m = pow(10, Double(k) / 3); xs += [m, -m] }
        xs.sort()
        let tol = 1e-6 * max(1, abs(targetValue))
        var roots: [Double] = []
        func add(_ r: Double) {
            if !roots.contains(where: { abs($0 - r) <= 1e-9 * max(1, abs(r)) }) { roots.append(r) }
        }
        for i in 0..<(xs.count - 1) {
            let a = xs[i], b = xs[i + 1]
            let ga = g(a), gb = g(b)
            guard ga.isFinite, gb.isFinite else { continue }
            if ga == 0 { add(a); continue }
            guard ga * gb < 0 else { continue }
            var lo = a, hi = b, glo = ga
            for _ in 0..<100 {
                let mid = (lo + hi) / 2, gm = g(mid)
                if !gm.isFinite { break }
                if glo * gm <= 0 { hi = mid } else { lo = mid; glo = gm }
            }
            let r = (lo + hi) / 2
            if abs(g(r)) < tol { add(r) }   // rejects asymptotes like 1/x
        }
        if let last = xs.last, g(last) == 0 { add(last) }
        return Array(roots.sorted().prefix(4))
    }
}
