import Foundation

extension PreviewLoader {
    private static let yamlSettings = "|-4\n\n"

    /// Loading and creating lines of code with the `PreviewModel` array
    /// - Parameters:
    ///   - sources: Paths to the processed files with #Preview
    ///   - defaultEnabled: Automatic view addition is enabled
    /// - Returns: Ready-made code with a PreviewModel array for embedding in a template file
    static func loadMacroPreviewBodies(for sources: [String], defaultEnabled: Bool) async -> String? {
        guard let findedBodies = await loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }

        let previewModels = findedBodies
            .sorted { $0.key > $1.key }
            .compactMap { RawPreviewModel(from: $0.value, filename: $0.key) }

        return yamlSettings +
            """
                @MainActor
                private struct MacroPreviews {
                \(previewModels.filter({ $0.properties != nil }).map({ $0.previewWrapper }).joined(separator: "\r\n"))

                    static var previews: [PreviewModel] = [
            \(previewModels.map(\.previewModel).joined(separator: "\r\n"))
                    ]
                }
            """
    }
}
