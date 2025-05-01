import Foundation

extension PreviewLoader {
    static func loadPreviewMacros(for sources: [String], defaultEnabled: Bool) async -> (String, [[String: Any?]])? {
        guard let rawBodies = await loadRawPreviewBodies(for: sources, defaultEnabled: defaultEnabled) else { return nil }
        
        let models = rawBodies
            .sorted { $0.key > $1.key }
            .compactMap { RawPreviewModel(from: $0.value, filename: $0.key) }
        
        return (
            models.map(makeTestFuncString).joined(separator: "\n"),
            models.map(makeTestFuncDict)
        )
    }

    private static func makeTestFuncString(_ model: RawPreviewModel) -> String {
        let componentTestName = model.componentTestName
        let previewCode: String
        let content: String
        if model.properties == nil {
            previewCode = "        let preview = {\n\(model.body.ident(12))\n            }"
            content = "preview()"
        } else {
            previewCode = model.previewWrapper.ident(4)
            content = "PreviewWrapper\(componentTestName)()"
        }
        
        return """
                    func test_\(componentTestName)_Preview() {
                \(previewCode)
                        if let failure = assertSnapshots(for: PrefireSnapshot(\(content), name: \"\(model.displayName)\", isScreen: \(model.isScreen), device: deviceConfig)) {
                            XCTFail(failure)
                        }
                    }
            """
    }

    private static func makeTestFuncDict(_ model: RawPreviewModel) -> [String: Any?] {
        return [
            "displayName": model.displayName,
            "componentTestName": model.componentTestName,
            "isScreen": model.isScreen,
            "body": model.body,
            "properties": model.properties,
        ]
    }
}
