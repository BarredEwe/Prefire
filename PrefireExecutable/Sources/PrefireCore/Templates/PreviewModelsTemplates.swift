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

    {% if not argument.globalConfiguration %}@inlinable
    {% endif %}@MainActor
    static func createModel<Preview: PreviewProvider>(for preview: Preview.Type, name: String) -> [PreviewModel] {
        var views: [PreviewModel] = []

        for (index, view) in Preview._allPreviews.enumerated() {
            views.append(
                PreviewModel(
                    id: name + "\(index)" + String(describing: self),
                    content: { return view.content },
                    name: name,
                    type: view.layout == .device ? .screen : .component,
                    device: view.device{% if argument.globalConfiguration %},
                    globalConfiguration: {{ argument.globalConfiguration }}.self{% endif %}
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
    {% if not macroModel.hasArguments %}
    struct PreviewWrapper{{ macroModel.componentTestName }}: SwiftUI.View {
    {{ macroModel.properties }}
        var body: some View {
        {{ macroModel.body|indent:8 }}
        }
    }
    {% endif %}
    {% endif %}
    {% endfor %}

    static var previews: [PreviewModel] = {
        var previews: [PreviewModel] = []
        {% for macroModel in argument.previewsMacrosDict %}
        {% if macroModel.hasArguments %}
        for (previewArgumentIndex, previewArgument) in ({{ macroModel.arguments }}).enumerated() {
            let {{ macroModel.argumentPattern }} = previewArgument
            previews.append(
                PreviewModel(
                    id: "{{ macroModel.componentTestName }}-\(previewArgumentIndex)",
                    content: {
                        {{ macroModel.body|indent:24 }}
                    },
                    name: "{{ macroModel.displayName }}-\(previewArgumentIndex + 1)-\(String(describing: previewArgument))",
                    type: {% if macroModel.isScreen == 1 %}.screen{% else %}.component{% endif %}{% if argument.globalConfiguration %},
                    globalConfiguration: {{ argument.globalConfiguration }}.self{% endif %}
                )
            )
        }
        {% else %}
        {% if macroModel.properties %}
        previews.append(PreviewModel(content: { PreviewWrapper{{ macroModel.componentTestName }}() }, name: "{{ macroModel.displayName }}"{% if argument.globalConfiguration %}, globalConfiguration: {{ argument.globalConfiguration }}.self{% endif %}))
        {% else %}
        previews.append(
            PreviewModel(
                content: {
                    {{ macroModel.body|indent:20 }}
                },
                name: "{{ macroModel.displayName }}",
                type: {% if macroModel.isScreen == 1 %}.screen{% else %}.component{% endif %}{% if argument.globalConfiguration %},
                globalConfiguration: {{ argument.globalConfiguration }}.self{% endif %}
            )
        )
        {% endif %}
        {% endif %}
        {% endfor %}
        return previews
    }()
}

{% endif %}
"""#
}
