//
//  SafeAreaEnviroment.swift
//  
//
//  Created by Grishutin Maksim Vladimirovich on 25.09.2022.
//

import SwiftUI

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        UIApplication.shared.windows.first?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}

public extension EnvironmentValues {
    /// Отступы, которые используется для определения безопасной области для этого представления.
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
