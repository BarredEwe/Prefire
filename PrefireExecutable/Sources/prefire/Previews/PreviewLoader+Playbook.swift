import Foundation

extension PreviewLoader {
    private static let yamlSettings = "|-4\n\n"

    /// Loading and creating lines of code with the `PreviewModel` array
    /// - Parameters:
    ///   - target: Working target
    ///   - sources: Paths to the processed files with #Preview
    ///   - defaultEnabled: Automatic view addition is enabled
    /// - Returns: Ready-made code with a PreviewModel array for embedding in a template file
    static func loadMacroPreviewBodies(for target: String, and sources: [String], defaultEnabled: Bool) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target, and: sources, defaultEnabled: defaultEnabled) else { return nil }

        let previewModels = findedBodies.map { RawPreviewModel(from: $0, lineSymbol: "\t\t").previewModel }.reduce("", +)

        return yamlSettings + """
                private struct MacroPreviews {
                static var previews: [PreviewModel] = [
            \(previewModels)
                ]
            }
            """.replacingOccurrences(of: "\n", with: "\n    ")
    }
}
