import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Equatable {
    case gemini
    case openrouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini:     return "Gemini 1.5 Flash"
        case .openrouter: return "OpenRouter"
        }
    }
}

enum AIRouter {
    static func generateText(prompt: String, settings: SettingsStore, maxTokens: Int = 80) async throws -> String {
        switch settings.aiProviderEnum {
        case .openrouter:
            return try await OpenRouterClient.generateText(
                prompt: prompt,
                apiKey: settings.openRouterAPIKey,
                maxTokens: maxTokens
            )
        case .gemini:
            return try await GeminiClient.generateText(
                prompt: prompt,
                apiKey: settings.geminiAPIKey,
                maxTokens: maxTokens
            )
        }
    }

    static func generateHint(prompt: String, imageJPEG: Data, settings: SettingsStore) async throws -> String {
        switch settings.aiProviderEnum {
        case .openrouter:
            return try await OpenRouterClient.generateHint(
                prompt: prompt,
                imageJPEG: imageJPEG,
                apiKey: settings.openRouterAPIKey
            )
        case .gemini:
            return try await GeminiClient.generateHint(
                prompt: prompt,
                imageJPEG: imageJPEG,
                apiKey: settings.geminiAPIKey
            )
        }
    }
}
