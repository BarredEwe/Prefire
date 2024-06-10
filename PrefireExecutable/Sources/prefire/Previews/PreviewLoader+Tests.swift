import Foundation

extension PreviewLoader {
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)
    private static let yamlSettings = "|-4\n\n"
    private static let previewSpaces = "            "

    static func loadPreviewBodies(for sources: [String], defaultEnabled: Bool) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }

        let result = findedBodies
            .sorted(by: { $0.key > $1.key })
            .map { makeFunc(fileName: $0.key, body: $0.value) + "\r\n" }
            .joined()

        return yamlSettings + result
    }

    private static func makeFunc(fileName: String, body: String) -> String {
        let rawPreviewModel = RawPreviewModel(from: body, filename: fileName, lineSymbol: previewSpaces)
        let isScreen = rawPreviewModel.traits == ".device"
        let componentTestName = rawPreviewModel.displayName.components(separatedBy: funcCharacterSet).joined()

        return 
            """
                    func test_\(componentTestName)_Preview() {
                        let preview = {
            \(rawPreviewModel.body)
                        }
                        if let failure = assertSnapshots(matching: AnyView(preview()), name: "\(rawPreviewModel.displayName)", isScreen: \(isScreen), device: deviceConfig) {
                            XCTFail(failure)
                        }
                    }
            """
    }
}
