import SwiftUI
import UniformTypeIdentifiers

struct SourcesView: View {
  @Bindable var viewModel: SourcesViewModel
  @State private var showAddSource = false
  @State private var showImporter = false
  @State private var exportDocument: ExportDocument?
  @State private var editingSource: FeedSource?
  @State private var editedName = ""

  var body: some View {
    NavigationStack {
      PrismaScreen {
        List {
          if viewModel.sources.isEmpty {
            Section {
              EmptyStateView(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "sources.empty.title"),
                message: String(localized: "sources.empty.message"),
                actionTitle: String(localized: "sources.add"),
                action: { showAddSource = true }
              )
              .listRowBackground(Color.clear)
            }
          } else {
            Section(String(localized: "sources.yours")) {
              ForEach(viewModel.sources, id: \.id) { source in
                sourceRow(source)
              }
              .onDelete { indexSet in
                indexSet.map { viewModel.sources[$0] }.forEach(viewModel.delete)
              }
            }
          }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle(String(localized: "tab.sources"))
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button(String(localized: "sources.add"), systemImage: "plus") {
              showAddSource = true
            }
            Button(String(localized: "sources.importOPML"), systemImage: "square.and.arrow.down") {
              showImporter = true
            }
            Button(String(localized: "sources.exportOPML"), systemImage: "square.and.arrow.up") {
              exportOPML()
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .sheet(isPresented: $showAddSource) {
        AddSourceView(viewModel: viewModel)
      }
      .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: [.xml, UTType(filenameExtension: "opml") ?? .xml]
      ) { result in
        if case .success(let url) = result,
           let data = try? Data(contentsOf: url) {
          viewModel.importOPML(data: data)
        }
      }
      .sheet(item: $exportDocument) { document in
        ShareSheet(items: [document.url])
      }
      .alert(String(localized: "sources.rename"), isPresented: .init(
        get: { editingSource != nil },
        set: { if !$0 { editingSource = nil } }
      )) {
        TextField(String(localized: "sources.field.name"), text: $editedName)
        Button(String(localized: "action.save")) {
          if let source = editingSource {
            viewModel.rename(source, to: editedName)
          }
          editingSource = nil
        }
        Button(String(localized: "action.cancel"), role: .cancel) {
          editingSource = nil
        }
      }
      .onAppear { viewModel.load() }
    }
  }

  @ViewBuilder
  private func sourceRow(_ source: FeedSource) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      HStack(spacing: PrismaSpacing.sm) {
        SourceIconView(siteURL: source.siteURL, feedURL: source.feedURL, size: 36)
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(source.name)
              .font(PrismaTypography.headline())
            if source.isFavorite {
              Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(PrismaColors.warning)
            }
            if source.isBlocked {
              Image(systemName: "hand.raised.fill")
                .font(.caption)
                .foregroundStyle(PrismaColors.danger)
            }
          }
          Text(source.feedURL)
            .font(PrismaTypography.caption2())
            .foregroundStyle(PrismaColors.textTertiary)
            .lineLimit(1)
        }
        Spacer()
        Toggle("", isOn: Binding(
          get: { source.isEnabled },
          set: { _ in viewModel.toggleEnabled(source) }
        ))
        .labelsHidden()
      }

      HStack {
        Button(String(localized: "sources.favorite")) {
          viewModel.toggleFavorite(source)
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "sources.block")) {
          viewModel.toggleBlocked(source)
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "action.edit")) {
          editingSource = source
          editedName = source.name
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "action.refresh")) {
          Task { await viewModel.refreshSource(source) }
        }
        .font(PrismaTypography.caption())
      }
      .buttonStyle(.borderless)
    }
    .padding(.vertical, PrismaSpacing.xxs)
  }

  private func exportOPML() {
    guard let content = viewModel.exportOPML() else { return }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("prisma-feeds.opml")
    try? content.write(to: url, atomically: true, encoding: .utf8)
    exportDocument = ExportDocument(url: url)
  }
}

struct ExportDocument: Identifiable {
  let id = UUID()
  let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
