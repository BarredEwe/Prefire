import Foundation

enum TestTargetConfig {
    /// Reads the configured target from the supplied directories in search order.
    static func loadTargetName(in possibleConfigPaths: [String]) -> String? {
        for configPath in possibleConfigPaths {
            let configUrl = URL(filePath: configPath).appending(path: ".prefire.yml")
            guard FileManager.default.fileExists(atPath: configUrl.path(percentEncoded: false)) else { continue }

            let configDataString = try? String(contentsOf: configUrl, encoding: .utf8).components(separatedBy: .newlines)

            if let targetName = configDataString?.first(where: { $0.contains("target:") })?.components(separatedBy: ":").last {
                return targetName
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
            }
        }

        return nil
    }
}
