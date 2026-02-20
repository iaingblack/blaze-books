import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A toolbar button that triggers `.fileImporter` for EPUB selection.
///
/// On success, hands the selected URL to `EPUBImportService` for import.
/// Shows a loading indicator while import is in progress.
struct ImportButton: View {
    @Environment(EPUBImportService.self) private var importService
    @Environment(\.modelContext) private var modelContext
    @State private var showingImporter = false

    var body: some View {
        Button {
            showingImporter = true
        } label: {
            if importService.isImporting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            } else {
                Label("Import", systemImage: "plus")
            }
        }
        .disabled(importService.isImporting)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.epub],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importService.importEPUB(from: url, modelContext: modelContext)
                }
            case .failure(let error):
                importService.importError = "Could not open file picker: \(error.localizedDescription)"
            }
        }
    }
}
