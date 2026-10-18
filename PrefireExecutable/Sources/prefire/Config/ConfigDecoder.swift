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
        case .splitSnapshotDirectories:
            config.tests.splitSnapshotDirectories = getValue(from: components.last, env: env) == "true"
        case .drawHierarchyInKeyWindowDefaultEnabled:
            config.tests.drawHierarchyInKeyWindowDefaultEnabled = getValue(from: components.last, env: env) == "true"
        case .fullPageSnapshots:
            config.tests.fullPageSnapshots = getValue(from: components.last, env: env) == "true"
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
        guard let lastComponent = components.last?.trimmingCharacters(in: .whitespaces),
              lastComponent.isEmpty == true else { return nil }

        var values = [String]()

        for line in lines[lines.startIndex + 1..<lines.endIndex] {
            guard !line.contains(Constants.separtor) else { return values }

            let value = line
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "- ", with: "")

            guard !value.isEmpty else { continue }

            values.append(value.replacingEnvKeys(env: env))
        }

        return values
    }

    private func getValue(from component: String?, env: [String: String]) -> String? {
        component?
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\"", with: "")
            .replacingEnvKeys(env: env)
    }
}

private extension String {
    /// Replace every key formatted as "${key}" with its value from the environment.
    /// Unknown keys and the target placeholders resolved later by `ConfigPathResolver` are kept as is.
    func replacingEnvKeys(env: [String: String]) -> String {
        var result = self
        for key in findKeys() where !ConfigPathResolver.placeholderKeys.contains(key) {
            guard let envValue = env[key] else { continue }
            result = result.replacingOccurrences(of: "${\(key)}", with: envValue)
        }
        return result
    }

    /// Extract all keys enclosed within "${}" from a string
    /// - Returns: Keys in order of appearance
    func findKeys() -> [String] {
        components(separatedBy: "${")
            .dropFirst()
            .compactMap { part in part.range(of: "}").map { String(part[..<$0.lowerBound]) } }
            .filter { !$0.isEmpty }
    }
}
