//
//  ContentView.swift
//  ImageResizer
//
//  Created by Marcello on 30/12/25.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @State private var viewModel = ImageResizerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            DropZoneView(viewModel: viewModel)

            if viewModel.selectedImageURL != nil {
                ImagePreviewView(imageInfo: viewModel.originalImageInfo)
            }

            ResizeOptionsView(viewModel: viewModel)

            HStack(spacing: 8) {
                Text("Save to:")
                    .foregroundStyle(.secondary)

                Text(viewModel.outputURL?.path ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                Button("Choose…") {
                    viewModel.selectOutputLocation()
                }
            }

            Button {
                Task { await viewModel.resizeImage() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isProcessing ? "Resizing…" : "Resize Image")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canResize || viewModel.isProcessing)
            .controlSize(.large)

            ResultView(resultInfo: viewModel.resultInfo, errorMessage: viewModel.errorMessage)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 700)
    }
}

#Preview {
    ContentView()
}
