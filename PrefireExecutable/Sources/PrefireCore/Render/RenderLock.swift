import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// Holds a render directory for one render at a time, like `prefire mcp` and `prefire render` run at
/// once. Another render waits for it.
///
/// The lock is `flock` on a file in the directory, so the system lets it go when the process ends.
final class RenderLock {
    static let fileName = ".prefire-render.lock"

    private var descriptor: Int32

    init(directory: URL) throws {
        let path = directory.appendingPathComponent(Self.fileName).path
        descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            throw RenderError.invalidOption("Prefire could not open \(path) to lock the render directory.")
        }
        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            Logger.warning("Another render is writing to \(directory.path), waiting for it to finish...")
            flock(descriptor, LOCK_EX)
        }
    }

    func unlock() {
        guard descriptor >= 0 else { return }
        flock(descriptor, LOCK_UN)
        close(descriptor)
        descriptor = -1
    }

    deinit {
        unlock()
    }
}
