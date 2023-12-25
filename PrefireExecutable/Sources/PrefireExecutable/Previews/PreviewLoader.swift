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
            let fileName = fileURL.lastPathComponent.components(separatedBy: .decimalDigits).joined()
            guard fileName.hasSuffix(Keys.macroName + Keys.fileType) else { continue }

            if let previewBody = loadPreviewBody(from: fileURL, and: sources), !findedBodies.contains(previewBody) {
                findedBodies.append(previewBody)
            }
        }

        guard !findedBodies.isEmpty else { return nil }

        return findedBodies
    }

    static func checkAvailability(for line: String?, and result: [String]) -> Bool {
        guard let line = line?.replacingOccurrences(of: Keys.source, with: "") else { return false }

        var components = line.components(separatedBy: ":")
        components.removeLast()
        components.removeLast()
        let firstLine = Int(components.removeLast()) ?? 0

        guard let path = components.first, let fileURL = URL(string: "file://" + path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8), !content.isEmpty else { return false }

        let lines = content.components(separatedBy: .newlines)
        var result = result
        result.removeFirst()
        result.removeLast()

        for i in 0..<result.count {
            guard let left = result[safe: i]?.trimmingCharacters(in: .whitespaces),
                  let right = lines[safe: firstLine + i]?.trimmingCharacters(in: .whitespaces),
                    left == right else { return false }
        }

        return true
    }

    static func loadPreviewBody(from fileURL: URL, and sources: String) -> String? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8), !content.isEmpty else { return nil }

        var lines = content.components(separatedBy: .newlines)
        lines.removeLast()

        guard lines.last?.hasPrefix(Keys.source + sources) == true else { return nil }

        var result = ""
        var isInsideFunction = false

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

        guard checkAvailability(for: lines.last, and: result.components(separatedBy: .newlines)) else { return nil }

        return result + "\n"
    }
}

extension MutableCollection {
    subscript(safe index: Index) -> Element? {
        get {
            return indices.contains(index) ? self[index] : nil
        }

        set(newValue) {
            if let newValue = newValue, indices.contains(index) {
                self[index] = newValue
            }
        }
    }
}
