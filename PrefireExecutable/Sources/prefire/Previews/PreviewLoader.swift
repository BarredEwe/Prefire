import Foundation

/// Simplify and improve the process of locating and parsing generated preview code for Swift projects.
enum PreviewLoader {
    enum Constants {
        static let previewMarker = "#Preview"
        static let prefireDisableMarker = ".prefireIgnored()"
        static let prefireEnabledMarker = ".prefireEnabled()"
        static let openingBrace: Character = "{"
        static let closingBrace: Character = "}"
    }

    /// Attempts to locate raw preview bodies within the specified sources string and returns them as an array of Strings.
    /// - Parameters:
    ///   - sources: Paths to a source swift files or directories.
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: A dictionary containing the preview bodies for the sources, with file names as keys and preview bodies as values
    static func loadRawPreviewBodies(for sources: [String], defaultEnabled: Bool) async -> [String: String]? {
        var previewBodyDictionary = [String: String]()
        
        await withTaskGroup(of: [String: String]?.self) { group in
            for url in sources.compactMap(URL.init(string:)) {
                group.addTask {
                    do {
                        let fileManager = FileManager.default
                        if fileManager.checkIfDirectoryExists(at: url) {
                            let files = fileManager.listFiles(atURL: url, withExtension: ".swift")
                            return await loadRawPreviewBodies(for: files, defaultEnabled: defaultEnabled)
                        }

                        let content = try await readFile(atPath: url.path)
                        guard content.range(of: Constants.previewMarker) != nil else { return nil }

                        var localPreviewBodyDictionary = [String: String]()
                        if let previewBodies = previewBodies(from: content, defaultEnabled: defaultEnabled) {
                            let fileName = url.fileName
                            previewBodies.enumerated().forEach { index, previewBody in
                                localPreviewBodyDictionary["\(fileName)_\(index)"] = previewBody
                            }
                        }
                        return localPreviewBodyDictionary
                    } catch {
                        Logger.print("⚠️ Cannot load file with Preview macro at path: \(url.path) with error \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await result in group {
                guard let bodies = result else { continue }
                previewBodyDictionary.merge(bodies) { _, new in new }
            }
        }

        return previewBodyDictionary.isEmpty ? nil : previewBodyDictionary
    }

    /// Extract the preview body using the passed content
    ///
    /// - Parameters:
    ///   - content: File content
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: An array representing the results of the macro preview without the initial `#Preview` and final `}`.
    static func previewBodies(from content: String, defaultEnabled: Bool) -> [String]? {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var previewBodies: [String] = []

        var currentBody: String = ""
        var previewWasFound = false
        var viewMustBeLoaded = defaultEnabled
        var braceBalance = 0

        for line in lines {
            if line.hasPrefix(Constants.previewMarker) {
                previewWasFound = true
                currentBody = ""
                braceBalance = 0
            }

            guard previewWasFound else { continue }

            braceBalance += line.reduce(0) { (count, char) in
                if char == Constants.openingBrace {
                    return count + 1
                } else if char == Constants.closingBrace {
                    return count - 1
                }
                return count
            }

            if defaultEnabled {
                if line.hasSuffix(Constants.prefireDisableMarker) {
                    viewMustBeLoaded = false
                }
            } else if !viewMustBeLoaded {
                viewMustBeLoaded = line.hasSuffix(Constants.prefireEnabledMarker)
            }

            currentBody.append(String(line) + "\n")

            if braceBalance == 0 {
                if !currentBody.isEmpty, viewMustBeLoaded {
                    previewBodies.append(currentBody)
                }

                previewWasFound = false
                viewMustBeLoaded = defaultEnabled
            }
        }

        return previewBodies.isEmpty ? nil : previewBodies
    }

    static private func readFile(atPath path: String) async throws -> String {
        return try String(contentsOfFile: path)
    }
}
