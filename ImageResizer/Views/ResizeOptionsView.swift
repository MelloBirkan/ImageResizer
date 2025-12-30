import SwiftUI
import Observation

struct ResizeOptionsView: View {
    @Bindable var viewModel: ImageResizerViewModel

    var body: some View {
        GroupBox("Resize Options") {
            Form {
                LabeledContent("Width") {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            text: Binding(
                                get: { viewModel.targetWidth },
                                set: { viewModel.updateWidth($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                        Text("px")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Height") {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            text: Binding(
                                get: { viewModel.targetHeight },
                                set: { viewModel.updateHeight($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disabled(viewModel.lockAspectRatio)

                        Text("px")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(
                    isOn: Binding(
                        get: { viewModel.lockAspectRatio },
                        set: { newValue in
                            if viewModel.lockAspectRatio != newValue {
                                viewModel.toggleAspectRatio()
                            }
                        }
                    )
                ) {
                    Label("Lock aspect ratio", systemImage: "link")
                }

                Picker("Algorithm", selection: $viewModel.selectedAlgorithm) {
                    ForEach(ResizeAlgorithm.allCases, id: \.self) { algorithm in
                        Text(algorithm.displayName).tag(algorithm)
                    }
                }
                .pickerStyle(.menu)

                Picker("Output format", selection: $viewModel.selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}
