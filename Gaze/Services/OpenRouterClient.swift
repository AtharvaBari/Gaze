import Foundation

enum OpenRouterClient {
    private static let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    private static let model = "openrouter/free"
    private static let referer = "https://github.com/AtharvaBari/Gaze-MacOS"
    private static let titleHeader = "Gaze"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func generateHint(prompt: String, imageJPEG: Data, apiKey: String) async throws -> String {
        let dataURL = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": dataURL]]
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": content
            ]],
            "max_tokens": 60,
            "temperature": 0.7
        ]
        return try await send(body: body, apiKey: apiKey)
    }

    static func generateText(prompt: String, apiKey: String, maxTokens: Int = 80) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": prompt
            ]],
            "max_tokens": maxTokens,
            "temperature": 0.6
        ]
        return try await send(body: body, apiKey: apiKey)
    }

    private static func send(body: [String: Any], apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingKey }
        guard let url = URL(string: endpoint) else { throw AIError.badResponse(0) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(titleHeader, forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse(0) }

        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw AIError.unauthorized
        case 429:
            throw AIError.rateLimited
        default:
            throw AIError.badResponse(http.statusCode)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decoding
        }
        guard let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw AIError.empty
        }

        if let plain = message["content"] as? String, !plain.isEmpty {
            return plain.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let parts = message["content"] as? [[String: Any]] {
            let joined = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
            if !joined.isEmpty {
                return joined.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        throw AIError.empty
    }
}
