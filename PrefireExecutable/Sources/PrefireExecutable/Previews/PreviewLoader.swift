import Foundation

enum PreviewLoader {}

extension PreviewLoader {
    static let viewMarkerStart = "        DeveloperToolsSupport"
    static let viewMarkerEnd = "    }"
    static let prefireDisableMarker = ".prefireIgnored()"

    static let macroType = "fMf" // freestanding macro
    static let macroName = "Preview" + macroType
    static let macroManglingPrefix = "@__swiftmacro_"

    static func loadRawPreviewBodies(for target: String) -> [String]? {
        let previewMacrosDirectory = FileManager.default.temporaryDirectory.appending(path: "swift-generated-sources")
        let fileURLs = try? FileManager.default.contentsOfDirectory(at: previewMacrosDirectory, includingPropertiesForKeys: nil)

        var findedBodies = [String]()

        for fileURL in fileURLs ?? [] {
            var fileName = fileURL.lastPathComponent
                .replacingOccurrences(of: "_.swift", with: "")
                .replacingOccurrences(of: macroManglingPrefix, with: "")
            fileName.removeLastNumber()

            let charCount = fileName.removeFirstNumber() ?? 0
            let moduleName = fileName.prefix(charCount)

            guard fileName.hasSuffix(macroName), moduleName == target else { continue }

            if let previewBody = loadPreviewBody(from: fileURL), !findedBodies.contains(previewBody) {
                findedBodies.append(previewBody)
            }
        }

        guard !findedBodies.isEmpty else { return nil }

        return findedBodies
    }

    static func loadPreviewBody(from fileURL: URL) -> String? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8), !content.isEmpty else { return nil }

        var result = ""
        var isInsideFunction = false

        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix(viewMarkerStart) {
                isInsideFunction = true
            } else if line.hasPrefix(viewMarkerEnd) {
                isInsideFunction = false
                result.removeLast()
            }

            if line.hasSuffix(prefireDisableMarker) {
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
