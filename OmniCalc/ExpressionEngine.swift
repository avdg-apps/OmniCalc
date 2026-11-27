import Foundation

enum CalcError: LocalizedError {
    case syntax, divideByZero, domain
    var errorDescription: String? {
        switch self {
        case .syntax: return "Syntax error"
        case .divideByZero: return "Can't divide by zero"
        case .domain: return "Math error"
        }
    }
}

/// Recursive-descent expression evaluator: + - * / ^ ! %, brackets, implicit multiplication,
/// constants (pi, e, ans) and common functions. Missing closing brackets are tolerated.
struct ExpressionEngine {
    var degrees = true
    var ans = 0.0

    enum Token: Equatable { case num(Double), name(String), op(Character), open, close, comma }

    func evaluate(_ text: String) throws -> Double {
        var p = Parser(tokens: try tokenize(text), engine: self)
        let v = try p.parseExpression()
        guard p.atEnd else { throw CalcError.syntax }
        guard v.isFinite else { throw CalcError.domain }
        return v
    }

    /// 12 significant digits, so 0.1 + 0.2 shows as 0.3.
    static func format(_ v: Double) -> String {
        guard v.isFinite else { return "Error" }
        if abs(v) < 1e-12 { return "0" }
        let stored = UserDefaults.standard.integer(forKey: "sigDigits")
        return String(format: "%.\(stored == 0 ? 12 : stored)g", v)
    }

    func tokenize(_ s: String) throws -> [Token] {
        let cleaned = s.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "√", with: "sqrt")
        let chars = Array(cleaned)
        var out: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c.isNumber || c == "." {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                guard let v = Double(String(chars[i..<j])) else { throw CalcError.syntax }
                out.append(.num(v)); i = j
            } else if c.isLetter {
                var j = i
                while j < chars.count, chars[j].isLetter { j += 1 }
                out.append(.name(String(chars[i..<j]).lowercased())); i = j
            } else {
                switch c {
                case "(": out.append(.open)
                case ")": out.append(.close)
                case ",": out.append(.comma)
                case "+", "-", "*", "/", "^", "%", "!": out.append(.op(c))
                default: throw CalcError.syntax
                }
                i += 1
            }
        }
        return out
    }

    func constant(_ n: String) -> Double? {
        switch n {
        case "pi": return .pi
        case "tau": return 2 * .pi
        case "e": return M_E
        case "ans": return ans
        default: return nil
        }
    }

    func factorial(_ x: Double) throws -> Double {
        guard x >= 0, x == x.rounded(), x <= 170 else { throw CalcError.domain }
        return tgamma(x + 1).rounded()
    }

    func apply(_ n: String, _ a: [Double]) throws -> Double {
        func one() throws -> Double { guard a.count == 1 else { throw CalcError.syntax }; return a[0] }
        func two() throws -> (Double, Double) { guard a.count == 2 else { throw CalcError.syntax }; return (a[0], a[1]) }
        let k = degrees ? Double.pi / 180 : 1
        switch n {
        case "sin": return sin(try one() * k)
        case "cos": return cos(try one() * k)
        case "tan": return tan(try one() * k)
        case "asin": let x = try one(); guard abs(x) <= 1 else { throw CalcError.domain }; return asin(x) / k
        case "acos": let x = try one(); guard abs(x) <= 1 else { throw CalcError.domain }; return acos(x) / k
        case "atan": return atan(try one()) / k
        case "sinh": return sinh(try one())
        case "cosh": return cosh(try one())
        case "tanh": return tanh(try one())
        case "ln": let x = try one(); guard x > 0 else { throw CalcError.domain }; return log(x)
        case "log": let x = try one(); guard x > 0 else { throw CalcError.domain }; return log10(x)
        case "logb": let (b, x) = try two(); guard b > 0, b != 1, x > 0 else { throw CalcError.domain }; return log(x) / log(b)
        case "sqrt": let x = try one(); guard x >= 0 else { throw CalcError.domain }; return x.squareRoot()
        case "cbrt": return cbrt(try one())
        case "root": let (r, x) = try two(); guard r != 0 else { throw CalcError.domain }; return pow(x, 1 / r)
        case "abs": return abs(try one())
        case "exp": return exp(try one())
        case "floor": return floor(try one())
        case "ceil": return ceil(try one())
        case "round": return (try one()).rounded()
        case "fact": return try factorial(try one())
        case "pow": let (b, x) = try two(); return pow(b, x)
        case "mod": let (x, y) = try two(); guard y != 0 else { throw CalcError.divideByZero }; return x.truncatingRemainder(dividingBy: y)
        case "ncr": let (nn, r) = try two(); return try factorial(nn) / (try factorial(r) * (try factorial(nn - r)))
        case "npr": let (nn, r) = try two(); return try factorial(nn) / (try factorial(nn - r))
        default: throw CalcError.syntax
        }
    }

    struct Parser {
        let tokens: [Token]
        let engine: ExpressionEngine
        var pos = 0
        init(tokens: [Token], engine: ExpressionEngine) { self.tokens = tokens; self.engine = engine }
        var atEnd: Bool { pos >= tokens.count }
        var peek: Token? { pos < tokens.count ? tokens[pos] : nil }

        mutating func parseExpression() throws -> Double {
            var v = try parseTerm()
            while case .op(let o)? = peek, o == "+" || o == "-" {
                pos += 1
                let r = try parseTerm()
                v = o == "+" ? v + r : v - r
            }
            return v
        }

        mutating func parseTerm() throws -> Double {
            var v = try parseUnary()
            while let t = peek {
                switch t {
                case .op("*"): pos += 1; v *= try parseUnary()
                case .op("/"):
                    pos += 1
                    let d = try parseUnary()
                    if d == 0 { throw CalcError.divideByZero }
                    v /= d
                case .num, .name, .open: v *= try parseUnary()   // implicit multiplication
                default: return v
                }
            }
            return v
        }

        mutating func parseUnary() throws -> Double {
            if case .op(let o)? = peek, o == "-" || o == "+" {
                pos += 1
                let v = try parseUnary()
                return o == "-" ? -v : v
            }
            return try parsePower()
        }

        mutating func parsePower() throws -> Double {
            let base = try parsePostfix()
            if case .op("^")? = peek {
                pos += 1
                return pow(base, try parseUnary())
            }
            return base
        }

        mutating func parsePostfix() throws -> Double {
            var v = try parsePrimary()
            while case .op(let o)? = peek, o == "!" || o == "%" {
                pos += 1
                v = o == "%" ? v / 100 : try engine.factorial(v)
            }
            return v
        }

        mutating func parsePrimary() throws -> Double {
            guard let t = peek else { throw CalcError.syntax }
            pos += 1
            switch t {
            case .num(let v): return v
            case .open:
                let v = try parseExpression()
                if case .close? = peek { pos += 1 } else if !atEnd { throw CalcError.syntax }
                return v
            case .name(let n):
                if let c = engine.constant(n) { return c }
                var args: [Double] = []
                if case .open? = peek {
                    pos += 1
                    if case .close? = peek { pos += 1 } else {
                        args.append(try parseExpression())
                        while case .comma? = peek { pos += 1; args.append(try parseExpression()) }
                        if case .close? = peek { pos += 1 } else if !atEnd { throw CalcError.syntax }
                    }
                } else {
                    args = [try parseUnary()]   // allows "sqrt 9"
                }
                return try engine.apply(n, args)
            default: throw CalcError.syntax
            }
        }
    }
}
