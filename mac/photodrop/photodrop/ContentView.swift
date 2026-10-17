import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PhotoSpaceViewModel

    var body: some View {
        PhotoSpace(viewModel: viewModel)
            .frame(minWidth: 400, minHeight: 300)
            .background(TransparentWindow())
    }
}

private final class TransparentWindowView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
}

private struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TransparentWindowView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
