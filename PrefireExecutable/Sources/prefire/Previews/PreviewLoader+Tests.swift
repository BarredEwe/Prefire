import Foundation

extension PreviewLoader {
    static func loadPreviewBodies(for target: String, and sources: String) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target, and: sources) else { return nil }

        let result = findedBodies.map { makeFunc(body: $0) + "\r\n" }.reduce("", +)

        return result
    }

    private static func makeFunc(body: String) -> String {
        var components = body.components(separatedBy: "\n")
        let previewName = components.first?.components(separatedBy: "\"")
            .first(where: { !$0.hasPrefix("        DeveloperToolsSupport") })

        components.removeFirst()
        components.removeLast()

        let previewBody = components.map { $0 + "\n" }.reduce("", +)

        lazy var viewName = components.first?
            .components(separatedBy: "(").first?
            .replacingOccurrences(of: " ", with: "")

        guard let displayName = previewName ?? viewName else {
            fatalError("Cannot get view name")
        }

        return """
                func test_\(displayName)_Preview() {
                    let preview = {
            \(previewBody)
                    \r\n
                    if let failure = assertSnapshots(matching: AnyView(preview()), name: "\(displayName)", isScreen: true, device: deviceConfig) {
                        XCTFail(failure)
                    }
                }

            """
    }
}
