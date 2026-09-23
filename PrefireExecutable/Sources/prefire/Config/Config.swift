import Foundation
import PrefireCore

struct Config {
    var tests = TestsConfig()
    var playbook = PlaybookConfig()
    /// Directory containing the loaded `.prefire` file. Used to resolve relative paths.
    var configDirectory: String?

    enum CodingKeys: String, CodingKey {
        case tests = "test_configuration"
        case playbook = "playbook_configuration"
    }
}

struct TestsConfig {
    var target: String?
    var testTargetPath: String?
    var sources: [String]?
    var testFilePath: String?
    var template: String?
    var device: String?
    var osVersion: String?
    var snapshotDevices: [String]?
    var previewDefaultEnabled: Bool?
    var imports: [String]?
    var testableImports: [String]?
    var useGroupedSnapshots: Bool?
    var splitSnapshotDirectories: Bool?
    var drawHierarchyInKeyWindowDefaultEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case target = "target"
        case testTargetPath = "test_target_path"
        case sources = "sources"
        case testFilePath = "test_file_path"
        case template = "template_file_path"
        case device = "simulator_device"
        case osVersion = "required_os"
        case snapshotDevices = "snapshot_devices"
        case previewDefaultEnabled = "preview_default_enabled"
        case imports = "imports"
        case testableImports = "testable_imports"
        case useGroupedSnapshots = "use_grouped_snapshots"
        case splitSnapshotDirectories = "split_snapshot_directories"
        case drawHierarchyInKeyWindowDefaultEnabled = "draw_hierarchy_in_key_window_default_enabled"
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
    static let packagePathKey = "PACKAGE_DIR"

    static func load(from configPath: String?, testTargetPath: String?, env: [String: String]) -> Config? {
        let possibleConfigPaths = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath, packagePath: env[packagePathKey])

        for path in possibleConfigPaths {
            let configUrl = URL(filePath: path)
            guard FileManager.default.fileExists(atPath: configUrl.path),
                  let configDataString = try? String(contentsOf: configUrl, encoding: .utf8) else { continue }

            Logger.info("🟢 The '.prefire' file is used on the path: \(configUrl.path)")

            var config = ConfigDecoder().decode(from: configDataString, env: env)
            config.configDirectory = configUrl.deletingLastPathComponent().path(percentEncoded: false)
            return config
        }

        Logger.verbose("🟡 The '.prefire' file was not found by paths:" + possibleConfigPaths.map({ "\n  - " + $0 }).joined())

        return nil
    }
}

extension Config {
    /// Resolves a template path from the config.
    ///
    /// Absolute paths are used as is. Relative paths are looked up relative to `targetPath`
    /// (legacy behavior), then relative to the `.prefire` file directory, then the current directory.
    /// The first existing file wins; if none exists, the first candidate is returned so the error shows a full path.
    func resolveTemplatePath(_ template: String, targetPath: String?) -> String {
        guard !template.hasPrefix("/") else { return template }

        let candidates = [targetPath, configDirectory, FileManager.default.currentDirectoryPath]
            .compactMap { $0 }
            .map { URL(filePath: $0).appending(path: template).standardizedFileURL.path(percentEncoded: false) }

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? candidates.first ?? template
    }
}
