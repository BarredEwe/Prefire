import Foundation

extension PreviewLoader {
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)

    static func loadPreviewBodies(for target: String, and sources: [String], defaultEnabled: Bool) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target, and: sources, defaultEnabled: true) else { return nil }

        let result = findedBodies.map { makeFunc(body: $0) + "\r\n" }.joined()

        return result
    }

    private static func makeFunc(body: String) -> String {
        let rawPreviewModel = RawPreviewModel(from: body)
        let isScreen = rawPreviewModel.traits == ".device"
        let componentTestName = rawPreviewModel.displayName.components(separatedBy: funcCharacterSet).joined()

        return """
                func test_\(componentTestName)_Preview() {
                    let preview = {
            \(rawPreviewModel.body)
                    }
                    \r\n
                    if let failure = assertSnapshots(matching: AnyView(preview()), name: "\(rawPreviewModel.displayName)", isScreen: \(isScreen), device: deviceConfig) {
                        XCTFail(failure)
                    }
                }

            """
    }
}
