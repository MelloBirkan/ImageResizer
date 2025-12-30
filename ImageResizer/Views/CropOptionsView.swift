import SwiftUI
import Observation

struct CropOptionsView: View {
    @Bindable var viewModel: ImageResizerViewModel

    var body: some View {
        GroupBox("Crop Options") {
            Form {
                LabeledContent("Output Size") {
                    Text("856 × 836 px")
                        .foregroundStyle(.secondary)
                }

                Picker("Output format", selection: $viewModel.selectedCropFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Crop Position") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("X: \(Int(viewModel.cropRect.x))")
                        Text("Y: \(Int(viewModel.cropRect.y))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
