import Foundation
import PathKit

/// A preview Prefire generates a snapshot test for, and where it is declared.
public struct PreviewEntry: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// A `#Preview` macro.
        case macro
        /// A `PreviewProvider` marked with `PrefireProvider`, whose previews are named only at runtime.
        case provider
    }

    /// Name of the snapshot: the name of the `#Preview`, or of the `PreviewProvider` type.
    public var name: String
    public var kind: Kind
    public var file: String
    public var line: Int

    /// Class of the generated test, when the snapshots are grouped as `use_grouped_snapshots` sets.
    public var testClass: String
    public var testMethod: String

    /// Whether the preview is a screen, rendered on a device, rather than a component.
    public var isScreen: Bool

    public init(name: String, kind: Kind, file: String, line: Int, testClass: String, testMethod: String, isScreen: Bool) {
        self.name = name
        self.kind = kind
        self.file = file
        self.line = line
        self.testClass = testClass
        self.testMethod = testMethod
        self.isScreen = isScreen
    }

    /// Whether the snapshot named `snapshotName` comes from this preview.
    ///
    /// Snapshots of a preview with `arguments:`, or rendered on several devices, add `-` and a suffix.
    func matches(snapshotName: String) -> Bool {
        snapshotName == name || snapshotName.hasPrefix(name + "-")
    }
}

/// Finds the previews Prefire generates snapshot tests for, the way `prefire tests` does.
public enum PreviewCatalog {
    public static func entries(sources: [Path], defaultEnabled: Bool, useGroupedSnapshots: Bool) throws -> [PreviewEntry] {
        var files: Set<Path> = []
        for path in sources {
            if path.isDirectory {
                files.formUnion(try path.recursiveChildren().filter { $0.extension == "swift" })
            } else if path.extension == "swift" {
                files.insert(path)
            }
        }

        let contents = try files.sorted { $0.string < $1.string }.map { file in (file: file, content: try file.read(.utf8) as String) }

        // Providers are found as the generator finds them: through the types of every file, so one
        // conforming through `protocol MyProvider: PrefireProvider` counts too.
        let graph = TypeGraph(types: TypeScanner.merge(contents.map { TypeScanner.scan(contents: $0.content) }))
        let providers = Set(graph.types.filter { type in
            type.kind != .protocol && (graph.based(of: type).contains("PrefireProvider") || type.annotations["PrefireProvider"] != nil)
        }.map(\.name))

        var providersFound: Set<String> = []
        var catalog = contents.flatMap { file in
            entries(in: file.content, file: file.file, defaultEnabled: defaultEnabled, useGroupedSnapshots: useGroupedSnapshots, providers: providers)
                // A provider extended in another file is tested once.
                .filter { $0.kind == .macro || providersFound.insert($0.name).inserted }
        }

        // Ungrouped, each generated class tests every provider and no `PreviewTests` class exists,
        // so the test of a provider is taken from the first class.
        if !useGroupedSnapshots, let testClass = catalog.first(where: { $0.kind == .macro })?.testClass {
            for index in catalog.indices where catalog[index].kind == .provider {
                catalog[index].testClass = testClass
            }
        }
        return catalog
    }

    /// - Parameter providers: Names of the `PrefireProvider` types of the sources. When `nil`, a type
    ///   is one when it conforms to `PrefireProvider` itself.
    static func entries(
        in content: String,
        file: Path,
        defaultEnabled: Bool,
        useGroupedSnapshots: Bool,
        providers: Set<String>? = nil
    ) -> [PreviewEntry] {
        let fileName = file.lastComponentWithoutExtension
        let macroClass = useGroupedSnapshots ? "PreviewTests" : "\(fileName)Tests"
        var entries: [PreviewEntry] = []

        if content.contains("#Preview") {
            let previews = PreviewLoader.locatedPreviewModels(from: content, filename: fileName, defaultEnabled: defaultEnabled) ?? []
            entries += previews.map { preview in
                PreviewEntry(
                    name: preview.model.displayName,
                    kind: .macro,
                    file: file.string,
                    line: preview.line,
                    testClass: macroClass,
                    testMethod: "test_\(preview.model.componentTestName)_Preview",
                    isScreen: preview.model.isScreen
                )
            }
        }

        if providers.map({ !$0.isEmpty }) ?? content.contains("PrefireProvider") {
            let lines = content.components(separatedBy: .newlines)
            entries += TypeScanner.scan(contents: content)
                .filter { $0.kind != .protocol && (providers?.contains($0.name) ?? $0.isPrefireProvider) }
                .map { type in
                    PreviewEntry(
                        name: type.name,
                        kind: .provider,
                        file: file.string,
                        line: declarationLine(of: type.localName, in: lines),
                        // `entries(sources:)` picks one of the generated classes when ungrouped.
                        testClass: "PreviewTests",
                        testMethod: providerTestMethod(for: type.name),
                        isScreen: false
                    )
                }
        }

        return entries
    }

    /// Name the default template gives the test of a `PreviewProvider`.
    static func providerTestMethod(for typeName: String) -> String {
        let lowered = typeName.prefix(1).lowercased() + typeName.dropFirst()
        return "test_" + lowered.replacingOccurrences(of: "_Previews", with: "").replacingOccurrences(of: ".", with: "_")
    }

    private static func declarationLine(of name: String, in lines: [String]) -> Int {
        let keywords = ["struct", "class", "enum", "actor", "extension"]
        let index = lines.firstIndex { line in
            let words = line.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
            return zip(words, words.dropFirst()).contains { keywords.contains(String($0)) && $1 == name }
        }
        return (index ?? 0) + 1
    }
}

private extension ParsedType {
    var isPrefireProvider: Bool {
        inheritedNames.contains("PrefireProvider") || annotations["PrefireProvider"] != nil
    }
}

private extension Path {
    var lastComponentWithoutExtension: String {
        lastComponent.components(separatedBy: ".").dropLast().joined(separator: ".")
    }
}
