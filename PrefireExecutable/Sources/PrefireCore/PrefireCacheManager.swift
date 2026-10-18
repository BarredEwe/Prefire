import Foundation
import CryptoKit
import PathKit

struct PrefireCacheManager {
    private let version: String
    private let cacheBasePath: Path?

    init(version: String, cacheBasePath: Path? = nil) {
        self.version = version
        self.cacheBasePath = cacheBasePath
    }

    func loadOrGenerate(
        sources: [Path],
        template: String,
        parseTypes: () throws -> [ParsedType],
        parsePreviews: () async throws -> [String: RawPreviewModel]
    ) async throws -> (types: [ParsedType], previews: [String: RawPreviewModel]) {
        let key = fingerprint(for: sources, extra: template + "\npreview-model-cache-v3")
        let dir = Path.cachesDir(sourcePath: sources.first ?? .current, basePath: cacheBasePath)
        let typesFile = dir + "\(version)-\(key).types.json"
        let previewsFile = dir + "\(version)-\(key).previews.json"

        var types: [ParsedType]?
        var previews: [String: RawPreviewModel]?

        if typesFile.exists {
            do {
                let data = try Data(contentsOf: typesFile.url)
                types = try JSONDecoder().decode([ParsedType].self, from: data)
            } catch {
                Logger.warning("⚠️ Failed to read Types cache: \(error)")
            }
        }

        if previewsFile.exists {
            do {
                let data = try Data(contentsOf: previewsFile.url)
                previews = try JSONDecoder().decode([String: RawPreviewModel].self, from: data)
            } catch {
                Logger.warning("⚠️ Failed to read Previews cache: \(error)")
            }
        }

        let cacheStamp = typesFile.lastModification
        let isCacheFresh = cacheStamp != nil && sources.allSatisfy {
            ($0.lastModification ?? .distantPast) <= cacheStamp!
        }

        if let types, let previews, isCacheFresh {
            Logger.info("✅ Loaded types and previews from fresh cache.")
            return (types, previews)
        } else {
            Logger.info("♻️ Cache expired or missing. Regenerating…")
        }

        let freshTypes = try parseTypes()
        let freshPreviews = try await parsePreviews()

        let tData = try JSONEncoder().encode(freshTypes)
        let pData = try JSONEncoder().encode(freshPreviews)

        try typesFile.parent().mkpath()
        try tData.write(to: typesFile.url)
        try pData.write(to: previewsFile.url)

        Logger.info("💾 Cache written: types and previews.")

        return (freshTypes, freshPreviews)
    }

    private func fingerprint(for sources: [Path], extra: String) -> String {
        var hasher = SHA256()
        for file in sources.sorted(by: { $0.string < $1.string }) {
            hasher.update(data: Data(file.string.utf8))
            hasher.update(with: file.lastModification ?? .distantPast)
        }
        hasher.update(data: Data(extra.utf8))
        return hasher.finalize().hexString
    }
}

// MARK: - Extensions

private extension SHA256 {
    mutating func update(with date: Date) {
        withUnsafeBytes(of: date.timeIntervalSince1970.bitPattern) {
            update(data: Data($0))
        }
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension Path {
    /// User caches directory, the root Prefire writes its parse cache into.
    static var defaultBaseCachePath: Path {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return Path(paths[0])
    }

    static func cachesDir(
        sourcePath: Path,
        basePath: Path? = nil,
        createIfMissing: Bool = true
    ) -> Path {
        let root = (basePath ?? defaultBaseCachePath) + "PrefireCache"
        let dir = root + sourcePath.absolute().sha256prefix(8)
        if createIfMissing, !dir.exists { try? dir.mkpath() }
        return dir
    }

    fileprivate var lastModification: Date? {
        (try? FileManager.default.attributesOfItem(atPath: string)[.modificationDate]) as? Date
    }

    fileprivate func sha256prefix(_ length: Int) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.hexString.prefix(length).description
    }
}
