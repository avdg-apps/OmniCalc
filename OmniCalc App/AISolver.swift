import Foundation

struct AISolution: Codable {
    let interpretation: String?
    let steps: [String]
    let expression: String?
    let answer: String
}

enum AISolverError: LocalizedError {
    case missingKey, rateLimited, http(Int, String), badResponse
    var errorDescription: String? {
        switch self {
        case .missingKey: return "Add your Gemini API key in Secrets.swift first."
        case .rateLimited: return "Free-tier limit reached. Wait a minute and try again."
        case .http(let code, let body): return "AI request failed (\(code)). \(body.prefix(160))"
        case .badResponse: return "The AI returned something unreadable. Try rephrasing."
        }
    }
}

/// Gemini REST call (text and/or photo). To switch provider only this file changes.
enum AISolver {
    private static let systemPrompt = """
    You are a careful maths tutor. If an image is provided, read the question from it. \
    Reply with ONLY a JSON object, no markdown:
    {"interpretation": "one-line restatement of the problem",
     "steps": ["short step 1", "short step 2", ...],
     "expression": "ONE plain arithmetic expression that evaluates to the final numeric answer, using only numbers, + - * / ^ ( ) sqrt sin cos tan ln log pi e (angles in degrees). Use \\"\\" if the answer is not a single number.",
     "answer": "final answer, with units if relevant"}
    """

    static func solve(_ problem: String, image: Data? = nil) async throws -> AISolution {
        guard !AIConfig.isMissingKey else { throw AISolverError.missingKey }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AIConfig.activeModel):generateContent") else { throw AISolverError.badResponse }

        var parts: [[String: Any]] = [["text": problem.isEmpty ? "Solve the problem in the image." : problem]]
        if let image { parts.append(["inline_data": ["mime_type": "image/jpeg", "data": image.base64EncodedString()]]) }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["responseMimeType": "application/json", "temperature": 0.2]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AIConfig.apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Free tier is busy/limited at times: retry politely.
        for attempt in 0..<3 {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw AISolverError.badResponse }
            if [429, 503].contains(http.statusCode) {
                if attempt < 2 { try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 3_000_000_000); continue }
                throw http.statusCode == 429 ? AISolverError.rateLimited : AISolverError.http(503, "Model busy")
            }
            guard http.statusCode == 200 else { throw AISolverError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "") }
            return try parse(data)
        }
        throw AISolverError.badResponse
    }

    private static func parse(_ data: Data) throws -> AISolution {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cands = json["candidates"] as? [[String: Any]],
              let content = cands.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { throw AISolverError.badResponse }
        var text = parts.compactMap { $0["text"] as? String }.joined()
        text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = text.data(using: .utf8), let sol = try? JSONDecoder().decode(AISolution.self, from: d) else { throw AISolverError.badResponse }
        return sol
    }
}
