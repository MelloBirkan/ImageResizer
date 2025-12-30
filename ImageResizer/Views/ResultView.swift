import SwiftUI

struct ResultView: View {
    let resultInfo: AppImageInfo?
    let errorMessage: String?

    var body: some View {
        GroupBox("Result") {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else if let info = resultInfo {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text(info.dimensionsString)
                        .monospacedDigit()

                    Text(info.formattedFileSize)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Text(info.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                Text("No result yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }
}
