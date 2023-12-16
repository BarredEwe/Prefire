import Foundation

enum PreviewLoader {}

extension PreviewLoader {
    enum Keys {
        static let viewMarkerStart = "        DeveloperToolsSupport"
        static let viewMarkerEnd = "    }"

        static let prefireDisableMarker = ".prefireIgnored()"

        static let source = "// original-source-range: "
        static let fileType = "_.swift"

        static let macroType = "fMf" // freestanding macro
        static let macroName = "Preview" + macroType
    }

    static func loadRawPreviewBodies(for target: String, and sources: String) -> [String]? {
        let previewMacrosDirectory = FileManager.default.temporaryDirectory.appending(path: "swift-generated-sources")
        let fileURLs = try? FileManager.default.contentsOfDirectory(at: previewMacrosDirectory, includingPropertiesForKeys: nil)

        var findedBodies = [String]()

        for fileURL in fileURLs ?? [] {
            guard fileURL.lastPathComponent.hasSuffix(Keys.macroName + Keys.fileType) else { continue }

            if let previewBody = loadPreviewBody(from: fileURL, and: sources), !findedBodies.contains(previewBody) {
                findedBodies.append(previewBody)
            }
        }

        guard !findedBodies.isEmpty else { return nil }

        return findedBodies
    }

    static func loadPreviewBody(from fileURL: URL, and sources: String) -> String? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8), !content.isEmpty else { return nil }

        var lines = content.components(separatedBy: .newlines)
        lines.removeLast()

        var result = ""
        var isInsideFunction = false

        guard lines.last?.hasPrefix(Keys.source + sources) == true else { return nil }

        for line in lines {
            if line.hasPrefix(Keys.viewMarkerStart) {
                isInsideFunction = true
            } else if line.hasPrefix(Keys.viewMarkerEnd) {
                isInsideFunction = false
                result.removeLast()
            }

            if line.hasSuffix(Keys.prefireDisableMarker) {
                return nil
            }

            if isInsideFunction {
                result += line + "\n"
            }
        }

        return result + "\n"
    }
}

private extension String {
    @discardableResult
    mutating func removeLastNumber() -> Int? {
        var number = ""
        while self.last?.isNumber ?? false {
            number += String(self.removeLast())
        }

        return Int(number)
    }

    @discardableResult
    mutating func removeFirstNumber() -> Int? {
        var number = ""
        while self.first?.isNumber ?? false {
            number += String(self.removeFirst())
        }

        return Int(number)
    }
}
