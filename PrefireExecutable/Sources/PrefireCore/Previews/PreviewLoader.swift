import Foundation
import SwiftParser
import SwiftSyntax

/// Simplify and improve the process of locating and parsing generated preview code for Swift projects.
enum PreviewLoader {
    enum Constants {
        static let previewMacro = "Preview"
        static let defaultTrait = ".device"
        static let prefireDisableMarker = ".prefireIgnored()"
        static let prefireEnabledMarker = ".prefireEnabled()"
    }

    /// Extract the preview body using the passed content
    ///
    /// - Parameters:
    ///   - content: File content
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: An array representing the results of the macro preview, each starting with `#Preview`
    ///            and ending with the closing `}` of the preview closure followed by a newline.
    static func previewBodies(from content: String, defaultEnabled: Bool) -> [String]? {
        let previews = rawPreviews(from: content, defaultEnabled: defaultEnabled)
        return previews?.map(\.body)
    }

    static func previewModels(from content: String, filename: String, defaultEnabled: Bool) -> [String: RawPreviewModel]? {
        guard let previews = rawPreviews(from: content, defaultEnabled: defaultEnabled) else { return nil }

        var models: [String: RawPreviewModel] = [:]
        for (index, preview) in previews.enumerated() {
            let key = "\(filename)_\(index)"
            models[key] = RawPreviewModel(
                displayName: preview.parser.displayName ?? key,
                traits: preview.parser.traits ?? [Constants.defaultTrait],
                fixedLayoutSize: preview.parser.fixedLayoutSize,
                body: preview.parser.body ?? "",
                properties: preview.parser.propertiesSource,
                arguments: preview.parser.arguments,
                argumentPattern: preview.parser.argumentPattern
            )
        }

        return models.isEmpty ? nil : models
    }
}

private extension PreviewLoader {
    struct RawPreview {
        let body: String
        let parser: PreviewParser
    }

    static func rawPreviews(from content: String, defaultEnabled: Bool) -> [RawPreview]? {
        // Locate `#Preview` macros with SwiftSyntax rather than a line-based brace scanner.
        // The scanner used to miscount braces that appear inside string literals, comments or
        // raw strings (e.g. `#Preview("{braced}")`), truncating the collected body. SwiftSyntax
        // understands the grammar, so the macro's real source range is always correct.
        let sourceFile = Parser.parse(source: content)
        let collector = PreviewMacroCollector()
        collector.walk(sourceFile)

        let sourceBytes = Array(content.utf8)
        var previews: [RawPreview] = []

        for preview in collector.previews {
            guard preview.startOffset <= preview.endOffset, preview.endOffset <= sourceBytes.count else { continue }
            let body = String(decoding: sourceBytes[preview.startOffset..<preview.endOffset], as: UTF8.self) + "\n"

            let viewMustBeLoaded: Bool
            if defaultEnabled {
                viewMustBeLoaded = !body.contains(Constants.prefireDisableMarker)
            } else {
                viewMustBeLoaded = body.contains(Constants.prefireEnabledMarker)
            }

            if viewMustBeLoaded {
                previews.append(RawPreview(body: body, parser: preview.parser))
            }
        }

        return previews.isEmpty ? nil : previews
    }
}

/// Collects the source ranges of every `#Preview` macro in a file, in source order.
private final class PreviewMacroCollector: SyntaxVisitor {
    struct PreviewRange {
        let startOffset: Int
        let endOffset: Int
        let parser: PreviewParser
    }

    private(set) var previews: [PreviewRange] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(macroName: node.macroName.text, pound: node.pound, node: node)
        return .visitChildren
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        record(macroName: node.macroName.text, pound: node.pound, node: node)
        return .visitChildren
    }

    /// Records the macro's range, starting at the `#` token so that leading attributes
    /// (e.g. `@available(...)`) are excluded, matching the shape the downstream parser expects.
    private func record(macroName: String, pound: TokenSyntax, node: some SyntaxProtocol) {
        guard macroName == PreviewLoader.Constants.previewMacro else { return }
        let parser = PreviewParser()
        parser.walk(node)
        previews.append(
            PreviewRange(
                startOffset: pound.positionAfterSkippingLeadingTrivia.utf8Offset,
                endOffset: node.endPositionBeforeTrailingTrivia.utf8Offset,
                parser: parser
            )
        )
    }
}
