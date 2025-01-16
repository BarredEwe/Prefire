import Foundation

// Simplify and improve the process of locating and parsing generated preview code for Swift projects.
enum PreviewLoader {
    enum Constants {
        static let previewMarker = "#Preview"
        static let prefireDisableMarker = ".prefireIgnored()"
        static let prefireEnabledMarker = ".prefireEnabled()"
        static let openingBrace: Character = "{"
        static let closingBrace: Character = "}"
    }

    static private let cacheManager = CacheManager()
    static private let fileManager = FileManager.default

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
                    await processURL(url, defaultEnabled: defaultEnabled)
                }
            }

            for await result in group {
                guard let bodies = result else { continue }
                previewBodyDictionary.merge(bodies) { _, new in new }
            }
        }

        return previewBodyDictionary.isEmpty ? nil : previewBodyDictionary
    }

    // MARK: - Private

    /// Processes a given URL to load raw preview bodies.
    /// - Parameters:
    ///   - url: The URL to process.
    ///   - fileManager: The file manager instance to use for file operations.
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: A dictionary containing the preview bodies for the sources, with file names as keys and preview bodies as values
    private static func processURL(_ url: URL, defaultEnabled: Bool) async -> [String: String]? {
        do {
            if url.isDirectory {
                let files = fileManager.listFiles(atPath: url.path, withExtension: ".swift")
                return await loadRawPreviewBodies(for: files, defaultEnabled: defaultEnabled)
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else { return nil }

            if let cachedPreviewBodies = cacheManager.loadCache(for: url, modificationDate: modificationDate) {
                return cachedPreviewBodies
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

            cacheManager.saveCache(localPreviewBodyDictionary, for: url, modificationDate: modificationDate)

            return localPreviewBodyDictionary
        } catch {
            Logger.print("⚠️ Cannot load file with Preview macro at path: \(url.path): \(error)")
            return nil
        }
    }

    // Extracts preview bodies from the given content.
    private static func previewBodies(from content: String, defaultEnabled: Bool) -> [String]? {
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

    // Reads the contents of a file at the specified path.
    private static func readFile(atPath path: String) async throws -> String {
        try String(contentsOfFile: path)
    }
}

// CacheManager handles the caching of parsed preview bodies
class CacheManager {
    private let fileManager = FileManager.default

    // Loads cached data for the given URL if available and valid.
    func loadCache(for url: URL, modificationDate: Date) -> [String: String]? {
        let cacheURL = cacheFileURL(for: url)
        guard let cacheAttributes = try? fileManager.attributesOfItem(atPath: cacheURL.path),
              let cacheModificationDate = cacheAttributes[.modificationDate] as? Date,
              abs(cacheModificationDate.timeIntervalSince1970 - modificationDate.timeIntervalSince1970) < 1,
              let cachedData = try? Data(contentsOf: cacheURL),
              let cachedPreviewBodies = try? JSONDecoder().decode([String: String].self, from: cachedData) else {
            return nil
        }
        return cachedPreviewBodies
    }

    // Clears the cache by removing all cached files.
    func clearCache() {
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("prefire")
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in cachedFiles {
                try fileManager.removeItem(at: file)
            }
            Logger.print("✅ Cache cleared successfully.")
        } catch {
            Logger.print("⚠️ Cannot clear cache: \(error)")
        }
    }

    // Saves parsed preview bodies to the cache for the given URL.
    func saveCache(_ previewBodies: [String: String], for url: URL, modificationDate: Date) {
        let cacheURL = cacheFileURL(for: url)
        do {
            let data = try JSONEncoder().encode(previewBodies)
            try data.write(to: cacheURL, options: .atomic)
            try fileManager.setAttributes([.modificationDate: modificationDate], ofItemAtPath: cacheURL.path)
        } catch {
            Logger.print("⚠️ Cannot save cache for file at path: \(url.path): \(error)")
        }
    }

    // Returns the cache file URL for the given file URL.
    private func cacheFileURL(for url: URL) -> URL {
        let tempDirectory = fileManager.temporaryDirectory.appending(component: "prefire").appending(component: "")

        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileName = url.lastPathComponent
        return tempDirectory.appendingPathComponent(fileName)
    }
}
