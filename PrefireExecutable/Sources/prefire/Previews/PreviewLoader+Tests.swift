import Foundation

extension PreviewLoader {
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)
    private static let yamlSettings = "|-4\n\n"
    private static let previewSpaces = "            "

    static func loadPreviewBodies(for sources: [String], defaultEnabled: Bool) async -> String? {
        guard let findedBodies = await loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }

        let result = findedBodies
            .sorted(by: { $0.key > $1.key })
            .compactMap { makeFunc(fileName: $0.key, body: $0.value)?.appending("\r\n") }
            .joined()

        return yamlSettings + result
    }

    private static func makeFunc(fileName: String, body: String) -> String? {
        guard let rawPreviewModel = RawPreviewModel(from: body, filename: fileName, lineSymbol: previewSpaces) else { return nil }
        let isScreen = rawPreviewModel.traits == ".device"
        let componentTestName = rawPreviewModel.displayName.components(separatedBy: funcCharacterSet).joined()
        let snapshotSettings = rawPreviewModel.snapshotSettings?.replacingOccurrences(of: "snapshot", with: "init")

        return 
            """
                    func test_\(componentTestName)_Preview() {
                        let preview = {
            \(rawPreviewModel.body)
                        }
                        if let failure = assertSnapshots(for: PrefireSnapshot(preview(), name: "\(rawPreviewModel.displayName)", isScreen: \(isScreen), device: deviceConfig\(snapshotSettings.flatMap({ ", settings: " + $0 }) ?? ""))) {
                            XCTFail(failure)
                        }
                    }
            """
    }
}
