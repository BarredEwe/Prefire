import SwiftUI

/// Environment variation applied to a preview before a snapshot is taken.
///
/// Variants come from the `snapshot_variants` configuration key or from `.snapshotVariants(_:)`.
public enum SnapshotVariant: Hashable, Sendable {
    /// Dynamic Type size, mirroring `ContentSizeCategory`, which older SDKs do not mark as `Sendable`.
    ///
    /// The raw value is the name used in the configuration file and in the snapshot name.
    public enum SizeCategory: String, Hashable, Sendable, CaseIterable {
        case extraSmall = "XS"
        case small = "S"
        case medium = "M"
        case large = "L"
        case extraLarge = "XL"
        case extraExtraLarge = "XXL"
        case extraExtraExtraLarge = "XXXL"
        case accessibilityMedium = "accessibilityM"
        case accessibilityLarge = "accessibilityL"
        case accessibilityExtraLarge = "accessibilityXL"
        case accessibilityExtraExtraLarge = "accessibilityXXL"
        case accessibilityExtraExtraExtraLarge = "accessibilityXXXL"
    }

    /// Baseline appearance. Keeps the snapshot name unsuffixed, so recorded snapshots stay valid.
    case light
    case dark
    case sizeCategory(SizeCategory)
    case rightToLeft
    case locale(Locale)

    /// Suffix appended to the snapshot name. Empty for `.light`.
    public var nameSuffix: String {
        switch self {
        case .light: return ""
        case .dark: return "-dark"
        case let .sizeCategory(category): return "-" + category.rawValue
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
            if let category = SizeCategory(name: name) {
                self = .sizeCategory(category)
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

    private static let localePrefix = "locale_"
}

public extension SnapshotVariant.SizeCategory {
    /// Creates a size category from its short name (`XXXL`) or its SwiftUI case name (`extraExtraExtraLarge`).
    init?(name: String) {
        guard let category = Self(rawValue: name) ?? Self.allCases.first(where: { "\($0)" == name }) else { return nil }
        self = category
    }

    /// The SwiftUI value applied to the environment.
    var contentSizeCategory: ContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        }
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
            environment(\.sizeCategory, category.contentSizeCategory)
        case .rightToLeft:
            environment(\.layoutDirection, .rightToLeft)
        case let .locale(locale):
            environment(\.locale, locale)
        }
    }
}
