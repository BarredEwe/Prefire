import Foundation
import PrefireCore

private enum Constants {
    static let separtor = ":"
}

final class ConfigDecoder {
    func decode(from configDataString: String, env: [String: String]) -> Config {
        var config: Config = Config()

        var currentSection: Config.CodingKeys?

        let lines = configDataString.components(separatedBy: .newlines)

        for index in 0..<lines.count {
            if lines[index].contains(Config.CodingKeys.tests.rawValue + Constants.separtor) {
                currentSection = .tests
            } else if lines[index].contains(Config.CodingKeys.playbook.rawValue + Constants.separtor) {
                currentSection = .playbook
            } else if let currentSection {
                let components = lines[index].components(separatedBy: Constants.separtor)
                if components.count > 1 {
                    switch currentSection {
                    case .tests:
                        handleTestConfig(config: &config, components: components, lines: lines[index..<lines.count], env: env)
                    case .playbook:
                        handlePlaybookConfig(config: &config, components: components, lines: lines[index..<lines.count], env: env)
                    }
                }
            }
        }

        return config
    }

    // MARK: - Private methods

    private func handleTestConfig(config: inout Config, components: [String], lines: ArraySlice<String>, env: [String: String]) {
        var components = components
        let keyString = components.removeFirst().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")

        guard !keyString.isEmpty else { return }

        guard let key = TestsConfig.CodingKeys(rawValue: keyString) else {
            Logger.warning("⚠️ Unknown test config key: '\(keyString)'")
            return
        }

        switch key {
        case .target:
            config.tests.target = getValue(from: components.last, env: env)
        case .sources:
            config.tests.sources = getValues(from: components, lines: lines, env: env)
        case .testFilePath:
            config.tests.testFilePath = getValue(from: components.last, env: env)
        case .template:
            config.tests.template = getValue(from: components.last, env: env)
        case .device:
            config.tests.device = getValue(from: components.last, env: env)
        case .osVersion:
            config.tests.osVersion = getValue(from: components.last, env: env)
        case .snapshotDevices:
            config.tests.snapshotDevices = getValues(from: components, lines: lines, env: env)
        case .previewDefaultEnabled:
            config.tests.previewDefaultEnabled = getValue(from: components.last, env: env) == "true"
        case .imports:
            config.tests.imports = getValues(from: components, lines: lines, env: env)
        case .testableImports:
            config.tests.testableImports = getValues(from: components, lines: lines, env: env)
        case .testTargetPath:
            config.tests.testTargetPath = getValue(from: components.last, env: env)
        case .useGroupedSnapshots:
            config.tests.useGroupedSnapshots = getValue(from: components.last, env: env) == "true"
        }
    }

    private func handlePlaybookConfig(config: inout Config, components: [String], lines: ArraySlice<String>, env: [String: String]) {
        var components = components
        let keyString = components.removeFirst().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")

        guard !keyString.isEmpty else { return }

        guard let key = PlaybookConfig.CodingKeys(rawValue: keyString) else {
            Logger.warning("⚠️ Unknown playbook config key: '\(keyString)'")
            return
        }

        switch key {
            case .targetPath:
                config.playbook.targetPath = getValue(from: components.last, env: env)
            case .template:
                config.playbook.template = getValue(from: components.last, env: env)
            case .previewDefaultEnabled:
                config.playbook.previewDefaultEnabled = getValue(from: components.last, env: env) == "true"
            case .imports:
                config.playbook.imports = getValues(from: components, lines: lines, env: env)
            case .testableImports:
                config.playbook.testableImports = getValues(from: components, lines: lines, env: env)
        }
    }

    private func getValues(from components: [String], lines: ArraySlice<String>, env: [String: String]) -> [String]? {
        guard components.last?.isEmpty == true else { return nil }

        var values = [String]()

        for line in lines[lines.startIndex + 1..<lines.endIndex] {
            guard !line.contains(Constants.separtor) else { return values }

            var value = line
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "- ", with: "")

            guard !value.isEmpty else { continue }

            // Check and replace if the value contains a key formatted as "${key}"
            if let key = value.findKey(), let envValue = env[key] {
                value = value.replacingOccurrences(of: "${\(key)}", with: envValue)
            }

            values.append(value)
        }

        return values
    }

    private func getValue(from component: String?, env: [String: String]) -> String? {
        var value = component?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")

        // Check and replace if the value contains a key formatted as "${key}"
        if let key = value?.findKey(), let envValue = env[key] {
            value = value?.replacingOccurrences(of: "${\(key)}", with: envValue)
        }

        return value
    }
}

private extension String {
    /// Extract the key enclosed within "${}" from a string
    /// - Returns: Key
    func findKey() -> String? {
        guard contains("${") else { return nil }

        return components(separatedBy: "${").last?.components(separatedBy: "}").first
    }
}
