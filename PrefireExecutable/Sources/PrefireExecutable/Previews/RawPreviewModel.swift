import Foundation

struct RawPreviewModel {
    var name: String
    var previewTrait: String
    var previewBody: String
}

extension RawPreviewModel {
    init(from body: String) {
        var components = body.components(separatedBy: "\n")
        let previewName = components.first?.components(separatedBy: "\"")
            .first(where: { !$0.hasPrefix("        DeveloperToolsSupport") })

        var previewTrait: String?
        let traitsComponents = components.first?.components(separatedBy: "traits: ")
        if traitsComponents?.count ?? 0 > 1 {
            previewTrait = traitsComponents?.last?.components(separatedBy: ")").first
        }

        components.removeFirst()
        components.removeLast()
        components.removeLast()

        let previewBody = components.map { "\t\t" + $0 + "\n" }.reduce("", +)

        lazy var viewName = components.first?
            .components(separatedBy: "(").first?
            .replacingOccurrences(of: " ", with: "")

        guard let displayName = previewName ?? viewName else {
            fatalError("Cannot get view name")
        }

        name = displayName
        self.previewBody = previewBody
        self.previewTrait = previewTrait ?? ".device"
    }
}

extension RawPreviewModel {
    var previewModel: String {
        """
                PreviewModel(
                    content: {
                        AnyView(
        \(previewBody)
                        )
                    },
                    name: \"\(name)\",
                    type: \(previewTrait == ".device" ? ".screen" : ".component"),
                    device: nil
                ),\n
        """
    }
}
