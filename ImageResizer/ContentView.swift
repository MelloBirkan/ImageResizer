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
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            DropZoneView(viewModel: viewModel)

            Picker("Mode", selection: $viewModel.operationMode) {
                ForEach(OperationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if viewModel.selectedImageURL != nil {
                switch viewModel.operationMode {
                case .resize:
                    ImagePreviewView(imageInfo: viewModel.originalImageInfo)
                    ResizeOptionsView(viewModel: viewModel)
                case .crop:
                    CropView(viewModel: viewModel)
                    CropOptionsView(viewModel: viewModel)
                }
            }

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
                Task {
                    switch viewModel.operationMode {
                    case .resize:
                        await viewModel.resizeImage()
                    case .crop:
                        await viewModel.cropImage()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(
                        viewModel.isProcessing
                            ? "Processing…"
                            : (viewModel.operationMode == .resize ? "Resize Image" : "Crop Image")
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canProcess || viewModel.isProcessing)
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
