import Foundation

struct RawPreviewModel {
    var displayName: String
    var traits: String
    var body: String
}

extension RawPreviewModel {
    private enum Markers {
        static let previewMacro = "#Preview"
        static let traits = "traits: "
    }

    private enum Constants {
        static let bodySeparatorCharacters = CharacterSet(charactersIn: "{(")
        static let defaultTrait = ".device"
    }

    /// Initialization from the macro Preview body
    /// - Parameters:
    ///   - macroBody: Preview View body
    ///   - filename: File name in which the macro was found
    ///   - lineSymbol: The line separator symbol
    init(from macroBody: String, filename: String, lineSymbol: String = "") {
        var components = macroBody.components(separatedBy: "\n")

        let previewName = components.first?.components(separatedBy: "\"")
            .first(where: { !$0.contains(Markers.previewMacro) })
        self.displayName = previewName ?? filename

        var previewTrait: String?
        let traitsComponents = components.first?.components(separatedBy: Markers.traits)
        if traitsComponents?.count ?? 0 > 1 {
            previewTrait = traitsComponents?.last?.components(separatedBy: ")").first
        }

        components.removeFirst()
        components.removeLast(2)

        let previewBody = components.map { lineSymbol + $0 }.joined(separator: "\n")

        self.body = previewBody
        self.traits = previewTrait ?? Constants.defaultTrait
    }
}

extension RawPreviewModel {
    var previewModel: String {
        """
                    PreviewModel(
                        content: {
                            AnyView(
        \(body)
                            )
                        },
                        name: \"\(displayName)\",
                        type: \(traits == ".device" ? ".screen" : ".component"),
                        device: nil
                    ),
        """
    }
}
