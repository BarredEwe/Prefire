import Foundation

private enum Constants {
    static let separtor = ":"
}

struct Config {
    struct TestsConfig {
        var target: String?
        var testFilePath: String?
        var template: String?
        var device: String?
        var osVersion: String?
        var snapshotDevices: [String]?
        var previewDefaultEnabled: Bool?
        var imports: [String]?
        var testableImports: [String]?
    }

    struct PlaybookConfig {
        var template: String?
        var previewDefaultEnabled: Bool?
        var imports: [String]?
        var testableImports: [String]?
    }

    var tests = TestsConfig()
    var playbook = PlaybookConfig()

    init?(from configDataString: String) {
        var isTestConfig = false
        var isPlaybookConfig = false

        let lines = configDataString.components(separatedBy: .newlines)

        for index in 0..<lines.count {
            if lines[index].contains(Keys.test_configuration.rawValue + Constants.separtor) {
                isPlaybookConfig = false
                isTestConfig = true
                continue
            } else if lines[index].contains(Keys.playbook_configuration.rawValue + Constants.separtor) {
                isTestConfig = false
                isPlaybookConfig = true
                continue
            }

            let components = lines[index].components(separatedBy: Constants.separtor)

            if isTestConfig {
                if let target = Config.getValue(from: components, key: .target) {
                    tests.target = target
                    continue
                }
                if let testFilePath = Config.getValue(from: components, key: .test_file_path) {
                    tests.testFilePath = testFilePath
                    continue
                }
                if let template = Config.getValue(from: components, key: .template_file_path) {
                    tests.template = template
                    continue
                }
                if let device = Config.getValue(from: components, key: .simulator_device) {
                    tests.device = device
                    continue
                }
                if let osVersion = Config.getValue(from: components, key: .required_os) {
                    tests.osVersion = osVersion
                    continue
                }
                if let snapshotDevices = Config.getValues(from: components, lines: Array(lines[index..<lines.count]), key: .snapshot_devices) {
                    tests.snapshotDevices = snapshotDevices
                    continue
                }
                if let previewDefaultEnabled = Config.getValue(from: components, key: .preview_default_enabled) {
                    tests.previewDefaultEnabled = previewDefaultEnabled == "true"
                    continue
                }
                if let imports = Config.getValues(from: components, lines: Array(lines[index..<lines.count]), key: .imports) {
                    tests.imports = imports
                    continue
                }
                if let testableImports = Config.getValues(from: components, lines: Array(lines[index..<lines.count]), key: .testable_imports) {
                    tests.testableImports = testableImports
                    continue
                }
            }

            if isPlaybookConfig {
                if let template = Config.getValue(from: components, key: .template_file_path) {
                    playbook.template = template
                    continue
                }
                if let previewDefaultEnabled = Config.getValue(from: components, key: .preview_default_enabled) {
                    playbook.previewDefaultEnabled = previewDefaultEnabled == "true"
                    continue
                }
                if let imports = Config.getValues(from: components, lines: Array(lines[index..<lines.count]), key: .imports) {
                    playbook.imports = imports
                    continue
                }
                if let testableImports = Config.getValues(from: components, lines: Array(lines[index..<lines.count]), key: .testable_imports) {
                    playbook.testableImports = testableImports
                    continue
                }
            }
        }
    }
}

// MARK: - Initialization

extension Config {
    enum Keys: String {
        case target
        case test_file_path
        case template_file_path
        case simulator_device
        case required_os
        case snapshot_devices
        case preview_default_enabled
        case imports
        case testable_imports
        case test_configuration
        case playbook_configuration
    }
    
    static func load(from configPath: String?, testTargetPath: String?) -> Config? {
        let possibleConfigPaths = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        for path in possibleConfigPaths {
            let configUrl = URL(filePath: path)
            guard FileManager.default.fileExists(atPath: configUrl.path),
                  let configDataString = try? String(contentsOf: configUrl, encoding: .utf8) else { continue }

            Logger.print("🟢 The '.prefire' file is used on the path: \(configUrl.path)")

            if let configuration = Config(from: configDataString) {
                return configuration
            }
        }

        Logger.print("🟡 The '.prefire' file was not found by paths:" + possibleConfigPaths.map({ "\n  - " + $0 }).reduce("", +))

        return nil
    }

    // MARK: - Private

    private static func getValues(from components: [String], lines: [String], key: Keys) -> [String]? {
        guard (components.first?.hasSuffix("- \(key.rawValue)") ?? false) == true, components.last?.isEmpty == true else { return nil }

        var values = [String]()

        for line in lines[1..<lines.count] {
            guard !line.contains(Constants.separtor) else { return values }

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
