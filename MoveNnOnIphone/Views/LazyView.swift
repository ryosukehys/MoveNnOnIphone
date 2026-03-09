import SwiftUI

/// TabView は全タブの View を起動時に生成してしまうため、
/// LazyView で包むことで実際にタブが選択されるまで View の body を遅延させる
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: some View {
        build()
    }
}
