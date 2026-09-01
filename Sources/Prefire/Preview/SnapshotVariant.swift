import SwiftUI

/// Environment variation applied to a preview before a snapshot is taken.
///
/// Variants come from the `snapshot_variants` configuration key or from `.snapshotVariants(_:)`.
public enum SnapshotVariant: Hashable, Sendable {
    /// Baseline appearance. Keeps the snapshot name unsuffixed, so recorded snapshots stay valid.
    case light
    case dark
    case sizeCategory(ContentSizeCategory)
    case rightToLeft
    case locale(Locale)

    /// Suffix appended to the snapshot name. Empty for `.light`.
    public var nameSuffix: String {
        switch self {
        case .light: return ""
        case .dark: return "-dark"
        case let .sizeCategory(category): return "-" + Self.name(of: category)
        case .rightToLeft: return "-rtl"
        case let .locale(locale): return "-" + Self.localePrefix + locale.identifier
        }
    }

    /// Creates a variant from its name in the configuration file.
    public init?(name: String) {
        switch name {
        case "light":
            self = .light
        case "dark":
            self = .dark
        case "rtl", "rightToLeft":
            self = .rightToLeft
        default:
            if let category = Self.sizeCategories.first(where: { $0.name == name || $0.swiftUIName == name }) {
                self = .sizeCategory(category.value)
            } else if name.hasPrefix(Self.localePrefix) {
                self = .locale(Locale(identifier: String(name.dropFirst(Self.localePrefix.count))))
            } else {
                return nil
            }
        }
    }

    /// Maps `snapshot_variants` names from the configuration file to variants.
    public static func variants(named names: [String]) -> [SnapshotVariant] {
        names.map { name in
            guard let variant = SnapshotVariant(name: name) else {
                fatalError("Unknown snapshot variant from configuration file: \(name)")
            }
            return variant
        }
    }

    // MARK: - Private

    private static let localePrefix = "locale_"

    private static let sizeCategories: [(name: String, swiftUIName: String, value: ContentSizeCategory)] = [
        ("XS", "extraSmall", .extraSmall),
        ("S", "small", .small),
        ("M", "medium", .medium),
        ("L", "large", .large),
        ("XL", "extraLarge", .extraLarge),
        ("XXL", "extraExtraLarge", .extraExtraLarge),
        ("XXXL", "extraExtraExtraLarge", .extraExtraExtraLarge),
        ("accessibilityM", "accessibilityMedium", .accessibilityMedium),
        ("accessibilityL", "accessibilityLarge", .accessibilityLarge),
        ("accessibilityXL", "accessibilityExtraLarge", .accessibilityExtraLarge),
        ("accessibilityXXL", "accessibilityExtraExtraLarge", .accessibilityExtraExtraLarge),
        ("accessibilityXXXL", "accessibilityExtraExtraExtraLarge", .accessibilityExtraExtraExtraLarge),
    ]

    private static func name(of category: ContentSizeCategory) -> String {
        sizeCategories.first(where: { $0.value == category })?.name ?? "\(category)"
    }
}

extension View {
    /// Applies the variant through the SwiftUI environment, so it works on every platform.
    @ViewBuilder
    func snapshotVariant(_ variant: SnapshotVariant?) -> some View {
        switch variant {
        case .none:
            self
        case .light:
            environment(\.colorScheme, .light)
        case .dark:
            environment(\.colorScheme, .dark)
        case let .sizeCategory(category):
            environment(\.sizeCategory, category)
        case .rightToLeft:
            environment(\.layoutDirection, .rightToLeft)
        case let .locale(locale):
            environment(\.locale, locale)
        }
    }
}
