import Foundation

enum AIError: Error, LocalizedError {
    case missingKey
    case unauthorized
    case rateLimited
    case badResponse(Int)
    case decoding
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:    return "Gemini API key not set"
        case .unauthorized:  return "Invalid Gemini API key"
        case .rateLimited:   return "Rate limited — try again later"
        case .badResponse(let code): return "Server error (\(code))"
        case .decoding:      return "Could not decode Gemini response"
        case .empty:         return "Gemini returned no content"
        }
    }
}

enum GeminiClient {
    private static let model = "gemini-1.5-flash-latest"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func generateHint(prompt: String, imageJPEG: Data, apiKey: String) async throws -> String {
        let parts: [[String: Any]] = [
            ["text": prompt],
            ["inline_data": [
                "mime_type": "image/jpeg",
                "data": imageJPEG.base64EncodedString()
            ]]
        ]
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.95,
                "maxOutputTokens": 60
            ]
        ]
        return try await send(body: body, apiKey: apiKey)
    }

    static func generateText(prompt: String, apiKey: String, maxTokens: Int = 80) async throws -> String {
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.6,
                "maxOutputTokens": maxTokens
            ]
        ]
        return try await send(body: body, apiKey: apiKey)
    }

    private static func send(body: [String: Any], apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingKey }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw AIError.badResponse(0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
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
        guard let candidates = object["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.compactMap({ $0["text"] as? String }).first else {
            throw AIError.empty
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
