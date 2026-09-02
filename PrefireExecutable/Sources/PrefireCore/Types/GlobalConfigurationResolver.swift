import Foundation

/// Decides which `PrefireGlobalConfiguration` the generated file should apply.
///
/// `global_configuration:` in `.prefire.yml` always wins. Without it, a single type conforming to
/// the protocol anywhere in the scanned sources is picked up automatically, so the common case
/// needs no configuration at all.
enum GlobalConfigurationResolver {
    static let protocolName = "PrefireGlobalConfiguration"
    static let argumentKey = "globalConfiguration"

    /// Access levels a generated file in the same module cannot name.
    private static let unreachableAccessLevels: Set<String> = ["private", "fileprivate"]

    static func resolve(arguments: [String: NSObject], graph: TypeGraph) throws -> [String: NSObject] {
        let candidates = graph.types(conformingTo: protocolName)

        if let configured = arguments[argumentKey] as? String {
            warnIfConfiguredTypeIsUnreachable(named: configured, candidates: candidates)
            return arguments
        }

        let (reachable, unreachable) = candidates.partitionedByReachability()

        for type in unreachable {
            Logger.warning(
                """
                ⚠️ '\(type.name)' conforms to \(protocolName) but is '\(type.accessLevel)', so the generated \
                file cannot reference it. Raise its access level to have it picked up automatically.
                """
            )
        }

        guard let detected = reachable.first else { return arguments }

        guard reachable.count == 1 else {
            throw GlobalConfigurationError.ambiguous(names: reachable.map(\.name))
        }

        Logger.info("🔍 Detected global configuration: \(detected.name)")

        var arguments = arguments
        arguments[argumentKey] = detected.name as NSString
        return arguments
    }

    /// A configured name that resolves to an unreachable declaration would fail to compile with a
    /// message pointing at the generated file, so say it here instead.
    private static func warnIfConfiguredTypeIsUnreachable(named name: String, candidates: [ParsedType]) {
        guard let type = candidates.first(where: { $0.name == name || $0.localName == name }),
              unreachableAccessLevels.contains(type.accessLevel) else { return }

        Logger.warning(
            """
            ⚠️ global_configuration is set to '\(name)', which is declared '\(type.accessLevel)'. \
            The generated file cannot reference it and will not compile.
            """
        )
    }

    fileprivate static func isReachable(_ type: ParsedType) -> Bool {
        !unreachableAccessLevels.contains(type.accessLevel)
    }
}

enum GlobalConfigurationError: LocalizedError {
    case ambiguous(names: [String])

    var errorDescription: String? {
        switch self {
        case let .ambiguous(names):
            return """
            Found \(names.count) types conforming to \(GlobalConfigurationResolver.protocolName): \
            \(names.sorted().joined(separator: ", ")). Prefire cannot tell which one to apply — \
            name it explicitly with 'global_configuration:' in .prefire.yml.
            """
        }
    }
}

private extension [ParsedType] {
    func partitionedByReachability() -> (reachable: [ParsedType], unreachable: [ParsedType]) {
        (
            reachable: filter(GlobalConfigurationResolver.isReachable),
            unreachable: filter { !GlobalConfigurationResolver.isReachable($0) }
        )
    }
}
