//
//  PrefireProvider.swift
//  
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI

/// Protocol, for generating `tests` and `playbook`
///
/// For example:
///
///     struct Text_Previews: PreviewProvider, PrefireProvider {
///          static var previews: some View { ... }
///     }
public protocol PrefireProvider: PreviewProvider {}
