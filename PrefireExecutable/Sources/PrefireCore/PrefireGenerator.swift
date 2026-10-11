import Foundation
import PathKit

/// A `#Preview` the generator turned into a test, described in terms callers need to
/// predict the snapshot files it records.
public struct GeneratedPreview: Equatable, Sendable {
    /// Swift file the preview lives in, without extension.
    public let sourceFileName: String
    /// `#Preview` display name, used verbatim as the snapshot name.
    public let displayName: String
    /// `#Preview(arguments:)` expands into one snapshot per argument.
    public let isParameterized: Bool

    public init(sourceFileName: String, displayName: String, isParameterized: Bool) {
        self.sourceFileName = sourceFileName
        self.displayName = displayName
        self.isParameterized = isParameterized
    }
}

/// What a generation run produced, beyond the files it wrote.
public struct GenerationResult: Equatable, Sendable {
    public let previews: [GeneratedPreview]
    /// `PrefireProvider` conformances found in the sources. Their snapshots are named from
    /// `previewDisplayName` at runtime, so they cannot be listed up front.
    public let hasPreviewProviders: Bool
    /// Swift files the run actually looked at. Zero means the sources were empty or
    /// misconfigured — no preview was seen, and nothing can be concluded from that.
    public let parsedSourceCount: Int

    public init(previews: [GeneratedPreview], hasPreviewProviders: Bool, parsedSourceCount: Int) {
        self.previews = previews
        self.hasPreviewProviders = hasPreviewProviders
        self.parsedSourceCount = parsedSourceCount
    }
}

public enum PrefireGenerator {
    private enum Constants {
        static let prefireProvider = "PrefireProvider"
    }

    nonisolated(unsafe) static var startTime = Date()

    @discardableResult
    public static func generate(
        version: String,
        sources: [Path],
        output: Path,
        arguments: [String: NSObject],
        inlineTemplate: String,
        defaultEnabled: Bool,
        cacheDir: Path? = nil,
        useGroupedSnapshots: Bool
    ) async throws -> GenerationResult {
        startTime = Date()

        var discovered: Set<Path> = []
        try sources.forEach { path in
            if path.isDirectory {
                discovered.formUnion(try path.recursiveChildren().filter { $0.extension == "swift" })
            } else if path.extension == "swift" {
                discovered.insert(path)
            }
        }

        guard !discovered.isEmpty else {
            Logger.info("No Swift sources found to process.")
            return GenerationResult(previews: [], hasPreviewProviders: false, parsedSourceCount: 0)
        }

        // Sorted so the order of the generated declarations does not depend on set iteration order.
        let swiftFiles = discovered.sorted { $0.string < $1.string }
        let fileContents: [(Path, String)] = try swiftFiles.map { ($0, try $0.read(.utf8)) }

        // If use grouped is false, we geneate one file per tests
        // and use the template as output replacing the "{PREVIEW_FILE_NAME}" with the name of the file

        let manager = PrefireCacheManager(version: version, cacheBasePath: cacheDir)
        let (types, previews) = try await manager.loadOrGenerate(
            sources: fileContents.map { $0.0 },
            template: inlineTemplate,
            parseTypes: {
                Logger.info("🧩 Parsing Swift files...")
                return TypeScanner.merge(fileContents.map { TypeScanner.scan(contents: $0.1) })
            },
            parsePreviews: {
                Logger.info("🔍 Extracting #Preview bodies...")
                var result: [String: RawPreviewModel] = [:]
                for (path, content) in fileContents {
                    guard content.contains("#Preview") else { continue }
                    if let models = PreviewLoader.previewModels(
                        from: content,
                        filename: path.lastComponentWithoutExtension,
                        defaultEnabled: defaultEnabled
                    ) {
                        result.merge(models) { current, _ in current }
                    }
                }
                return result
            }
        )

        let sortedPreviews = previews.sorted { $0.key > $1.key }

        let previewModels = sortedPreviews
            .compactMap { entry -> [String: Any?]? in
                var dict = entry.value.makeStencilDict()
                // Add the source filename for ungrouped generation
                dict["sourceFileName"] = extractFileNameFromKey(entry.key)
                return dict
            }

        let context = StencilContext(graph: TypeGraph(types: types))

        if useGroupedSnapshots {
            // Generate one file with all previews
            var arguments = arguments
            arguments["previewsMacrosDict"] = previewModels as NSArray
            
            // For grouped snapshots, replace {PREVIEW_FILE_NAME} with "Preview" to maintain current class name
            let customizedTemplate = inlineTemplate.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: "Preview")
            
            try renderAndWrite(context: context, inlineTemplate: customizedTemplate, output: output, arguments: arguments)
        } else {
            // Generate one file per source file containing previews
            try generateUngroupedFiles(
                previewModels: previewModels,
                context: context,
                inlineTemplate: inlineTemplate,
                output: output,
                arguments: arguments
            )
        }

        Logger.info("✅ Generation completed in \(startTime.distance(to: Date()).formatted())")

        return GenerationResult(
            previews: sortedPreviews.map { entry in
                GeneratedPreview(
                    sourceFileName: extractFileNameFromKey(entry.key),
                    displayName: entry.value.displayName,
                    isParameterized: entry.value.hasArguments
                )
            },
            hasPreviewProviders: types.types.contains(where: isPreviewProvider),
            parsedSourceCount: swiftFiles.count
        )
    }

    /// Mirrors the template's `type.implements.PrefireProvider or type.based.PrefireProvider
    /// or type|annotated:"PrefireProvider"` filter.
    private static func isPreviewProvider(_ type: Type) -> Bool {
        type.implements[Constants.prefireProvider] != nil
            || type.based[Constants.prefireProvider] != nil
            || type.annotations[Constants.prefireProvider] != nil
    }

    private static func generateUngroupedFiles(
        previewModels: [[String: Any?]],
        context: StencilContext,
        inlineTemplate: String,
        output: Path,
        arguments: [String: NSObject]
    ) throws {
        // Group preview models by their source file name
        let groupedByFile = Dictionary(grouping: previewModels) { previewModel -> String in
            return previewModel["sourceFileName"] as? String ?? "Unknown"
        }
        
        Logger.info("📝 Generating \(groupedByFile.count) separate test files...")
        
        for (fileName, models) in groupedByFile {
            guard fileName != "Unknown" else { continue }
            
            // Replace the placeholder in the output path
            let outputPath = replacePreviewFileName(in: output, with: fileName)
            
            var fileArguments = arguments
            fileArguments["previewsMacrosDict"] = models as NSArray

            // Resolve the placeholder in any string-valued arguments so values like the
            // `file` path (used by SnapshotTesting to derive the per-class `__Snapshots__`
            // folder) point at the per-source generated file rather than a literal placeholder.
            for (key, value) in fileArguments {
                guard let stringValue = value as? NSString,
                      stringValue.contains("{PREVIEW_FILE_NAME}") else { continue }
                let resolved = (stringValue as String).replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
                fileArguments[key] = resolved as NSString
            }

            // Replace the placeholder in the template as well
            let customizedTemplate = inlineTemplate.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
            
            Logger.info("🖋 Rendering template for \(fileName)...")
            try renderAndWrite(
                context: context,
                inlineTemplate: customizedTemplate,
                output: outputPath,
                arguments: fileArguments
            )
        }
    }
    
    private static func extractFileNameFromKey(_ key: String) -> String {
        // Key format is "FileName_index", extract just the file name part
        let components = key.components(separatedBy: "_")
        guard !components.isEmpty else { return key }
        
        // If the last component is a number, it's likely an index
        if components.count > 1 && Int(components.last!) != nil {
            return components.dropLast().joined(separator: "_")
        }
        
        return key
    }
    
    private static func replacePreviewFileName(in path: Path, with fileName: String) -> Path {
        let pathString = path.string
        let updatedPath = pathString.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
        return Path(updatedPath)
    }

    private static func renderAndWrite(
        context: StencilContext,
        inlineTemplate: String,
        output: Path,
        arguments: [String: NSObject]
    ) throws {
        Logger.info("🖋 Rendering template...")
        let rendered = try TemplateRenderer.render(
            template: inlineTemplate,
            context: context.dictionary(arguments: arguments)
        )

        Logger.info("💾 Writing to file: \(output)")
        try output.parent().mkpath()
        try output.write(rendered)
    }
}

private extension Path {
    var lastComponentWithoutExtension: String {
        self.lastComponent.components(separatedBy: ".").dropLast().joined(separator: ".")
    }
}
