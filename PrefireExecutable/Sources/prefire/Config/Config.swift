import Foundation

struct Config {
    var tests = TestsConfig()
    var playbook = PlaybookConfig()

    enum CodingKeys: String, CodingKey {
        case tests = "test_configuration"
        case playbook = "playbook_configuration"
    }
}

struct TestsConfig {
    var target: String?
    var sources: [String]?
    var testFilePath: String?
    var template: String?
    var device: String?
    var osVersion: String?
    var snapshotDevices: [String]?
    var previewDefaultEnabled: Bool?
    var imports: [String]?
    var testableImports: [String]?

    enum CodingKeys: String, CodingKey {
        case target = "target"
        case sources = "sources"
        case testFilePath = "test_file_path"
        case template = "template_file_path"
        case device = "simulator_device"
        case osVersion = "required_os"
        case snapshotDevices = "snapshot_devices"
        case previewDefaultEnabled = "preview_default_enabled"
        case imports = "imports"
        case testableImports = "testable_imports"
    }
}

struct PlaybookConfig {
    var targetPath: String?
    var template: String?
    var previewDefaultEnabled: Bool?
    var imports: [String]?
    var testableImports: [String]?

    enum CodingKeys: String, CodingKey {
        case targetPath = "target"
        case template = "template_file_path"
        case previewDefaultEnabled = "preview_default_enabled"
        case imports = "imports"
        case testableImports = "testable_imports"
    }
}

extension Config {
    static func load(from configPath: String?, testTargetPath: String?, env: [String : String]) -> Config? {
        let possibleConfigPaths = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        for path in possibleConfigPaths {
            let configUrl = URL(filePath: path)
            guard FileManager.default.fileExists(atPath: configUrl.path),
                  let configDataString = try? String(contentsOf: configUrl, encoding: .utf8) else { continue }

            Logger.print("🟢 The '.prefire' file is used on the path: \(configUrl.path)")

            return ConfigDecoder().decode(from: configDataString, env: env)
        }

        Logger.print("🟡 The '.prefire' file was not found by paths:" + possibleConfigPaths.map({ "\n  - " + $0 }).joined())

        return nil
    }
}
