import Foundation
import PathKit
import SourceryFramework
import SourceryRuntime
import SourceryStencil

public enum PrefireGenerator {
    nonisolated(unsafe) static var startTime = Date()

    public static func generate(
        version: String,
        sources: [Path],
        output: Path,
        arguments: [String: NSObject],
        inlineTemplate: String,
        defaultEnabled: Bool,
        cacheDir: Path? = nil
    ) async throws {
        startTime = Date()

        var swiftFiles: Set<Path> = []
        try sources.forEach { path in
            if path.isDirectory {
                swiftFiles.formUnion(try path.recursiveChildren().filter { $0.extension == "swift" })
            } else if path.extension == "swift" {
                swiftFiles.insert(path)
            }
        }

        guard !swiftFiles.isEmpty else {
            Logger.info("No Swift sources found to process.")
            return
        }

        let fileContents: [(Path, String)] = try swiftFiles.map { ($0, try $0.read(.utf8)) }

        let manager = PrefireCacheManager(version: version, cacheBasePath: cacheDir)
        let (types, previews) = try await manager.loadOrGenerate(
            sources: fileContents.map { $0.0 },
            template: inlineTemplate,
            parseTypes: {
                Logger.info("🧩 Parsing Swift files...")
                let results = try fileContents.map { (path, content) in
                    let parser = try FileParserSyntax(
                        contents: content,
                        forceParse: [],
                        parseDocumentation: false,
                        path: path,
                        module: nil
                    )
                    return try parser.parse()
                }
                let types = results.flatMap { $0.types }
                return Types(types: types)
            },
            parsePreviews: {
                Logger.info("🔍 Extracting #Preview bodies...")
                var result: [String: String] = [:]
                for (path, content) in fileContents {
                    guard content.contains("#Preview") else { continue }
                    if let bodies = PreviewLoader.previewBodies(from: content, defaultEnabled: defaultEnabled) {
                        for (i, body) in bodies.enumerated() {
                            let key = "\(path.lastComponentWithoutExtension)_\(i)"
                            result[key] = body
                        }
                    }
                }
                return result
            }
        )

        let previewModels = previews
            .sorted { $0.key > $1.key }
            .compactMap { RawPreviewModel(from: $0.value, filename: $0.key) }
            .map { $0.makeStencilDict() }

        var arguments = arguments
        arguments["previewsMacrosDict"] = previewModels as NSArray

        let parserResult = FileParserResult(path: nil, module: nil, types: types.types, functions: [], typealiases: [])

        try renderAndWrite(parserResult: parserResult, inlineTemplate: inlineTemplate, output: output, arguments: arguments)

        Logger.info("✅ Generation completed in \(startTime.distance(to: Date()).formatted())")
    }

    private static func renderAndWrite(
        parserResult: FileParserResult,
        inlineTemplate: String,
        output: Path,
        arguments: [String: NSObject]
    ) throws {
        Logger.info("🖋 Rendering template...")
        let tpl = StencilTemplate(templateString: inlineTemplate)

        let context = TemplateContext(
            parserResult: parserResult,
            types: Types(types: parserResult.types),
            functions: parserResult.functions,
            arguments: arguments
        )

        let rendered = try tpl.render(context.stencilContext)

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
