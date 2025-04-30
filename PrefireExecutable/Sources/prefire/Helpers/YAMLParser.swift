import Foundation

struct YAMLParser {
    /// Creating a YAML string from a dictionary
    /// - Parameter content: A dictionary with content for YAML
    /// - Returns: YAML content String
    func string(from content: [String: Any?]) -> String {
        var result = ""

        func indent(_ indentationLevel: Int) {
            result += String(repeating: " ", count: indentationLevel * 2)
        }

        func recurse(_ content: [String: Any?], _ indentationLevel: Int, indentFirst: Bool) {
            var isFirst = true
            for item in content.sorted(by: { $0.key < $1.key }) {
                if item.value == nil { continue }
                if !isFirst || indentFirst {
                    indent(indentationLevel)
                }
                isFirst = false
                if let values = item.value as? [String] {
                    result += "\(item.key):\n"
                    for value in values {
                        indent(indentationLevel + 1)
                        result += "- \(value)\n"
                    }
                } else if let values = item.value as? [String: Any?] {
                    result += "\(item.key):\n"
                    recurse(values, indentationLevel + 1, indentFirst: true)
                } else if let values = item.value as? [[String: Any?]] {
                    result += "\(item.key):\n"
                    for dict in values {
                        indent(indentationLevel + 1)
                        result += "- "
                        recurse(dict, indentationLevel + 2, indentFirst: false)
                    }
                } else if let value = item.value as? String {
                    result += "\(item.key): \(stringLiteral(value))\n"
                } else if let value = item.value {
                    result += "\(item.key): \(value)\n"
                }
            }
        }

        recurse(content, 0, indentFirst: true)

        return result
    }

    private func stringLiteral(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
