@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct Render: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Render previews to PNG by running the generated snapshot tests",
            discussion: """
            Builds the scheme with `xcodebuild test` and has the snapshot tests write each preview as \
            `<name>.png` with a `<name>.json` record, instead of comparing it with its reference. \
            `manifest.json` lists the previews of the run.
            """
        )

        @Argument(help: "Names of the previews to render. Renders all when none are given.")
        var previews: [String] = []

        @Option(name: .customLong("device"), help: "Device to render screens on, like 'iPhone 16 Pro'. Can be repeated.")
        var devices: [String] = []
        @Option(help: "Color scheme: \(RenderRequest.colorSchemes.joined(separator: ", ")).")
        var colorScheme: String?
        @Option(help: "Dynamic Type size: \(RenderRequest.dynamicTypeSizes.joined(separator: ", ")).")
        var dynamicType: String?

        @Flag(help: "List the previews as JSON instead of rendering.")
        var list = false
        @Flag(help: "Print the manifest as JSON.")
        var json = false

        @OptionGroup var setup: RenderSetupOptions

        func run() throws {
            Logger.level = setup.verbose ? .verbose : .warnings
            Logger.output = .standardError
            let config = setup.loadConfig()

            if list {
                let configuration = try setup.renderConfiguration(config: config, requiresScheme: false)
                print(try RenderOutput.json(RenderService(configuration: configuration).catalog()))
                return
            }

            let service = RenderService(configuration: try setup.renderConfiguration(config: config))
            let result = try service.render(
                RenderRequest(previews: previews, devices: devices, colorScheme: colorScheme, dynamicType: dynamicType)
            )

            if json {
                print(String(decoding: try result.manifest.encoded(), as: UTF8.self))
            } else {
                print(RenderOutput.summary(of: result))
            }
            if result.status != 0 {
                throw ExitCode(result.status)
            }
        }
    }
}

enum RenderOutput {
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// A line for each rendered preview, then where the manifest and the log are.
    static func summary(of result: RenderResult) -> String {
        var lines = result.manifest.previews.map { preview in
            let record = preview.record
            let name = record.name + (record.device.map { " (\($0))" } ?? "")
            if let image = result.imageURL(of: preview) {
                return "✅ \(name): \(image.path)"
            }
            return "❌ \(name): \(record.error ?? "not rendered")"
        }
        lines += result.warnings.map { "⚠️ " + $0 }
        if result.manifest.previews.isEmpty, result.warnings.isEmpty {
            lines.append("No preview matched. Run `prefire render --list` for the names.")
        }
        lines.append("Manifest: \(result.directory.appendingPathComponent(RenderManifest.fileName).path)")
        if result.status != 0 {
            lines.append("xcodebuild exited with \(result.status). Its output: \(result.logFile.path)")
        }
        return lines.joined(separator: "\n")
    }
}
