import Foundation

/// Marketing names for device model identifiers such as `iPhone17,1`.
///
/// The generated tests compare `simulator_device` from `.prefire.yml` against
/// `SIMULATOR_MODEL_IDENTIFIER`, so a mismatch is reported in identifiers only. The table turns
/// them back into names a human recognises. It is best-effort: an unknown identifier is reported
/// as-is, and a name coming from the environment always wins over the table.
public enum PrefireDeviceIdentifier {
    /// Marketing name for a model identifier, or `nil` when the identifier is not in the table.
    public static func name(for identifier: String) -> String? {
        names[identifier.trimmingCharacters(in: .whitespaces)]
    }

    /// Identifier with its name when one is known: `iPhone 16 Pro (iPhone17,1)`.
    ///
    /// - Parameter name: Name reported by the simulator environment. Preferred over the table,
    ///                   because it also covers devices added after this table was written.
    public static func describe(_ identifier: String, name: String? = nil) -> String {
        let reported = name?.trimmingCharacters(in: .whitespaces)
        let resolved = reported.flatMap { $0.isEmpty ? nil : $0 } ?? Self.name(for: identifier)
        guard let resolved, resolved != identifier else { return identifier }
        return "\(resolved) (\(identifier))"
    }

    private static let names: [String: String] = Dictionary(
        uniqueKeysWithValues: table.flatMap { entry in entry.identifiers.map { ($0, entry.name) } }
    )

    private static let table: [(identifiers: [String], name: String)] = [
        (["iPhone8,1"], "iPhone 6s"),
        (["iPhone8,2"], "iPhone 6s Plus"),
        (["iPhone8,4"], "iPhone SE (1st generation)"),
        (["iPhone9,1", "iPhone9,3"], "iPhone 7"),
        (["iPhone9,2", "iPhone9,4"], "iPhone 7 Plus"),
        (["iPhone10,1", "iPhone10,4"], "iPhone 8"),
        (["iPhone10,2", "iPhone10,5"], "iPhone 8 Plus"),
        (["iPhone10,3", "iPhone10,6"], "iPhone X"),
        (["iPhone11,2"], "iPhone XS"),
        (["iPhone11,4", "iPhone11,6"], "iPhone XS Max"),
        (["iPhone11,8"], "iPhone XR"),
        (["iPhone12,1"], "iPhone 11"),
        (["iPhone12,3"], "iPhone 11 Pro"),
        (["iPhone12,5"], "iPhone 11 Pro Max"),
        (["iPhone12,8"], "iPhone SE (2nd generation)"),
        (["iPhone13,1"], "iPhone 12 mini"),
        (["iPhone13,2"], "iPhone 12"),
        (["iPhone13,3"], "iPhone 12 Pro"),
        (["iPhone13,4"], "iPhone 12 Pro Max"),
        (["iPhone14,2"], "iPhone 13 Pro"),
        (["iPhone14,3"], "iPhone 13 Pro Max"),
        (["iPhone14,4"], "iPhone 13 mini"),
        (["iPhone14,5"], "iPhone 13"),
        (["iPhone14,6"], "iPhone SE (3rd generation)"),
        (["iPhone14,7"], "iPhone 14"),
        (["iPhone14,8"], "iPhone 14 Plus"),
        (["iPhone15,2"], "iPhone 14 Pro"),
        (["iPhone15,3"], "iPhone 14 Pro Max"),
        (["iPhone15,4"], "iPhone 15"),
        (["iPhone15,5"], "iPhone 15 Plus"),
        (["iPhone16,1"], "iPhone 15 Pro"),
        (["iPhone16,2"], "iPhone 15 Pro Max"),
        (["iPhone17,1"], "iPhone 16 Pro"),
        (["iPhone17,2"], "iPhone 16 Pro Max"),
        (["iPhone17,3"], "iPhone 16"),
        (["iPhone17,4"], "iPhone 16 Plus"),
        (["iPhone17,5"], "iPhone 16e"),
        (["iPod9,1"], "iPod touch (7th generation)"),
        (["iPad7,11", "iPad7,12"], "iPad (7th generation)"),
        (["iPad11,6", "iPad11,7"], "iPad (8th generation)"),
        (["iPad12,1", "iPad12,2"], "iPad (9th generation)"),
        (["iPad13,18", "iPad13,19"], "iPad (10th generation)"),
        (["iPad11,1", "iPad11,2"], "iPad mini (5th generation)"),
        (["iPad14,1", "iPad14,2"], "iPad mini (6th generation)"),
        (["iPad11,3", "iPad11,4"], "iPad Air (3rd generation)"),
        (["iPad13,1", "iPad13,2"], "iPad Air (4th generation)"),
        (["iPad13,16", "iPad13,17"], "iPad Air (5th generation)"),
        (["iPad14,8", "iPad14,9"], "iPad Air 11-inch (M2)"),
        (["iPad14,10", "iPad14,11"], "iPad Air 13-inch (M2)"),
        (["iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4"], "iPad Pro (11-inch) (1st generation)"),
        (["iPad8,9", "iPad8,10"], "iPad Pro (11-inch) (2nd generation)"),
        (["iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7"], "iPad Pro (11-inch) (3rd generation)"),
        (["iPad14,3", "iPad14,4"], "iPad Pro (11-inch) (4th generation)"),
        (["iPad16,3", "iPad16,4"], "iPad Pro 11-inch (M4)"),
        (["iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8"], "iPad Pro (12.9-inch) (3rd generation)"),
        (["iPad8,11", "iPad8,12"], "iPad Pro (12.9-inch) (4th generation)"),
        (["iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11"], "iPad Pro (12.9-inch) (5th generation)"),
        (["iPad14,5", "iPad14,6"], "iPad Pro (12.9-inch) (6th generation)"),
        (["iPad16,5", "iPad16,6"], "iPad Pro 13-inch (M4)"),
        (["AppleTV5,3"], "Apple TV HD"),
        (["AppleTV6,2"], "Apple TV 4K (1st generation)"),
        (["AppleTV11,1"], "Apple TV 4K (2nd generation)"),
        (["AppleTV14,1"], "Apple TV 4K (3rd generation)"),
    ]
}
