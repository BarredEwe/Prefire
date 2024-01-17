import Foundation

extension PreviewLoader {
    static func loadPreviewBodies(for target: String, and sources: String) -> String? {
        guard let findedBodies = loadRawPreviewBodies(for: target, and: sources) else { return nil }

        let result = findedBodies.map { makeFunc(body: $0) + "\r\n" }.reduce("", +)

        return result
    }

    private static func makeFunc(body: String) -> String {
        let rawPreviewModel = RawPreviewModel(from: body)
        let isScreen = rawPreviewModel.traits == ".device"

        return """
                func test_\(rawPreviewModel.displayName)_Preview() {
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
