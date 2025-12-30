import SwiftUI

struct ImagePreviewView: View {
    let imageInfo: AppImageInfo?

    var body: some View {
        GroupBox("Original") {
            if let info = imageInfo {
                VStack(alignment: .leading, spacing: 6) {
                    Text(info.dimensionsString)
                        .font(.body)
                        .monospacedDigit()

                    HStack(spacing: 8) {
                        Text(info.format.uppercased())
                        Text("|")
                            .foregroundStyle(.secondary)
                        Text(info.formattedFileSize)
                            .monospacedDigit()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                Text("No image selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }
}
