import SwiftUI

struct MyLibraryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case allSaved = "All Saved"
        case myList = "My List"
        case watching = "Watching"
        case watched = "Watched"
        case favorites = "Favorites"
        var id: String { rawValue }
    }

    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedTab: Tab = .allSaved
    @State private var searchText = ""
    @State private var minimumRating = 0
    @State private var selectedCollectionID: UUID?
    @State private var isManagingCollections = false
    @FocusState private var isSearchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 250, maximum: 330), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if filteredItems.isEmpty {
                    EmptyStateView(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 380)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(filteredItems) { item in
                            LibraryMovieCard(
                                item: item,
                                collections: libraryViewModel.collections,
                                onOpen: { router.showDetails(for: libraryViewModel.asMovie(item)) },
                                onStatus: { libraryViewModel.setStatus($0, for: libraryViewModel.asMovie(item)) },
                                onFavorite: { libraryViewModel.toggleFavorite(libraryViewModel.asMovie(item)) },
                                onCollection: { collection, included in
                                    libraryViewModel.setMovie(libraryViewModel.asMovie(item), in: collection, included: included)
                                },
                                onRemove: { libraryViewModel.remove(libraryViewModel.asMovie(item)) }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear { libraryViewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .focusLibrarySearch)) { _ in isSearchFocused = true }
        .sheet(isPresented: $isManagingCollections) {
            CollectionManagerView(libraryViewModel: libraryViewModel)
        }
        .alert("Library Error", isPresented: Binding(
            get: { libraryViewModel.persistenceErrorMessage != nil },
            set: { if !$0 { libraryViewModel.persistenceErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { libraryViewModel.persistenceErrorMessage = nil }
        } message: {
            Text(libraryViewModel.persistenceErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("My Library", languageCode: settings.languageCode))
                .font(Theme.Font.title(28))

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { Text(L10n.string($0.rawValue, languageCode: settings.languageCode)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 450)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                    TextField("Search your library", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 320)

                Picker("Rating", selection: $minimumRating) {
                    Text("Any rating").tag(0)
                    ForEach([5, 6, 7, 8, 9, 10], id: \.self) { Text("\($0)+ personal").tag($0) }
                }
                .frame(width: 150)

                Picker("Collection", selection: $selectedCollectionID) {
                    Text("All collections").tag(UUID?.none)
                    ForEach(libraryViewModel.collections) { Text($0.name).tag(Optional($0.id)) }
                }
                .frame(width: 170)

                Button("Manage Collections") { isManagingCollections = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }

    private var filteredItems: [LibraryItem] {
        libraryViewModel.items.filter { item in
            let tabMatches: Bool = switch selectedTab {
            case .allSaved: true
            case .myList: item.status == .wantToWatch
            case .watching: item.status == .watching
            case .watched: item.status == .watched
            case .favorites: item.isFavorite
            }
            let textMatches = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || item.title.localizedStandardContains(searchText)
            let ratingMatches = minimumRating == 0 || (item.personalRating ?? 0) >= minimumRating
            let collectionMatches = selectedCollectionID == nil
                || libraryViewModel.collections.first(where: { $0.id == selectedCollectionID })?.contains(movieID: item.movieID) == true
            return tabMatches && textMatches && ratingMatches && collectionMatches
        }
    }

    private var emptyIcon: String { switch selectedTab { case .allSaved: "tray.full"; case .myList: "bookmark"; case .watching: "play.circle"; case .watched: "checkmark.circle"; case .favorites: "heart" } }
    private var emptyTitle: String { searchText.isEmpty ? "Nothing saved here yet" : "No matching titles" }
    private var emptyMessage: String { searchText.isEmpty ? "Use Movie Detail or a right-click menu to add and organize titles." : "Try changing your library search or filters." }
}

private struct LibraryMovieCard: View {
    let item: LibraryItem
    let collections: [LibraryCollection]
    let onOpen: () -> Void
    let onStatus: (LibraryStatus) -> Void
    let onFavorite: () -> Void
    let onCollection: (LibraryCollection, Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: Movie(libraryItem: item).posterURL) { phase in
                if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) }
                else { Color.white.opacity(0.06).overlay { Image(systemName: "film").foregroundStyle(.secondary) } }
            }
            .frame(width: 76, height: 112).clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(String(format: "%.1f", item.voteAverage)).foregroundStyle(.secondary)
                    if let rating = item.personalRating {
                        Text("• Mine \(rating)/10").foregroundStyle(Theme.accent)
                    }
                }.font(.system(size: 12))
                Label(item.status.title, systemImage: statusIcon).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                if item.status == .watching {
                    ProgressView(value: item.watchProgress)
                    Text("\(Int(item.watchProgress * 100))% watched").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10).frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(Color.white.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08)) }
        .contentShape(Rectangle()).onTapGesture(perform: onOpen)
        .contextMenu { libraryMenu }
    }

    @ViewBuilder private var libraryMenu: some View {
        Button("Open", action: onOpen)
        Divider()
        ForEach([LibraryStatus.wantToWatch, .watching, .watched]) { status in
            Button { onStatus(status) } label: { Label(status.title, systemImage: item.status == status ? "checkmark" : statusIcon(for: status)) }
        }
        Button(item.isFavorite ? "Unfavorite" : "Favorite", action: onFavorite)
        if !collections.isEmpty {
            Menu("Add to Collection") {
                ForEach(collections) { collection in
                    let included = collection.contains(movieID: item.movieID)
                    Button { onCollection(collection, !included) } label: { Label(collection.name, systemImage: included ? "checkmark" : "folder") }
                }
            }
        }
        Divider()
        Button("Remove from Library", role: .destructive, action: onRemove)
    }

    private var statusIcon: String { statusIcon(for: item.status) }
    private func statusIcon(for status: LibraryStatus) -> String { switch status { case .none: "tray"; case .wantToWatch: "bookmark.fill"; case .watching: "play.circle.fill"; case .watched: "checkmark.circle.fill" } }
}

private struct CollectionManagerView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var renameValues: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Custom Collections").font(Theme.Font.title(22)); Spacer(); Button("Done") { dismiss() } }
            HStack {
                TextField("Collection name", text: $newName)
                Button("Create") { libraryViewModel.createCollection(named: newName); newName = "" }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List {
                ForEach(libraryViewModel.collections) { collection in
                    HStack {
                        TextField(collection.name, text: Binding(get: { renameValues[collection.id] ?? collection.name }, set: { renameValues[collection.id] = $0 }))
                        Text("\(collection.movieIDs.count) items").foregroundStyle(.secondary)
                        Button("Rename") { libraryViewModel.rename(collection, to: renameValues[collection.id] ?? collection.name) }
                        Button("Delete", role: .destructive) { libraryViewModel.delete(collection) }
                    }
                }
            }
        }
        .padding(24).frame(minWidth: 620, minHeight: 380)
    }
}
