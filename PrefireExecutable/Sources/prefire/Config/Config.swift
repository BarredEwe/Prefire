import Foundation
import PrefireCore

struct Config {
    var tests = TestsConfig()
    var playbook = PlaybookConfig()
    var render = RenderConfig()

    enum CodingKeys: String, CodingKey {
        case tests = "test_configuration"
        case playbook = "playbook_configuration"
        case render = "render_configuration"
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
    var snapshotWaitForIdle: Bool?
    var snapshotWaitTimeout: Double?
    var fullPageSnapshots: Bool?
    /// How previews are snapshotted for VoiceOver, out of `voiceOverSnapshotStrategies`.
    /// `nil` keeps the default, `["image"]`; empty, from `none`, `[]` or no value, turns them off.
    var voiceOverSnapshots: [String]?

    static let voiceOverSnapshotStrategies = ["image", "text"]

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
        case snapshotWaitForIdle = "snapshot_wait_for_idle"
        case snapshotWaitTimeout = "snapshot_wait_timeout"
        case fullPageSnapshots = "full_page_snapshots"
        case voiceOverSnapshots = "voiceover_snapshots"
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

/// How `prefire render`, `prefire board` and `prefire mcp` build and run the snapshot tests.
struct RenderConfig {
    var scheme: String?
    var workspace: String?
    var project: String?
    var destination: String?
    var testTarget: String?
    var outputDir: String?
    var sources: [String]?
    var xcodebuildArgs: [String]?
    var directLaunch: Bool?
    var ownDerivedData: Bool?

    enum CodingKeys: String, CodingKey {
        case scheme = "scheme"
        case workspace = "workspace"
        case project = "project"
        case destination = "destination"
        case testTarget = "test_target"
        case outputDir = "output_dir"
        case sources = "sources"
        case xcodebuildArgs = "xcodebuild_args"
        case directLaunch = "direct_launch"
        case ownDerivedData = "own_derived_data"
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

            return ConfigDecoder().decode(from: configDataString, env: env)
        }

        Logger.verbose("🟡 The '.prefire' file was not found by paths:" + possibleConfigPaths.map({ "\n  - " + $0 }).joined())

        return nil
    }
}
