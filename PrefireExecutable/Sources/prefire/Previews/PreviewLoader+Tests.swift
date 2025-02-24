import Foundation

extension PreviewLoader {
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)
    private static let yamlSettings = "|-4\n\n"

    static func loadPreviewBodies(for sources: [String], defaultEnabled: Bool) async -> String? {
        guard let rawBodies = await loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }
        
        let functions = rawBodies
            .sorted { $0.key > $1.key }
            .compactMap { makeTestFunc(fileName: $0.key, body: $0.value) }
            .joined(separator: "\r\n")
        
        return yamlSettings + functions
    }

    private static func makeTestFunc(fileName: String, body: String) -> String? {
        guard let model = RawPreviewModel(from: body, filename: fileName) else { return nil }
        
        let componentTestName = model.displayName.components(separatedBy: funcCharacterSet).joined()
        let settingsSuffix = (model.snapshotSettings?.replacingOccurrences(of: "snapshot", with: "init")).flatMap { ", settings: \($0)" } ?? ""
        
        let previewCode: String
        let content: String
        if model.properties == nil {
            previewCode = "        let preview = {\n\(model.body.ident(12))\n            }"
            content = "preview()"
        } else {
            previewCode = model.previewWrapper.ident(4)
            content = "PreviewWrapper\(model.displayName)()"
        }
        
        let prefireSnapshot = "PrefireSnapshot(\(content), name: \"\(model.displayName)\", isScreen: \(model.isScreen), device: deviceConfig\(settingsSuffix))"
        
        return """
                    func test_\(componentTestName)_Preview() {
                \(previewCode)
                        if let failure = assertSnapshots(for: \(prefireSnapshot)) {
                            XCTFail(failure)
                        }
                    }
            """
    }
}
