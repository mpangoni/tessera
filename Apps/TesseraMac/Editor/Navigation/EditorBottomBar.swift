import SwiftUI

/// Reserves the lower navigation area for future editor-wide commands.
struct EditorBottomBar: View {
    var body: some View {
        HStack { Spacer(minLength: 0) }
            .frame(height: 28)
            .background(.bar)
    }
}
