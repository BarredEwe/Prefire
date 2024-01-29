import Foundation

extension PreviewLoader {
    /// Loading and creating lines of code with the `PreviewModel` array
    /// - Parameters:
    ///   - target: Working target
    ///   - sources: The path to the processed files with #Preview
    /// - Returns: Ready-made code with a PreviewModel array for embedding in a template file
    static func loadMacroPreviewBodies(for target: String, and sources: String) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target, and: sources) else { return nil }

        let previewModels = findedBodies.map { RawPreviewModel(from: $0, lineSymbol: "\t\t").previewModel }.reduce("", +)

        return """
            private struct MacroPreviews {
                static var previews: [PreviewModel] = [
            \(previewModels)
                ]
            }
            """
    }
}
