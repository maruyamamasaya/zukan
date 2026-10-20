import SwiftUI
import LibraryOrganizationUI
import LibraryOrganization
import Charts

private struct CloudReading: Identifiable {
    let id = UUID()
    let diagram: CloudDiagram
    let files: [CloudFile]
    let initial: CloudFile
    let document: OpenedDocument
    let offline: Bool
}

@MainActor
struct CloudLibraryView: View {
    @Environment(\.bookshelfTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: CloudLibraryStore
    @State private var drawerPresented = false
    @Environment(\.libraryDestination) private var libraryDestination
    private var phoneUI: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    @State private var selectedShelf = "all"
    @State private var selecting = false
    @State private var selectedDocuments = Set<String>()
    @State private var folderName = ""
    @State private var showFolderDialog = false
    @State private var folderCreationIDs = Set<String>()
    @State private var folderCreationShelf = LibraryShelf.presentation
    @State private var renamingFolder: UUID?
    @State private var moving = false
    @State private var syncLab: SyncLabSession?
    @State private var syncSetup = false
    private let onSyncLogin: (() async throws -> AuthenticatedSyncConnection)?
    @State private var selectedGroup = "すべて"
    @State private var selectedTag = ""
    @State private var classificationDraft: CloudDiagram?
    @State private var query = ""
    @State private var searchScope = "すべて"
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool
    @State private var reading: CloudReading?
    @State private var opening = false
    @State private var showCapacity = false
    @State private var showClearDocuments = false
    @State private var trashCandidates: [CloudDiagram] = []
    @State private var confirmTrash = false
    @State private var deletionPlans: [LibraryDeletionPlan] = []
    @State private var confirmDeletion = false
    private var showTrash: Bool { selectedShelf == "trash" }
    private let costFiles: CloudFileStore
    private let api: any CloudLibraryAPI
    let onSettings: (() -> Void)?
    let onLogout: (() -> Void)?
    let onReauthenticate: (() -> Void)?
    let production: Bool
    let kind: CloudLibraryKind
    init(files: CloudFileStore, kind: CloudLibraryKind = .presentations, api: any CloudLibraryAPI = MockCloudAPI(), production: Bool = false, onSettings: (() -> Void)? = nil, onLogout: (() -> Void)? = nil, onReauthenticate: (() -> Void)? = nil, syncConnection: AuthenticatedSyncConnection? = nil, onSyncLogin: (() async throws -> AuthenticatedSyncConnection)? = nil) {
        self.onSyncLogin = onSyncLogin
        self.costFiles = files
        self.kind = kind
        self.api = api
        self.production = production; self.onSettings = onSettings; self.onLogout = onLogout
        self.onReauthenticate = onReauthenticate
        #if targetEnvironment(simulator)
        let testSync = !production && ProcessInfo.processInfo.arguments.contains("--test-library-sync")
        #else
        let testSync = false
        #endif
        _store = StateObject(wrappedValue: CloudLibraryStore(api: api, files: files, enableTestSync: testSync, syncConnection: syncConnection))
    }
    private var savedDiagrams: [CloudDiagram] {
        var seen = Set<String>()
        return store.saved.filter { $0.file.format != .svg }.map(\.diagram).filter { seen.insert("\($0.id)-\($0.version)").inserted }
    }
    private var diagrams: [CloudDiagram] {
        var seen = Set<String>()
        let candidates = showTrash ? store.trashedDiagrams :
            store.items.map { store.preferredLocalVersion($0) } + (store.localDiagrams + savedDiagrams).sorted { $0.version > $1.version } + store.collections.flatMap(\.members) + store.hiddenDiagrams
        return candidates.filter {
            (showTrash || store.lifecycle.status($0.id) == .active) && (showTrash || !phoneUI || kind.contains($0)) && !$0.formats.allSatisfy { $0 == .svg } && matchesSearch($0) && (showTrash || matchesClassification($0) && matchesFolder($0))
        }.filter { seen.insert($0.id.lowercased()).inserted }
    }
    private var libraryShelf: LibraryShelf {
        if !phoneUI, let id = UUID(uuidString: selectedShelf),
           store.integratedOrganization.descendants(of: LibraryShelf.illustration.rootID).contains(id) { return .illustration }
        return phoneUI && kind == .illustrations ? .illustration : .presentation
    }
    private var folders: [OrganizationFolder] {
        phoneUI ? store.integratedOrganization.folders(in: libraryShelf) : store.integratedOrganization.orderedFolders.filter { !LibraryShelf.isRoot($0.id) }
    }
    private var selectedMoveShelf: LibraryShelf? {
        let kinds = Set(diagrams.filter { selectedDocuments.contains($0.id.lowercased()) }.map { CloudLibraryKind.illustrations.contains($0) ? LibraryShelf.illustration.rawValue : LibraryShelf.presentation.rawValue })
        return kinds.count == 1 ? kinds.first.flatMap(LibraryShelf.init(rawValue:)) : nil
    }
    private var destinationFolders: [OrganizationFolder] {
        guard let shelf = selectedMoveShelf else { return [] }
        return store.integratedOrganization.folders(in:shelf)
    }
    private var looseDiagrams: [CloudDiagram] {
        guard let id = UUID(uuidString: selectedShelf), let collection = store.collections.first(where: { $0.id == id }) else { return diagrams }
        let ranks = Dictionary(collection.members.enumerated().map { ($0.element.id.lowercased(), $0.offset) }, uniquingKeysWith: min)
        return diagrams.sorted { (ranks[$0.id.lowercased()] ?? Int.max) < (ranks[$1.id.lowercased()] ?? Int.max) }
    }
    private var apiScope: String { searchScope == "タイトル" ? "title" : searchScope == "タグ" ? "tags" : "all" }
    private var searchRequest: String { "\(showTrash)" }
    private func refresh(more: Bool = false) async {
        if showTrash {
            do { try await store.refreshLifecycle() } catch { store.errorMessage = "ゴミ箱を取得できませんでした。接続状態を確認してください。" }; return
        }
        await store.refresh(query: "", scope: "all", more: more) }
    var body: some View {
        AnyView(GeometryReader { geometry in
        let landscapePhone = UIDevice.current.userInterfaceIdiom == .phone && geometry.size.width > geometry.size.height
        let landscapeColumns = dynamicTypeSize.isAccessibilitySize || geometry.size.width - (phoneUI ? 160 : 0) < 540 ? 2 : 3
        NavigationStack {
            libraryContent(landscapePhone: landscapePhone, columns: landscapeColumns)
            .navigationTitle(phoneUI ? kind.title : "本棚")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch.toggle()
                        searchFocused = showSearch
                        if !showSearch { query = ""; searchScope = "すべて" }
                    } label: { Image(systemName: showSearch ? "xmark" : "magnifyingglass") }
                    .accessibilityLabel(showSearch ? "検索を閉じる" : "資料を検索")
                }
                ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    libraryActions
                } label: { Label("その他", systemImage: "ellipsis") }.disabled(opening || store.busy)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay { if opening { ProgressView("資料を開いています").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .refreshable { await store.reloadSaved(); await refresh() }
            .task { await store.reloadSaved() }
            .onAppear { Task { await store.reloadSaved() } }
            .task(id: searchRequest) {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                await refresh()
            }
            .onChange(of: selectedShelf) { _, _ in selectedDocuments.removeAll() }
            .onChange(of: diagrams.map { $0.id.lowercased() }) { _, ids in selectedDocuments.formIntersection(Set(ids)) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.reloadSaved(); await refresh() } }
            }
        }
        .alert("\(trashCandidates.count)件を共通ゴミ箱へ移しますか？", isPresented: $confirmTrash) {
            Button("キャンセル", role: .cancel) {}
            Button("ゴミ箱へ移動", role: .destructive) { Task { let done = await store.setTrashed(trashCandidates, trashed: true); selectedDocuments.subtract(done) } }
        } message: { Text("スマホとMacの通常一覧から外れます。完全削除するまで復元できます。") }
        .alert("\(deletionPlans.count)件を完全削除しますか？", isPresented: $confirmDeletion) {
            Button("キャンセル", role: .cancel) { deletionPlans = [] }
            Button("完全削除する", role: .destructive) {
                let confirmed = deletionPlans; deletionPlans = []
                Task { let done = await store.permanentlyDelete(confirmed); selectedDocuments.subtract(done) }
            }
        } message: {
            Text("S3の全版・成果物容量\(ByteCountFormatter.string(fromByteCount: deletionPlans.reduce(Int64(0)) { $0 + $1.sizeBytes }, countStyle: .file))（関連ファイルを含む計\(deletionPlans.reduce(0) { $0 + $1.objectCount })ファイル）と、スマホ・Macのアプリ内コピーを削除します。復元できません。オフライン端末のコピーは次の接続時に削除されます。登録フォルダの制作原本は残ります。")
        }
        .alert(renamingFolder == nil ? "フォルダを作成" : "名前を変更", isPresented: $showFolderDialog) {
            TextField("フォルダ名", text: $folderName)
            Button("保存") { Task {
                if let id = renamingFolder { _ = await store.renameFolder(id, name: folderName) }
                else {
                    let targetShelf = folderCreationIDs.isEmpty ? libraryShelf : folderCreationShelf
                    let parent = UUID(uuidString:selectedShelf).flatMap { store.integratedOrganization.descendants(of:targetShelf.rootID).contains($0) ? $0 : nil }
                    if await store.createFolder(folderName,parentID:parent,shelf:targetShelf,documentIDs:folderCreationIDs), !folderCreationIDs.isEmpty {
                        selectedDocuments.removeAll();selecting = false
                    }
                }
                folderName = "";folderCreationIDs = []
            } }
            Button("キャンセル", role: .cancel) { folderCreationIDs = [] }
        } message: { Text(folderCreationIDs.isEmpty ? "選択中の種類の中に分類フォルダを作成します。" : "選択した資料を新しいフォルダへ移動します。") }
        .confirmationDialog("端末の資料をすべて削除しますか？", isPresented: $showClearDocuments, titleVisibility: .visible) {
            Button("端末の資料を削除", role: .destructive) { Task { await store.clearLocalDocuments() } }
        } message: {
            Text("保存済み資料と一時キャッシュを両ライブラリから削除します。S3の正本、ローカル資料タブのファイル、フォルダ・グループ・タグの設定は残ります。再取得には通信が必要です。")
        }
        .sheet(item: $syncLab) { SyncLabView(session: $0) }
        .sheet(isPresented: $syncSetup) { SyncSetupView(available: production && onSyncLogin != nil && Bundle.main.object(forInfoDictionaryKey: "OrganizationSyncEnabled") as? Bool == true) {
            guard let onSyncLogin else { throw OrganizationConnectionError.authentication }
            return try await store.connectOrganizationSync(onSyncLogin())
        } }
        .sheet(item: $classificationDraft) { diagram in
            LibraryClassificationEditor(diagram: diagram, store: store)
        }
        .sheet(isPresented: $showCapacity) { CloudCapacityView(api: api, production: production, files: costFiles) }

        .fullScreenCover(item: $reading) { CloudReader(reading: $0, store: store, onReauthenticate: onReauthenticate) }
        .alert("操作を完了できません", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            if store.errorMessage == CloudError.authentication.errorDescription, let onReauthenticate {
                Button("ログインし直す") { store.errorMessage = nil; onReauthenticate() }
            }
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        })
    }
    private func libraryContent(landscapePhone: Bool, columns: Int) -> some View {
            VStack(spacing: 0) {
                if phoneUI { phoneShelfBar } else { tabletShelfBar }
                HStack(spacing: 0) {
                phoneFolderRail.frame(width: dynamicTypeSize.isAccessibilitySize ? 230 : phoneUI ? 150 : 210)
                VStack(spacing: 0) {
                if !phoneUI { classificationControls }
                if showSearch {
                    if phoneUI { phoneSearchBar } else { searchControls }
                }
                if selecting { selectionBar }
                libraryGrid(landscapePhone: landscapePhone, columns: columns)

                }
                }
            }.background(theme.canvas)
    }
    private func libraryGrid(landscapePhone: Bool, columns: Int) -> some View {
                ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if showTrash {
                        Button("ゴミ箱を空にする…", systemImage: "trash.slash", role: .destructive) {
                            Task {
                                do {
                                    try await store.refreshLifecycle()
                                    let ids = Set(store.trashedDiagrams.map { $0.id.lowercased() })
                                    if let plans = await store.prepareDeletion(ids), !plans.isEmpty {
                                        deletionPlans = plans; confirmDeletion = true
                                    }
                                } catch { store.errorMessage = "ゴミ箱を確認できませんでした。接続状態を確認してください。" }
                            }
                        }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                        .disabled(store.busy || !store.lifecycleEnabled || store.trashedDiagrams.isEmpty)
                        Text(store.lifecycleEnabled ? "iPhone・Mac共通のゴミ箱。完全削除するまで復元できます。" : "共通ゴミ箱を利用できません。接続状態を確認してください。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: landscapePhone
                              ? Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns)
                              : [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: landscapePhone ? 12 : 20) {
                        ForEach(looseDiagrams, id: \.selfKey) { diagram in
                            diagramCard(diagram, landscapePhone: landscapePhone)
                        }
                    }
                    if looseDiagrams.isEmpty && !store.busy {
                        ContentUnavailableView(showTrash ? "ゴミ箱は空です" : "資料が見つかりません",
                                               systemImage: showTrash ? "trash" : "magnifyingglass",
                                               description: Text(query.isEmpty ? "下に引いて一覧を更新してください。保存した資料は通信なしでも表示されます。" : "グループ・タグや検索条件を変えてみてください。"))
                    }
                    if !showTrash, let cursor = store.nextCursor {
                        if store.paginationFailed {
                            Button("読み込みを再試行") { Task { await store.loadNextPage(cursor: cursor) } }
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding()
                                .task(id: cursor) { await store.loadNextPage(cursor: cursor) }
                        }
                    }
                }.padding(12)
            }
    }
    private var selectionBar: some View {

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            Text("\(selectedDocuments.count)件を選択")
                            Button("すべて選択") { selectedDocuments = Set(diagrams.map { $0.id.lowercased() }) }
                            if showTrash {
                                Button("復元") { mutateTrash(trashed: false) }
                                    .disabled(selectedDocuments.isEmpty || store.busy || !store.lifecycleEnabled || selectedDocuments.contains { store.lifecycle.status($0) == .deleting })
                                Button("完全削除…", role: .destructive) {
                                    Task { if let plans = await store.prepareDeletion(selectedDocuments) { deletionPlans = plans; confirmDeletion = true } }
                                }.disabled(selectedDocuments.isEmpty || store.busy || !store.lifecycleEnabled)
                            } else {
                                Menu("フォルダへ移動") {
                                    Button("新しいフォルダへ移動…") {
                                        if let shelf = selectedMoveShelf { folderCreationShelf = shelf;folderCreationIDs = selectedDocuments;renamingFolder = nil;folderName = "";showFolderDialog = true }
                                    }.disabled(selectedMoveShelf == nil)
                                    Button("未整理") { moveSelection(to: nil) }
                                    ForEach(destinationFolders) { folder in Button(store.folderPath(folder.id)) { moveSelection(to: folder.id) } }
                                    if selectedMoveShelf == nil { Text("プレゼンと図解は種類ごとに選択してください") }
                                }.disabled(selectedDocuments.isEmpty || moving)
                                Button("ゴミ箱へ移動", role: .destructive) {
                                    trashCandidates = diagrams.filter { selectedDocuments.contains($0.id.lowercased()) }; confirmTrash = true
                                }.disabled(selectedDocuments.isEmpty || store.busy || !store.lifecycleEnabled)
                            }
                            Button("完了") { selecting = false; selectedDocuments.removeAll() }
                        }.font(.subheadline).padding(8)
                    }

    }
    private var shelfTitle: String {
        if showTrash { return "ゴミ箱" }
        if selectedShelf == "unfiled" { return "未整理" }
        if let id = UUID(uuidString: selectedShelf) { return store.folderPath(id) }
        return "すべての資料"
    }
    private var tabletShelfBar: some View {
        HStack(spacing: 12) {
            Text(shelfTitle).font(.headline).lineLimit(1)
            Text("\(diagrams.count)件").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button { showSearch.toggle(); searchFocused = showSearch } label: { Label("検索", systemImage: "magnifyingglass") }
            Button(selecting ? "完了" : "選択") { selecting.toggle(); selectedDocuments.removeAll() }
            Menu { BookshelfThemePicker(); libraryActions } label: { Label("管理", systemImage: "ellipsis") }
        }.padding(.horizontal, 20).frame(minHeight: 52)
        .background(BookshelfMaterial())
        .overlay(alignment: .bottom) { Divider() }
    }
    private var phoneShelfBar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(CloudLibraryKind.allCases, id: \.rawValue) { value in
                    Button(value.title) { libraryDestination.wrappedValue = value.rawValue }
                }
            } label: { Label("本棚", systemImage: "books.vertical").font(.subheadline.weight(.semibold)) }
            .frame(width: 130, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text([kind.title, selectedGroup == "すべて" ? "" : selectedGroup, selectedTag].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(shelfTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text("\(diagrams.count)件").font(.caption).foregroundStyle(.secondary)
            Button { showSearch.toggle(); searchFocused = showSearch } label: { Image(systemName: query.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill").frame(width: 44, height: 44) }
                .accessibilityLabel("資料を検索")
            Button(selecting ? "完了" : "選択") { selecting.toggle(); selectedDocuments.removeAll() }
                .frame(minWidth: 44, minHeight: 44)
            Menu {
                BookshelfThemePicker()
                Section("絞り込み") {
                    Picker("グループ", selection: $selectedGroup) {
                        Text("すべて").tag("すべて")
                        ForEach(LibraryGroup.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("タグ", selection: $selectedTag) {
                        Text("すべてのタグ").tag("")
                        ForEach(availableTags, id: \.self) { Text($0).tag($0) }
                    }
                    Button("絞り込みを解除") { selectedGroup = "すべて"; selectedTag = ""; query = "" }
                }
            } label: { Image(systemName: selectedGroup != "すべて" || !selectedTag.isEmpty ? "line.3.horizontal.decrease.circle.fill" : "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("絞り込み")
        }.padding(.horizontal, 12).background(BookshelfMaterial())
        .overlay(alignment: .bottom) { Divider() }
    }
    private var phoneSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("取得済み資料を検索", text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searchFocused).submitLabel(.search)
                .onSubmit { searchFocused = false }
            Menu {
                Picker("検索対象", selection: $searchScope) {
                    ForEach(["すべて", "タイトル", "タグ"], id: \.self) { Text($0).tag($0) }
                }
            } label: { Text(searchScope).font(.caption).frame(minWidth: 44, minHeight: 44) }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("検索をクリア")
            }
            Button("閉じる") { showSearch = false; searchFocused = false }.frame(minHeight: 44)
        }.font(.subheadline).padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    private func shelfRow(_ title: String, symbol: String, value: String) -> some View {
        Button {
            selectedShelf = value; selectedDocuments.removeAll()
        } label: {
            Label(title, systemImage: symbol).font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 8)
                .background(selectedShelf == value ? theme.accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selectedShelf == value ? theme.accent.opacity(0.35) : .clear))
        }.buttonStyle(.plain).accessibilityAddTraits(selectedShelf == value ? .isSelected : [])
    }
    private func folderRow(_ folder:OrganizationFolder) -> some View {
        shelfRow(folder.name,symbol:"folder",value:folder.id.uuidString)
            .padding(.leading,CGFloat(max(0,store.folderPath(folder.id).components(separatedBy:" / ").count-1))*12)
            .accessibilityLabel(store.folderPath(folder.id))
    }
    private var phoneFolderRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if !phoneUI {
                    Label("本棚", systemImage: "books.vertical").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                shelfRow("すべて", symbol: "books.vertical", value: "all")
                shelfRow("未整理", symbol: "tray", value: "unfiled")
                Text(phoneUI ? "フォルダ" : "種類と分類フォルダ").font(.caption).foregroundStyle(.secondary).padding(.top, 14).padding(.horizontal, 8)
                if phoneUI {
                    ForEach(folders) { folder in folderRow(folder) }
                } else {
                    ForEach([LibraryShelf.presentation, .illustration],id: \.rawValue) { shelf in
                        shelfRow(shelf.title + "（すべて）",symbol:"books.vertical",value:shelf.rootID.uuidString)
                        ForEach(store.integratedOrganization.folders(in:shelf)) { folder in folderRow(folder).padding(.leading,12) }
                    }
                }
                Divider().padding(.vertical, 8)
                shelfRow("ゴミ箱", symbol: "trash", value: "trash")
                Menu {
                    Button("フォルダを作成", systemImage: "folder.badge.plus") { folderCreationIDs = [];renamingFolder = nil; folderName = ""; showFolderDialog = true }
                    if let id = UUID(uuidString: selectedShelf), !LibraryShelf.isRoot(id) {
                        Button("名前を変更", systemImage: "pencil") { renamingFolder = id; folderName = folders.first(where: { $0.id == id })?.name ?? ""; showFolderDialog = true }
                        Button("フォルダを解除", systemImage: "folder.badge.minus") {
                            Task { if await store.removeFolder(id, scoped: true) { selectedShelf = "all" } }
                        }
                    }
                    Divider()
                    libraryActions
                } label: { Label("本棚を管理", systemImage: "slider.horizontal.3").font(.caption).frame(minHeight: 44) }
            }.padding(8)
        }.background(BookshelfMaterial())
        .overlay(alignment: .trailing) { Divider() }
    }
    private func diagramCard(_ diagram: CloudDiagram, landscapePhone: Bool) -> some View {
                            Button {
                                if selecting {
                                    let id = diagram.id.lowercased()
                                    if !selectedDocuments.insert(id).inserted { selectedDocuments.remove(id) }
                                } else if !showTrash { open(diagram) }
                            } label: {
                                CloudCover(diagram: diagram, store: store, offline: isSavedOnly(diagram), coverFocused: landscapePhone, suppressThumbnail: showTrash)
                            }
                            .buttonStyle(.plain).disabled(opening || store.busy)
                            .accessibilityLabel(selecting ? "\(diagram.title)を選択" : showTrash ? diagram.title : "\(diagram.title)を読む")
                            .accessibilityValue(selecting && selectedDocuments.contains(diagram.id.lowercased()) ? "選択中" : "未選択")
                            .overlay(alignment: .topLeading) {
                                if selecting { Image(systemName: selectedDocuments.contains(diagram.id.lowercased()) ? "checkmark.circle.fill" : "circle").font(.title).padding(8).background(.regularMaterial, in: Circle()).padding(4).allowsHitTesting(false) }
                            }
                            .contextMenu {
                                if showTrash {
                                    Button("復元", systemImage: "arrow.uturn.backward") { Task { _ = await store.setTrashed([diagram], trashed: false) } }.disabled(!store.lifecycleEnabled || store.lifecycle.status(diagram.id) == .deleting)
                                } else {
                                Button("ゴミ箱へ移動", systemImage: "trash", role: .destructive) { trashCandidates = [diagram]; confirmTrash = true }.disabled(!store.lifecycleEnabled)
                                Button("グループ・タグを編集", systemImage: "tag") { classificationDraft = diagram }

                            }
                                }
                            .overlay(alignment: .bottomTrailing) {
                                if showTrash && store.lifecycle.status(diagram.id) == .deleting {
                                    Text("削除中・再試行できます").font(.caption).padding(6).background(.regularMaterial, in: Capsule())
                                }
                                if !selecting, !showTrash, let update = store.availableUpdate(diagram) {
                                    Button { open(update, updating: true) } label: {
                                        Label("更新あり", systemImage: "arrow.down.circle")
                                            .font(.caption).padding(8).background(.regularMaterial, in: Capsule())
                                    }.buttonStyle(.plain).padding(8).disabled(opening || store.busy)
                                    .accessibilityLabel("\(diagram.title)を最新版に更新")
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if !selecting, !showTrash || !store.hiddenDiagrams.isEmpty {
                                    Menu {
                                        Button("ゴミ箱へ移動", systemImage: "trash", role: .destructive) { trashCandidates = [diagram]; confirmTrash = true }.disabled(!store.lifecycleEnabled)
                                        Button("グループ・タグを編集", systemImage: "tag") { classificationDraft = diagram }
                                    } label: { Image(systemName: "ellipsis.circle.fill").font(.title2).padding(8).background(.regularMaterial, in: Circle()) }
                                    .padding(8).disabled(opening || store.busy).accessibilityLabel("\(diagram.title)の操作")
                                }
                            }
    }
    private func mutateTrash(trashed: Bool) {
        let targets = diagrams.filter { selectedDocuments.contains($0.id.lowercased()) }
        Task { let done = await store.setTrashed(targets, trashed: trashed); selectedDocuments.subtract(done) }
    }
    private func matchesFolder(_ diagram: CloudDiagram) -> Bool {
        let organization = store.integratedOrganization
        if selectedShelf == "unfiled" { return !organization.isFiled(diagram.id.lowercased(), memberID: { $0.id }) }
        if let id = UUID(uuidString: selectedShelf) {
            if LibraryShelf.isRoot(id) { return (id == LibraryShelf.illustration.rootID) == CloudLibraryKind.illustrations.contains(diagram) }
            return organization.containsDocument(diagram.id.lowercased(), in: id, memberID: { $0.id })
        }
        return true
    }
    private func moveSelection(to folderID: UUID?) {
        let ids = selectedDocuments; moving = true
        Task {
            if await store.moveDocuments(ids, to: folderID, scoped: true) { selectedDocuments.removeAll(); selecting = false }
            moving = false
        }
    }
    private var availableTags: [String] {
        let candidates = store.items + store.localDiagrams + savedDiagrams + store.hiddenDiagrams
        return LibraryClassification.normalizedTags(candidates.filter {
            !phoneUI || kind.contains($0)
        }.flatMap { store.classification($0).tags }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private func matchesClassification(_ diagram: CloudDiagram) -> Bool {
        let value = store.classification(diagram)
        return (selectedGroup == "すべて" || value.group.rawValue == selectedGroup)
            && (selectedTag.isEmpty || value.tags.contains { $0.localizedCaseInsensitiveCompare(selectedTag) == .orderedSame })
    }
    @ViewBuilder private var libraryActions: some View {
                    Button("整理情報の同期", systemImage: "icloud") { syncSetup = true }
                    Menu("詳細") { Button("同期の検証", systemImage: "arrow.triangle.2.circlepath") { Task { syncLab = await store.makeSyncLab() } } }
                    Button("S3保存容量と月額費用", systemImage: "externaldrive") { showCapacity = true }
                    if let onSettings { Button("接続設定", systemImage: "gear") { onSettings() } }
                    if let onReauthenticate { Button("ログインし直す", systemImage: "person.crop.circle.badge.checkmark", action: onReauthenticate) }
                    if let onLogout { Button("ログアウト", systemImage: "rectangle.portrait.and.arrow.right") { onLogout() } }
                    Button("一覧を更新", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    Button("一時キャッシュを削除", systemImage: "trash") { Task { await store.clearCache() } }
                    Button("端末の資料をすべて削除", systemImage: "trash", role: .destructive) { showClearDocuments = true }
    }
    private var classificationControls: some View {
        VStack(spacing: 8) {
            Picker("グループ", selection: $selectedGroup) {
                Text("すべて").tag("すべて")
                ForEach(LibraryGroup.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
            }.pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    tagButton("すべてのタグ", value: "")
                    ForEach(availableTags, id: \.self) { tagButton($0, value: $0) }
                    if !selectedTag.isEmpty && !availableTags.contains(selectedTag) { tagButton(selectedTag, value: selectedTag) }
                }
            }
        }.padding(.horizontal).padding(.vertical, 8)
    }
    private func tagButton(_ title: String, value: String) -> some View {
        Button { selectedTag = value } label: {
            Text(title).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8)
                .background(selectedTag == value ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selectedTag == value ? .isSelected : [])
    }
    private var searchControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("タイトル・タグを検索", text: $query)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel(phoneUI ? "\(kind.title)を検索" : "資料を検索")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .accessibilityLabel("検索をクリア")
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            Picker("検索対象", selection: $searchScope) {
                ForEach(["すべて", "タイトル", "タグ"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    private func matchesSearch(_ diagram: CloudDiagram) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let titleMatches = diagram.title.localizedCaseInsensitiveContains(term)
        let tagMatches = store.classification(diagram).tags.contains { $0.localizedCaseInsensitiveContains(term) }
        switch searchScope {
        case "タイトル": return titleMatches
        case "タグ": return tagMatches
        default: return titleMatches || tagMatches
        }
    }
    private func isSavedOnly(_ diagram: CloudDiagram) -> Bool {
        !store.items.contains { $0.id == diagram.id && $0.version == diagram.version }
    }
    private func open(_ diagram: CloudDiagram, updating: Bool = false) {
        guard !opening else { return }
        opening = true
        let offline = !updating && (store.offline || isSavedOnly(diagram))
        Task {
            defer { opening = false }
            do {
                let files = try await store.readingFiles(diagram, localOnly: offline)
                guard let file = preferredCloudFile(files) else { throw CloudError.unavailable }
                let keepSaved = updating && store.saved.contains { $0.diagram.id.lowercased() == diagram.id.lowercased() }
                let doc = await store.open(diagram, file: file, persist: keepSaved)
                if doc != nil { await store.reloadSaved() }
                if let doc { reading = CloudReading(diagram: diagram, files: files, initial: file, document: doc, offline: offline) }
            } catch { store.errorMessage = "資料を開けませんでした。もう一度お試しください。" }
        }
    }
}
private extension CloudDiagram { var selfKey: String { "\(id)-\(version)" } }

@MainActor
private struct CloudCover: View {
    let diagram: CloudDiagram
    @ObservedObject var store: CloudLibraryStore
    let offline: Bool
    var coverFocused = false
    var suppressThumbnail = false
    var titleOverride: String? = nil
    var captionOverride: String? = nil
    var savedOverride: Bool? = nil
    @State private var image: UIImage?
    var body: some View {
        SquareLibraryCard(title: (titleOverride ?? diagram.title).replacingOccurrences(of: "（モック）", with: "")) {
            Color(uiColor: .secondarySystemBackground)
                .overlay {
                    if let image { Image(uiImage: image).resizable().scaledToFit() }
                    else { Image(systemName: "doc.richtext").font(.largeTitle).foregroundStyle(.secondary) }
                }.clipShape(RoundedRectangle(cornerRadius: 12))
        } caption: {
            HStack {
                Text(captionOverride ?? "\(diagram.pageCount)ページ").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .task(id: "\(diagram.selfKey)-\(offline)-\(store.saved.filter { $0.diagram.id == diagram.id && $0.diagram.version == diagram.version }.count)") {
            guard !suppressThumbnail else { image = nil; return }
            let loaded = await store.thumbnail(diagram, offline: offline)
            if !Task.isCancelled { image = loaded }
        }
    }
}

@MainActor
private struct CloudReader: View {
    let reading: CloudReading
    @ObservedObject var store: CloudLibraryStore
    @State private var document: OpenedDocument
    @State private var file: CloudFile
    @State private var saving = false
    @State private var switching = false
    @State private var showInfo = false
    let onReauthenticate: (() -> Void)?
    init(reading: CloudReading, store: CloudLibraryStore, onReauthenticate: (() -> Void)? = nil) {
        self.onReauthenticate = onReauthenticate
        self.reading = reading; self.store = store
        _document = State(initialValue: reading.document); _file = State(initialValue: reading.initial)
    }
    private var record: SavedCloudFile { SavedCloudFile(diagram: reading.diagram, file: file) }
    var body: some View {
        DocumentViewer(document: document, libraryActions: AnyView(actions), imagePages: imagePageControls,
                       displayIntent: CloudLibraryKind.illustrations.contains(reading.diagram) ? .illustration : .presentation)
            .id(file.format == .png ? "png-pages" : document.id.uuidString)
            .overlay(alignment: .bottom) {
                if saving || switching { ProgressView(saving ? "保存中…" : "読み込み中…").padding().background(.regularMaterial, in: Capsule()).padding(.bottom, 30) }
            }
            .sheet(isPresented: $showInfo) {
                NavigationStack {
                    Form {
                        Section("資料") { Text(reading.diagram.title); Text("版 \(reading.diagram.version) · \(reading.diagram.pageCount)ページ") }
                        Section("ファイル") { Text(file.format.rawValue.uppercased()); Text("\(file.sizeBytes.formatted()) bytes"); Text(file.sha256).font(.caption.monospaced()).textSelection(.enabled) }
                        if reading.files.contains(where: { $0.format == .pptx }) {
                            Section { Text("PPTXはQuick Lookで書体や折り返しが変わる場合があります。見た目を保つ閲覧にはPDFを利用してください。") }
                        }
                    }.navigationTitle("資料情報").toolbar { Button("閉じる") { showInfo = false } }
                }
            }
            .alert("操作を完了できません", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                if store.errorMessage == CloudError.authentication.errorDescription, let onReauthenticate {
                    Button("ログインし直す") { store.errorMessage = nil; onReauthenticate() }
                }
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
    }
    private var actions: some View {
        let layout = UIDevice.current.userInterfaceIdiom == .phone
            ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout())
        return layout {
            Button {
                saving = true
                Task { _ = await store.saveOpened(document, record: record); saving = false }
            } label: { Image(systemName: store.isSaved(record) ? "bookmark.fill" : "bookmark").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel(store.isSaved(record) ? "保存済み" : "資料を保存")
                .disabled(store.isSaved(record) || saving || switching || store.busy)
            Menu {
                ForEach([CloudFormat.pdf, .png, .pptx].filter { f in reading.files.contains(where: { $0.format == f }) }, id: \.self) { format in
                    if let selected = reading.files.first(where: { $0.format == format && (format != .png || $0.page == file.page) }) ?? reading.files.first(where: { $0.format == format }) {
                        Button { switchFile(selected) } label: {
                            if file.format == format { Label(format.rawValue.uppercased(), systemImage: "checkmark") }
                            else { Text(format.rawValue.uppercased()) }
                        }
                    }
                }
                if file.format == .png && reading.files.filter({ $0.format == .png }).count > 1 {
                    Menu("PNGのページ") {
                        ForEach(reading.files.filter { $0.format == .png }, id: \.name) { selected in
                            Button("ページ \(selected.page)") { switchFile(selected) }
                        }
                    }
                }
                Divider()
                Button("資料情報", systemImage: "info.circle") { showInfo = true }
            } label: { Text(file.format.rawValue.uppercased()).font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("形式を選択、現在\(file.format.rawValue.uppercased())").disabled(saving || switching)
        }
    }
    private var imagePageControls: ImagePageControls? {
        let pages = reading.files.filter { $0.format == .png }.sorted { $0.page < $1.page }
        guard file.format == .png, pages.count > 1, let index = pages.firstIndex(of: file) else { return nil }
        return ImagePageControls(canPrevious: !switching && index > 0,
                                 canNext: !switching && index + 1 < pages.count,
                                 previous: { if index > 0 { switchFile(pages[index - 1]) } },
                                 next: { if index + 1 < pages.count { switchFile(pages[index + 1]) } },
                                 pageIndex: index, pageCount: pages.count,
                                 selectPage: { selected in if pages.indices.contains(selected) { switchFile(pages[selected]) } },
                                 thumbnail: { selected in
                                     guard pages.indices.contains(selected) else { return nil }
                                     return await store.cachedSlideThumbnail(reading.diagram, file: pages[selected])
                                 })
    }
    private func switchFile(_ selected: CloudFile) {
        guard !switching, selected != file else { return }
        switching = true
        Task {
            let doc = await store.open(reading.diagram, file: selected, persist: false)
            if let doc { file = selected; document = doc }
            switching = false
        }
    }
}

@MainActor
private struct CloudCapacityView: View {
    let api: any CloudLibraryAPI
    let production: Bool
    let files: CloudFileStore
    @Environment(\.dismiss) private var dismiss
    @State private var capacity: CloudCapacity?
    @State private var history: [StorageCostSnapshot] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var historyError: String?
    @State private var billing: MonthlyBillingReply?
    @State private var billingLoading = false
    @State private var billingError: String?
    private let rate = 0.025
    private let exchange = 150.0
    private let tax = 10.0
    private var measuredGiB: Double { Double(capacity?.sizeBytes ?? 0) / 1_073_741_824 }
    private var estimate: Double? {
        guard let capacity, capacity.standardOnly else { return nil }
        return StorageCostEstimate.monthlyYen(gib: measuredGiB, usdPerGiB: rate, yenPerUSD: exchange, taxPercent: tax)
    }
    private func yen(_ amount: Double) -> String { amount.formatted(.currency(code: "JPY").precision(.fractionLength(2))) }
    var body: some View {
        NavigationStack {
            Form {
                Section(production ? "S3の保存費（月額目安）" : "サンプルの保存費（月額試算）") {
                    if let estimate { Text(yen(estimate) + "／月").font(.title.bold()).accessibilityLabel("月額試算 " + yen(estimate)) }
                    else { Text("S3保存容量を取得すると月額目安を表示します。") }
                    if let capacity {
                        LabeledContent(production ? "保存オブジェクト（全版）" : "サンプル資料", value: "\(capacity.documentCount)個")
                        LabeledContent("削除マーカー", value: "\(capacity.deleteMarkerCount)個")
                        if !capacity.standardOnly { Text("Standard以外の保存クラスを含むため、料金を算出できません。") }
                        LabeledContent("合計容量", value: ByteCountFormatter.string(fromByteCount: capacity.sizeBytes, countStyle: .binary))
                        LabeledContent("取得日時") { Text(capacity.updatedAt, format: .dateTime.year().month().day().hour().minute()) }
                    }
                    if loading { ProgressView("容量を集計しています…") }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    Button("容量を更新・履歴に記録") { Task { await refresh() } }.disabled(loading)
                    Text("専用S3バケットの全オブジェクト版・旧版・ゴミ箱・管理ファイルと削除マーカーを集計します。未完了のマルチパートアップロードは含みません。取得中の変更により差が生じる場合があります。ファイル本体はダウンロードしません。")
                    if !production { Text("サンプルです。実際のS3利用量ではありません。") }
                }
                if production {
                    Section("今月のAWS費用（請求データ）") {
                        if let billing {
                            Text("AWS請求月：" + billing.month + "（UTC）")
                            if let report = billing.report {
                                billingBreakdown("図鑑の費用（配賦確認分）", rows: report.diagram, total: report.diagramUSD)
                                billingBreakdown("共通・未配賦", rows: report.common, total: report.commonUSD)
                                if let date = cloudDate(report.fetchedAt) { LabeledContent("請求データ取得日時") { Text(date, format: .dateTime.year().month().day().hour().minute()) } }
                                Text("集計期間：" + report.periodStart + " 〜 " + report.periodEndExclusive + " 未満（UTC）")
                                Text(report.estimated ? "AWSの暫定額です。月末の確定請求とは異なる場合があります。" : "取得時点のAWS計上額です。今後の調整が反映される場合があります。")
                            } else if billing.status == "allocationPending" {
                                Text("費用の配賦設定を準備中です。図鑑の費用を0円とは判定していません。")
                            } else {
                                Text("今月の請求データは未取得です。取得中または取得に失敗したため、次回取得可能日時まで待ちます。")
                            }
                            if let text = billing.nextRefreshAt, let date = cloudDate(text) {
                                LabeledContent("次回取得可能日時") { Text(date, format: .dateTime.year().month().day().hour().minute()) }
                            }
                        }
                        if billingLoading { ProgressView("保存済み請求データを確認しています…") }
                        if let billingError { Text(billingError).foregroundStyle(.red) }
                        Button("請求データを確認") { Task { await refreshBilling() } }.disabled(billingLoading)
                        Text("全端末でデータを共有し、有料のAWS照会は最短7日に1回です。更新可能日時を過ぎた後の画面表示で取得します。AWSの請求反映にも通常1日以上かかる場合があります。")
                        Text("図鑑はProjectタグで確認できた分のみ。共通・未配賦はProjectタグがなく帰属を確認できない費用です。図鑑の過去費用や他用途の費用も含む場合があります。他プロジェクトのタグが付いた費用は対象外です。")
                        Text("USDはAWS計上額。円表示は1 USD＝150円での参考換算で、税を追加加算しません。上の保存費の月額目安とは期間と計算方法が異なるため合算しません。")
                    }
                }
                Section("料金の計算条件") {
                    Text("東京 S3 Standardの参考値：0.025 USD。為替150円・税10%は仮定です。1 GiB = 1,073,741,824 bytes。容量 × 単価 × 為替 × (1 + 税率 / 100)。50 TiBまでの単一料金帯の試算です。")
                    Link("AWS公式の最新料金を確認", destination: URL(string: "https://aws.amazon.com/jp/s3/pricing/")!)
                }
                Section("取得時点の履歴（この端末・最大365回）") {
                    if let historyError { Text(historyError).foregroundStyle(.red) }
                    if history.isEmpty { Text("容量更新後に記録します。自動・日次計測ではありません。") }
                    else {
                        Chart(history) { item in
                            LineMark(x: .value("取得日時", item.date), y: .value("容量 GiB", Double(item.bytes) / 1_073_741_824))
                            PointMark(x: .value("取得日時", item.date), y: .value("容量 GiB", Double(item.bytes) / 1_073_741_824))
                        }.frame(height: 160).chartYAxisLabel("GiB")
                        Chart(history) { item in
                            LineMark(x: .value("取得日時", item.date), y: .value("月額 円", item.monthlyYen))
                            PointMark(x: .value("取得日時", item.date), y: .value("月額 円", item.monthlyYen))
                        }.frame(height: 160).chartYAxisLabel("円／月")
                        Text("料金は各取得時の条件で記録。現在の条件変更で過去の試算は変わりません。")
                    }
                }
                Section("保存費の月額目安に含まれないもの") {
                    Text("ダウンロード通信料・APIリクエスト・認証等の費用、無料枠・クレジット・日割りは反映しません。現在の容量を1か月保持する仮定で、実際の請求や今月の累計ではありません。")
                }
            }
            .navigationTitle("S3保存容量と月額費用")
            .toolbar { Button("閉じる") { dismiss() } }
            .task {
                do { history = try await files.costHistory() }
                catch { historyError = "保存済み履歴を読み込めませんでした。" }
                await refresh()
                if production { await refreshBilling() }
            }
        }
    }
    private func billingBreakdown(_ title: String, rows: [MonthlyBillingRow], total: String) -> some View {
        let amount = (try? MonthlyBillingReport.amount(total)) ?? 0
        return DisclosureGroup {
            if rows.isEmpty { Text("この条件でAWSが返した費用明細はありません。未計上分が残る場合があります。") }
            ForEach(Array(Set(rows.map(\.category))).sorted(), id: \.self) { category in
                let items = rows.filter { $0.category == category }
                let subtotal = items.reduce(Decimal.zero) { $0 + $1.amount }
                DisclosureGroup {
                    ForEach(items) { row in
                        LabeledContent(row.service + " / " + row.usageType, value: row.amount.formatted(.currency(code: "USD").precision(.fractionLength(4))))
                    }
                } label: { LabeledContent(category, value: subtotal.formatted(.currency(code: "USD").precision(.fractionLength(4)))) }
            }
        } label: {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(amount.formatted(.currency(code: "USD").precision(.fractionLength(4))) + "（約" + (amount * 150).formatted(.currency(code: "JPY").precision(.fractionLength(2))) + "）")
            }
        }
    }
    @MainActor private func refreshBilling() async {
        guard !billingLoading else { return }
        billingLoading = true; billingError = nil
        defer { billingLoading = false }
        do {
            let result = try await api.monthlyBilling()
            try Task.checkCancellation()
            billing = result
        } catch {
            if !Task.isCancelled { billingError = billing == nil ? "今月のAWS費用を取得できませんでした。サーバーの対応状況と接続を確認してください。" : "請求データを更新できませんでした。前回の取得値を表示しています。" }
        }
    }
    @MainActor private func refresh() async {
        guard !loading else { return }
        loading = true; errorMessage = nil
        defer { loading = false }
        do {
            let result = try await api.capacity()
            try Task.checkCancellation()
            capacity = result
            guard result.standardOnly, let cost = StorageCostEstimate.monthlyYen(gib: Double(result.sizeBytes) / 1_073_741_824, usdPerGiB: rate, yenPerUSD: exchange, taxPercent: tax) else {
                errorMessage = "容量は取得しました。Standard以外の保存クラス、または50 TiB超のため料金を算出できません。"; return
            }
            do {
                history = try await files.recordCost(StorageCostSnapshot(date: result.updatedAt, bytes: result.sizeBytes, monthlyYen: cost))
                historyError = nil
            } catch { historyError = "容量は取得しましたが履歴を保存できませんでした。" }
        } catch {
            if !Task.isCancelled { errorMessage = capacity == nil ? "S3保存容量を取得できませんでした。接続状態とサーバーの対応状況を確認してください。" : "更新できませんでした。表示中の容量は前回の取得値です。" }
        }
    }
}

@MainActor
private struct LibraryClassificationEditor: View {
    @Environment(\.dismiss) private var dismiss
    let diagram: CloudDiagram
    @ObservedObject var store: CloudLibraryStore
    @State private var group: LibraryGroup
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var saving = false
    @State private var failed = false
    init(diagram: CloudDiagram, store: CloudLibraryStore) {
        self.diagram = diagram; self.store = store
        let value = store.classification(diagram)
        _group = State(initialValue: value.group); _tags = State(initialValue: value.tags)
    }
    private func addTag() {
        tags = LibraryClassification.normalizedTags(tags + [newTag]); newTag = ""
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(diagram.title) }
                Section("グループ") {
                    Picker("グループ", selection: $group) {
                        ForEach(LibraryGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("タグ") {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button { tags.removeAll { $0 == tag } } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("タグ「\(tag)」を削除")
                        }
                    }
                    HStack {
                        TextField("新しいタグ", text: $newTag).submitLabel(.done).onSubmit { addTag() }
                        Button("追加") { addTag() }.disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section { Text("分類はこのiPhoneに保存され、同じ資料の新版にも適用されます。").font(.caption).foregroundStyle(.secondary) }
                if failed { Text("保存できませんでした。もう一度お試しください。").foregroundStyle(.red) }
            }
            .disabled(saving)
            .navigationTitle("グループ・タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        addTag(); saving = true
                        Task {
                            if await store.setClassification(diagram, value: LibraryClassification(group: group, tags: tags)) { dismiss() }
                            else { failed = true }
                            saving = false
                        }
                    }.disabled(saving)
                }
            }
        }
    }
}
