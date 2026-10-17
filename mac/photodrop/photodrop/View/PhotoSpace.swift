//
//  PhotoSpace.swift
//  PhotoDrop
//

import SwiftUI
import AppKit

struct PhotoSpace: View {
    @ObservedObject var viewModel: PhotoSpaceViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.clips, id: \.id) { clip in
                    Image(nsImage: clip.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150)
                        .position(x: clip.x, y: clip.y)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(CanvasReference { view in
                viewModel.canvasView = view
            })
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    ConnectionStatus(websocket: viewModel.websocket)
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Settings")
                    .help("Server, display, and screen recording settings")
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
            }
        }
        .alert("PhotoDrop", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }
}

/// Measures the same rectangle that contains the positioned clip images.
private struct CanvasReference: NSViewRepresentable {
    let onResolve: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        onResolve(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        onResolve(nsView)
    }
}

#Preview {
    PhotoSpace(viewModel: PhotoSpaceViewModel())
}

private struct ConnectionStatus: View {
    @ObservedObject var websocket: Websocket

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(websocket.isConnected ? Color.green : Color.orange).frame(width: 7, height: 7)
            Text(websocket.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(websocket.lastError ?? websocket.status)
        .accessibilityElement(children: .combine)
    }
}
