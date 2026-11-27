import Foundation
import Observation

/// Live rates from frankfurter.dev (free, no key). Cached so it still works offline.
@MainActor @Observable
final class CurrencyService {
    var rates: [String: Double] = ["USD": 1, "EUR": 0.92]
    var updated: Date?
    var error: String?

    private struct Response: Decodable { let base: String; let rates: [String: Double] }

    init() {
        if let cached = UserDefaults.standard.dictionary(forKey: "fx.rates") as? [String: Double], !cached.isEmpty {
            rates = cached
            updated = UserDefaults.standard.object(forKey: "fx.date") as? Date
        }
    }

    func refresh() async {
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(Response.self, from: data)
            var all = r.rates
            all[r.base] = 1
            rates = all
            updated = Date()
            error = nil
            UserDefaults.standard.set(all, forKey: "fx.rates")
            UserDefaults.standard.set(updated, forKey: "fx.date")
        } catch {
            self.error = "Couldn't refresh rates (check your internet; on Mac enable Outgoing Connections in App Sandbox). Showing the last saved ones."
        }
    }
}
