import Foundation
import SwiftSyntax

/// Reads `// prefire:` and `// sourcery:` annotation comments preceding a declaration.
enum AnnotationParser {
    private static let prefixes = ["prefire:", "sourcery:"]

    static func parse(_ trivia: Trivia) -> [String: String] {
        var annotations: [String: String] = [:]

        for piece in trivia {
            let text: String
            switch piece {
            case let .lineComment(comment), let .docLineComment(comment):
                text = comment
            case let .blockComment(comment), let .docBlockComment(comment):
                text = comment
            default:
                continue
            }

            guard let body = annotationBody(in: text) else { continue }
            for entry in entries(in: body) {
                let (key, value) = keyValue(from: entry)
                guard !key.isEmpty else { continue }
                annotations[key] = value
            }
        }

        return annotations
    }

    /// Strips the comment delimiters and the `sourcery:`/`prefire:` marker.
    ///
    /// Only the delimiters around the comment are removed, so a value such as `"https://..."` keeps
    /// its own slashes.
    private static func annotationBody(in comment: String) -> String? {
        var text = Substring(comment)
        for opening in ["///", "//", "/**", "/*"] where text.hasPrefix(opening) {
            text = text.dropFirst(opening.count)
            break
        }
        if text.hasSuffix("*/") { text = text.dropLast(2) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for prefix in prefixes where trimmed.lowercased().hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count))
        }
        return nil
    }

    /// Splits `a, b = "x, y"` on the commas outside quotes.
    private static func entries(in body: String) -> [String] {
        var entries: [String] = []
        var current = ""
        var isQuoted = false

        for character in body {
            if character == "\"" { isQuoted.toggle() }
            if character == ",", !isQuoted {
                entries.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        entries.append(current)
        return entries
    }

    private static func keyValue(from entry: String) -> (key: String, value: String) {
        guard let equalsIndex = entry.firstIndex(of: "=") else {
            return (entry.trimmingCharacters(in: .whitespaces), "true")
        }

        let key = entry[entry.startIndex ..< equalsIndex].trimmingCharacters(in: .whitespaces)
        var value = entry[entry.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        return (key, value)
    }
}
