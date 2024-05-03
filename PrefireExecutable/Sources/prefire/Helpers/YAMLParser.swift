import Foundation

struct YAMLParser {
    /// Creating a YAML string from a dictionary
    /// - Parameter content: A dictionary with content for YAML
    /// - Returns: YAML content String
    func string(from content: [String: Any?]) -> String {
        var result = ""

        for item in content.sorted(by: { $0.key < $1.key }) {
            if let values = item.value as? [String] {
                result += "\(item.key):\n" + values.map({ "  - \($0)\n" }).reduce("", +)
            } else if let values = item.value as? [String: Any?] {
                result += "\(item.key):\n  " + string(from: values).replacingOccurrences(of: "\n", with: "\n  ")
                result.removeLast(2)
            } else if let value = item.value {
                result += "\(item.key): \(value)\n"
            }
        }

        return result
    }
}
