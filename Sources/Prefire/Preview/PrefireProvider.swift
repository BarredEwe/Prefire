import SwiftUI

/// Protocol, for generating `tests` and `playbook`
///
/// For example:
///
///     struct Text_Previews: PreviewProvider, PrefireProvider {
///          static var previews: some View { ... }
///     }
public protocol PrefireProvider: PreviewProvider {}
