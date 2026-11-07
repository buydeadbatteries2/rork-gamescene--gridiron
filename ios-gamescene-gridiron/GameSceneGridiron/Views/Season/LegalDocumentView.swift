import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("GameScene: Gridiron")
                        .font(.title2.bold())
                    Text(document.text)
                        .font(.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
                .foregroundStyle(Theme.paperInk)
                .frame(maxWidth: 700, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: "GameScene: Gridiron — \(document.title)\n\n\(document.text)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share \(document.title)")
                }
            }
        }
    }
}
