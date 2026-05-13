import Foundation

enum PortalCapture: Equatable {
    case hex(String)
    case url(URL)

    var copyable: String {
        switch self {
        case .hex(let s): return s
        case .url(let u): return u.absoluteString
        }
    }

    var displayLabel: String {
        switch self {
        case .hex(let s): return s
        case .url(let u): return u.host ?? u.absoluteString
        }
    }
}

enum PortalParser {
    static func parse(_ raw: String) -> PortalCapture? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let hex = matchHex(trimmed) { return .hex(hex) }
        if let url = matchURL(trimmed) { return .url(url) }
        return nil
    }

    private static func matchHex(_ s: String) -> String? {
        let pattern = #"^#?([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
        guard s.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let body = s.hasPrefix("#") ? String(s.dropFirst()) : s
        return "#" + body.uppercased()
    }

    private static func matchURL(_ s: String) -> URL? {
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "ftp", "file", "mailto"].contains(scheme) else { return nil }
        if scheme == "mailto" { return url }
        guard url.host?.isEmpty == false else { return nil }
        return url
    }
}
