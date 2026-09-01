import SwiftUI

/// Decoration applied to every preview, both in generated snapshot tests and in the Playbook.
///
/// Conform a type to it and point `global_configuration:` in `.prefire.yml` at that type
/// to inject a theme, DI container, locale or mocks once instead of in every `#Preview`:
///
///     enum MyPrefireSetup: PrefireGlobalConfiguration {
///         static func wrap(_ view: AnyView) -> AnyView {
///             AnyView(
///                 view
///                     .environment(\.locale, Locale(identifier: "en_US"))
///                     .environmentObject(DesignSystem.dark)
///             )
///         }
///     }
public protocol PrefireGlobalConfiguration {
    /// Wraps preview content before it is rendered.
    ///
    /// Keep the passed view in the returned hierarchy: preferences set inside a preview
    /// (`.snapshot(delay:precision:)`, `.previewUserStory()`) propagate through the wrapper.
    @MainActor static func wrap(_ view: AnyView) -> AnyView
}

public extension PrefireGlobalConfiguration {
    @MainActor static func wrap(_ view: AnyView) -> AnyView { view }
}

/// Applies the global configuration, when one is set.
@MainActor
func prefireWrapped(_ view: AnyView, with configuration: (any PrefireGlobalConfiguration.Type)?) -> AnyView {
    configuration?.wrap(view) ?? view
}
