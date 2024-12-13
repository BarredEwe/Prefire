import Foundation

extension PreviewLoader {
    private static let yamlSettings = "|-4\n\n"
    private static let previewSpaces = "                    "

    /// Loading and creating lines of code with the `PreviewModel` array
    /// - Parameters:
    ///   - sources: Paths to the processed files with #Preview
    ///   - defaultEnabled: Automatic view addition is enabled
    /// - Returns: Ready-made code with a PreviewModel array for embedding in a template file
    static func loadMacroPreviewBodies(for sources: [String], defaultEnabled: Bool) async -> String? {
        guard let findedBodies = await loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }

        let previewModels = findedBodies
            .map { RawPreviewModel(from: $0.value, filename: $0.key, lineSymbol: previewSpaces).previewModel }
            .joined(separator: "\n")

        return yamlSettings +
            """
                @MainActor
                private struct MacroPreviews {
                    static var previews: [PreviewModel] = [
            \(previewModels)
                    ]
                }
            """
    }
}
