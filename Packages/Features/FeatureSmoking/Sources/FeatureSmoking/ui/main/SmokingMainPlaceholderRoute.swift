// Ported from `feature/smoking/.../ui/main/SmokingMainPlaceholderRoute.kt`.
//
// An empty pushed screen under ``SmokingKey``. Task 10 replaces it with the real main screen and
// deletes this file; until then it only keeps the setup's "Başla" and the More row from landing
// nowhere.

import SalusDesignSystem
import SwiftUI

struct SmokingMainPlaceholderRoute: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(Text(verbatim: SmokingStrings.title))
        // LAST in the chain: the modifier is iOS-only API and every feature package also builds for
        // the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
