extension EmbeddedTemplates {
    public static let previewModels = #"""
// swiftlint:disable all
// swiftformat:disable all

import SwiftUI
import Prefire
{% for import in argument.imports %}
import {{ import }}
{% endfor %}
{% for import in argument.testableImports %}
@testable import {{ import }}
{% endfor %}

public enum PreviewModels {
    @MainActor
    public static var models: [PreviewModel] = {
        var views: [PreviewModel] = []
        #if !PLAYBOOK_DISABLED
        // PreviewProvider
        {% for type in types.types where type.implements.PrefireProvider or type.based.PrefireProvider or type|annotated:"PrefireProvider" %}
        views.append(contentsOf: createModel(for: {{ type.name }}.self, name: "{{ type.name | replace:"_Previews","" | replace:"_Preview","" }}"))
        {% endfor %}
        {% if argument.previewsMacrosDict %}

        // #Preview macro
        views.append(contentsOf: MacroPreviews.previews)
        {% endif %}
        #endif
        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()

    @inlinable
    @MainActor
    static func createModel<Preview: PreviewProvider>(for preview: Preview.Type, name: String) -> [PreviewModel] {
        var views: [PreviewModel] = []

        for (index, view) in Preview._allPreviews.enumerated() {
            views.append(
                PreviewModel(
                    id: name + "\(index)" + String(describing: self),
                    content: { return view.content },
                    name: name,
                    type: view.layout == .device ? .screen : .component,
                    device: view.device
                )
            )
        }

        return views
    }
}
{% if argument.previewsMacrosDict %}

// MARK: - Macros

@MainActor
private struct MacroPreviews {
    {% for macroModel in argument.previewsMacrosDict %}
    {% if macroModel.properties %}
    struct PreviewWrapper{{ macroModel.componentTestName }}: SwiftUI.View {
    {{ macroModel.properties }}
        var body: some View {
        {{ macroModel.body|indent:8 }}
        }
    }
    {% endif %}
    {% endfor %}

    static var previews: [PreviewModel] = [
        {% for macroModel in argument.previewsMacrosDict %}
        {% if macroModel.properties %}
        PreviewModel(content: { PreviewWrapper{{ macroModel.componentTestName }}() }, name: "{{ macroModel.displayName }}"),
        {% else %}
        PreviewModel(content: {
        {{ macroModel.body|indent:8 }}
        }, name: "{{ macroModel.displayName }}"),
        {% endif %}
        {% endfor %}
    ]
}

{% endif %}
"""#
}
