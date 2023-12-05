import Foundation

struct Config {
    var target: String?
    var testFilePath: String?
    var template: String?
    var device: String?
    var osVersion: String?
    var imports: [String]?
    var testableImports: [String]?
}

// MARK: - Initialization

extension Config {
    enum Keys: String {
        case target
        case test_file_path
        case template_file_path
        case simulator_device
        case required_os
        case imports
        case testable_imports
    }

    static func from(config: String?, verbose: Bool) -> Config? {
        let possibleConfigPaths = ConfigPathBuilder.possibleConfigPaths(for: config)

        for path in possibleConfigPaths {
            guard let configUrl = URL(string: "file://\(path)"),
                  FileManager.default.fileExists(atPath: configUrl.path),
                  let configDataString = try? String(contentsOf: configUrl, encoding: .utf8) else { continue }

            if verbose {
                print("🟢 Successfully found and will use the file '.prefire.yml' on the path: \(configUrl.path)")
            }

            if let configuration = Config.from(configDataString: configDataString, verbose: verbose) {
                return configuration
            }
        }
        return nil
    }

    static func from(configDataString: String, verbose _: Bool) -> Config? {
        var isTestConfig = false
        var isPlaybookConfig = false
        var configuration = Config()

        let lines = configDataString.components(separatedBy: .newlines)

        for index in 0..<lines.count {
            if lines[index].contains("test_configuration:") {
                isTestConfig = true
                continue
            } else if lines[index].contains("playbook_configuration:") {
                isPlaybookConfig = true
                continue
            }

            let components = lines[index].components(separatedBy: ":")

            if isTestConfig {
                if let target = getValue(from: components, key: .target) {
                    configuration.target = target
                    continue
                }
                if let testFilePath = getValue(from: components, key: .test_file_path) {
                    configuration.testFilePath = testFilePath
                    continue
                }
                if let template = getValue(from: components, key: .template_file_path) {
                    configuration.template = template
                    continue
                }
                if let device = getValue(from: components, key: .simulator_device) {
                    configuration.device = device
                    continue
                }
                if let osVersion = getValue(from: components, key: .required_os) {
                    configuration.osVersion = osVersion
                    continue
                }
            }

            if isPlaybookConfig {
                if let imports = getValues(from: components, lines: Array(lines[index..<lines.count]), key: .imports) {
                    configuration.imports = imports
                    continue
                }
                if let testableImports = getValues(from: components, lines: Array(lines[index..<lines.count]), key: .testable_imports) {
                    configuration.testableImports = testableImports
                    continue
                }
            }
        }

        return configuration
    }

    private static func getValues(from components: [String], lines: [String], key: Keys) -> [String]? {
        guard (components.first?.hasSuffix("- \(key.rawValue)") ?? false) == true else { return nil }

        var values = [String]()

        for line in lines[1..<lines.count] {
            guard !line.contains(":") else { return values }

            let value = line
                .trimmingCharacters(in: CharacterSet.whitespaces)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "- ", with: "")
            if !value.isEmpty {
                values.append(value)
            }
        }

        return values
    }

    private static func getValue(from components: [String], key: Keys) -> String? {
        guard components.first?.hasSuffix("- \(key.rawValue)") == true else { return nil }

        return components.last?
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .replacingOccurrences(of: "\"", with: "")
    }
}
