import Foundation

extension PreviewLoader {
    static let previewMacroMarker = "PreviewfMf"

    static func loadMacroPreviewBodies(for target: String) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target) else { return nil }

        let previewModels = findedBodies.map { RawPreviewModel(from: $0).previewModel }.reduce("", +)

        return """
            private struct MacroPreviews {
                static var previews: [PreviewModel] = [
            \(previewModels)
                ]
            }
            """
    }
}
