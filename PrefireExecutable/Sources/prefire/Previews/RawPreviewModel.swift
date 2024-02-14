import Foundation

struct RawPreviewModel {
    var displayName: String
    var traits: String
    var body: String
}

extension RawPreviewModel {
    private enum Keys {
        static let viewMarkerStart = "        DeveloperToolsSupport"
    }
    
    /// Initialization from the macro Preview body
    /// - Parameters:
    ///   - macroBody: Preview View body
    ///   - lineSymbol: The line separator symbol
    init(from macroBody: String, lineSymbol: String = "") {
        var components = macroBody.components(separatedBy: "\n")

        let previewName = components.first?.components(separatedBy: "\"")
            .first(where: { !$0.hasPrefix(Keys.viewMarkerStart) })

        var previewTrait: String?
        let traitsComponents = components.first?.components(separatedBy: "traits: ")
        if traitsComponents?.count ?? 0 > 1 {
            previewTrait = traitsComponents?.last?.components(separatedBy: ")").first
        }

        components.removeFirst()
        components.removeLast(2)

        let previewBody = components.map { lineSymbol + $0 + "\n" }.reduce("", +)

        lazy var viewName = components.first?
            .components(separatedBy: "(").first?
            .replacingOccurrences(of: " ", with: "")

        guard let displayName = previewName ?? viewName else {
            fatalError("Cannot get view name")
        }

        self.displayName = displayName
        self.body = previewBody
        self.traits = previewTrait ?? ".device"
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
                ),\n
        """
    }
}
