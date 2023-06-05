import Foundation
import PackagePlugin

struct Configuration {
    let targetName: String?
    let testFilePath: String?
    let simulatorDevice: String?
    let requiredOSVersion: String?
}

// MARK: - Initialization

extension Configuration {
    enum Keys: String {
        case target
        case test_file_path
        case simulator_device
        case required_os
    }

    private static let fileName = ".prefire.yml"

    static func from(rootPaths: [Path]) -> Configuration? {
        for path in rootPaths {
            if let configuration = Configuration.from(rootPath: path) {
                return configuration
            }
        }
        return nil
    }

    private static func from(rootPath: Path) -> Configuration? {
        let configPath = rootPath.appending(subpath: Configuration.fileName)
        Diagnostics.remark("Trying to find a '.prefire.yml' from the path: \(configPath.string)")

        guard FileManager.default.fileExists(atPath: configPath.string),
              let configDataString = URL(string: "file://\(configPath)").flatMap({ try? String(contentsOf: $0, encoding: .utf8) })
        else { return nil }

        Diagnostics.remark("🟢 Successfully found and will use the file '.prefire.yml' on the path: \(configPath.string)")

        return Configuration(
            targetName: getFrom(configDataString: configDataString, key: .target),
            testFilePath: getFrom(configDataString: configDataString, key: .test_file_path),
            simulatorDevice: getFrom(configDataString: configDataString, key: .simulator_device),
            requiredOSVersion: getFrom(configDataString: configDataString, key: .required_os)
        )
    }

    private static func getFrom(configDataString: String, key: Keys) -> String? {
        configDataString.matches(regex: "(test_configuration:|\\s+" + key.rawValue + ":)(.+)")
            .first?.components(separatedBy: ": ").last
    }
}

// MARK: - Extension regex

private extension String {
    func matches(regex: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.map { match in
            String(self[Range(match.range, in: self)!])
        }
    }
}
