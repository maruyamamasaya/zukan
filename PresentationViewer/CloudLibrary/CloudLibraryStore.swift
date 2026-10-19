import SwiftUI
import LibraryOrganization
import LibraryOrganizationUI
import PDFKit

@MainActor
final class CloudLibraryStore: ObservableObject {
    @Published private(set) var lifecycle = LibraryLifecycleIndex()
    var lifecycleEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "LibraryLifecycleEnabled") as? Bool == true && api.supportsLifecycle }
    @Published private(set) var organization = OrganizationState<CloudDiagram>()
    @Published private(set) var classifications: [String: LibraryClassification] = [:]
    @Published private(set) var collections: [CloudCollection] = []
    @Published private(set) var hiddenDiagrams: [CloudDiagram] = []
    @Published private(set) var items: [CloudDiagram] = []
    @Published private(set) var localDiagrams: [CloudDiagram] = []
    @Published private(set) var saved: [SavedCloudFile] = []
    @Published private(set) var offline = false
    @Published private(set) var busy = false
    @Published private(set) var refreshing = false
    @Published private(set) var paginationFailed = false
    @Published private(set) var nextCursor: String?
    @Published var errorMessage: String?
    @Published var notice: String?
    private var listedQuery = ""
    private var listedScope = "all"
    private let api: any CloudLibraryAPI
    private var pendingDetails: [String: Task<CloudDetail, Error>] = [:]
    private let files: CloudFileStore
    private final class WeakStore { weak var value: CloudLibraryStore?; init(_ value: CloudLibraryStore) { self.value = value } }
    private static var liveStores: [WeakStore] = []
    private static var productionSessions: [URL: SyncLabSession] = [:]
    private var productionSync = false
    private var enableTestSync: Bool
    private var syncConnection: AuthenticatedSyncConnection?
    private var testSync: SyncLabSession?
    init(api: any CloudLibraryAPI = MockCloudAPI(), files: CloudFileStore, enableTestSync: Bool = false, syncConnection: AuthenticatedSyncConnection? = nil) { self.syncConnection = syncConnection; self.api = api; self.files = files; self.enableTestSync = enableTestSync; Self.liveStores.removeAll { $0.value == nil }; Self.liveStores.append(WeakStore(self)) }
    func loadNextPage(cursor: String) async {
        while refreshing {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled, nextCursor == cursor else { return }
        await refresh(query: listedQuery, scope: listedScope, more: true)
    }
    func refresh(query: String = "", scope: String = "all", more: Bool = false) async {
        if more && (refreshing || nextCursor == nil) { return }
        while refreshing {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        paginationFailed = false
        refreshing = true; defer { refreshing = false }
        do {
            if !more && lifecycleEnabled { try await refreshLifecycle() }
            let append = more && query == listedQuery && scope == listedScope
            organization = try await files.organization(); classifications = try await files.classifications(); collections = try await files.collections(); hiddenDiagrams = try await files.hiddenDiagrams()
            saved = try await files.records()
            localDiagrams = try await files.cachedDiagrams()
            let result = try await api.list(query: query, cursor: append ? nextCursor : nil, scope: scope)
            guard !Task.isCancelled else { return }
            items = append ? items + result.items.filter { new in !items.contains(where: { $0.id == new.id }) } : result.items
            try? await files.cacheCatalog(items)
            offline = false
            listedQuery = query; listedScope = scope
            nextCursor = append && result.nextCursor == nextCursor ? nil : result.nextCursor; saved = try await files.records(); errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            if more {
                paginationFailed = true
                notice = "追加の資料を取得できませんでした。下に引いて再読み込みできます。"
                return
            }
            if !items.isEmpty {
                errorMessage = nil
                notice = "端末の一覧を表示しています。接続時に更新してください。"
                nextCursor = nil
                return
            }
            do {
                items = try await files.cachedDiagrams()
                saved = try await files.records()
                localDiagrams = items
                offline = true; nextCursor = nil
                if !items.isEmpty || !saved.isEmpty {
                    errorMessage = nil; notice = "端末にある資料を表示しています。接続時に一覧を更新してください。"
                } else { errorMessage = message(error) }
            } catch { errorMessage = message(error) }
        }
    }
    private static func refreshProductionStores(_ directory: URL) async throws {
        for reference in liveStores {
            guard let store = reference.value, await store.files.organizationSyncDirectory() == directory else { continue }
            store.organization = try await store.files.organization()
            store.classifications = try await store.files.classifications()
            store.collections = try await store.files.collections()
        }
    }
    func connectOrganizationSync(_ connection: AuthenticatedSyncConnection) async throws -> SyncLabSession {
        guard Bundle.main.object(forInfoDictionaryKey: "OrganizationSyncEnabled") as? Bool == true else { throw OrganizationConnectionError.authentication }
        let directory = await files.organizationSyncDirectory()
        if let existing = Self.productionSessions[directory] {
            guard existing.httpsConnection?.identityKey == connection.identityKey else { throw OrganizationConnectionError.accountChanged }
            testSync = existing; productionSync = true; enableTestSync = true
            return existing
        }
        let files = self.files
        let binding = TestLibrarySyncBinding(read: {
            let value = try await files.testLibrarySyncSource()
            return try JSONDecoder().decode(OrganizationState<OrganizationDocument>.self, from: JSONEncoder().encode(value))
        }, apply: { state in
            let value = try JSONDecoder().decode(OrganizationState<CloudDiagram>.self, from: JSONEncoder().encode(state))
            try await files.applyTestLibrarySync(value)
            try await Self.refreshProductionStores(directory)
        }, backup: { try await files.managementBackup() }, restore: { data in
            try await files.restoreManagementBackup(data)
            try await Self.refreshProductionStores(directory)
        })
        let seed = try await binding.read()
        let documents = items.map { OrganizationDocument(id:$0.id,title:$0.title,type:$0.type,version:$0.version,formats:$0.formats.map(\.rawValue),pageCount:$0.pageCount,tags:$0.tags) }
        let session = SyncLabSession(directory: directory, seed: seed, documents: documents, binding: binding, rateLimited: true, connection: connection)
        Self.productionSessions[directory] = session
        for reference in Self.liveStores {
            guard let store = reference.value, await store.files.organizationSyncDirectory() == directory else { continue }
            store.testSync = session; store.productionSync = true; store.enableTestSync = true
        }
        return session
    }
    func makeSyncLab() async -> SyncLabSession {
        if enableTestSync {
            if let testSync { return testSync }
            let binding = TestLibrarySyncBinding(read: { [weak self] in
                guard let self else { throw CancellationError() }
                let value = try await self.files.testLibrarySyncSource()
                return try JSONDecoder().decode(OrganizationState<OrganizationDocument>.self, from: JSONEncoder().encode(value))
            }, apply: { [weak self] state in
                guard let self else { throw CancellationError() }
                let value = try JSONDecoder().decode(OrganizationState<CloudDiagram>.self, from: JSONEncoder().encode(state))
                try await self.files.applyTestLibrarySync(value)
                self.organization = try await self.files.organization(); self.classifications = try await self.files.classifications(); self.collections = try await self.files.collections()
            }, backup: { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.files.managementBackup()
            }, restore: { [weak self] data in
                guard let self else { throw CancellationError() }
                try await self.files.restoreManagementBackup(data)
                self.organization = try await self.files.organization(); self.classifications = try await self.files.classifications(); self.collections = try await self.files.collections()
            })
            let seed = (try? await binding.read()) ?? OrganizationState<OrganizationDocument>()
            let documents = items.map { OrganizationDocument(id: $0.id, title: $0.title, type: $0.type, version: $0.version, formats: $0.formats.map(\.rawValue), pageCount: $0.pageCount, tags: $0.tags) }
            let session = SyncLabSession(directory: await (productionSync ? files.organizationSyncDirectory() : files.testLibrarySyncDirectory()), seed: seed, documents: documents, binding: binding, rateLimited: true, connection: syncConnection)
            testSync = session; return session
        }
        await reloadSaved()
        func document(_ member: CloudDiagram) -> OrganizationDocument {
            OrganizationDocument(id: member.id, title: member.title, type: member.type, version: member.version, formats: member.formats.map(\.rawValue), pageCount: member.pageCount, tags: member.tags)
        }
        var seed = OrganizationState<OrganizationDocument>()
        seed.folders = organization.folders; seed.folderOrder = organization.folderOrder; seed.assignments = organization.assignments
        seed.classifications = classifications
        seed.collections = collections.map { ReadingCollection(id: $0.id, title: $0.title, members: $0.members.map(document)) }
        var seen = Set<String>()
        let documents = (items + localDiagrams + saved.map(\.diagram) + collections.flatMap(\.members)).map(document).filter { seen.insert($0.id).inserted }
        return SyncLabSession(directory: await files.syncLabDirectory(), seed: seed, documents: documents)
    }
    func createFolder(_ name: String, parentID: UUID? = nil, shelf: LibraryShelf? = nil) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        do { organization = try await files.createFolder(name: name, parentID: parentID, shelf: shelf); await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    func moveDocuments(_ ids: Set<String>, to folderID: UUID?, scoped: Bool = false) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        let known = Set((items + localDiagrams + saved.map(\.diagram) + collections.flatMap(\.members)).map { $0.id.lowercased() })
        guard !ids.isEmpty, Set(ids.map { $0.lowercased() }).isSubset(of: known) else { errorMessage = CloudError.invalidResponse.errorDescription; return false }
        do { organization = try await files.moveDocuments(ids, to: folderID, scoped: scoped); collections = try await files.collections(); await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    func removeFolder(_ id: UUID, scoped: Bool = false) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        do { organization = try await files.removeOrganizationFolder(id, scoped: scoped); collections = try await files.collections(); await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    var integratedOrganization: OrganizationState<CloudDiagram> {
        var value = organization; value.collections = collections
        let documents = items + localDiagrams + saved.map(\.diagram) + collections.flatMap(\.members)
        let kinds = Dictionary(documents.map { ($0.id.lowercased(), CloudLibraryKind.illustrations.contains($0)) }, uniquingKeysWith: { a, _ in a })
        value.scopeLegacyFolders { kinds[$0.lowercased()] == true ? .illustration : .presentation }
        return value
    }
    func renameFolder(_ id: UUID, name: String) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { return false }
        do { organization = try await files.renameOrganizationFolder(id, name: name); await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    func folderPath(_ id: UUID) -> String {
        var names: [String] = []; var next: UUID? = id; var seen = Set<UUID>()
        while let current = next, seen.insert(current).inserted, let folder = (organization.folders.first(where: { $0.id == current }) ?? integratedOrganization.folders.first(where: { $0.id == current })) {
            if !LibraryShelf.isRoot(folder.id) { names.insert(folder.name, at: 0) }; next = folder.parentID
        }
        return names.joined(separator: " / ")
    }
    func classification(_ diagram: CloudDiagram) -> LibraryClassification {
        classifications[diagram.id.lowercased()] ?? LibraryClassification(tags: LibraryClassification.normalizedTags(diagram.tags))
    }
    func setClassification(_ diagram: CloudDiagram, value: LibraryClassification) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        do {
            classifications = try await files.setClassification(diagram, value: value)
            await testSync?.captureLibraryChanges()
            errorMessage = nil
            return true
        } catch { errorMessage = message(error); return false }
    }
    func saveCollection(_ collection: CloudCollection) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        do { collections = try await files.saveCollection(collection); errorMessage = nil; await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    func removeCollection(_ id: UUID) async -> Bool {
        guard testSync?.blocksLibraryEdits != true else { errorMessage = "同期の確認・復元処理中です。同期画面で完了または解除してから編集してください。"; return false }
        do { collections = try await files.removeCollection(id); errorMessage = nil; await testSync?.captureLibraryChanges(); return true }
        catch { errorMessage = message(error); return false }
    }
    func members(of collection: CloudCollection) -> [CloudDiagram] {
        collection.resolved(using: items + saved.map(\.diagram) + hiddenDiagrams, hidden: []).filter { lifecycle.status($0.id) == .active }
    }
    func collectionPages(_ collection: CloudCollection) async throws -> [CloudCollectionPage] {
        var pages: [CloudCollectionPage] = []
        for diagram in members(of: collection) {
            try Task.checkCancellation()
            let available: [CloudFile]
            // When no live catalog entry exists, keep the exact saved version usable without network.
            if !items.contains(where: { $0.id.lowercased() == diagram.id.lowercased() && $0.version == diagram.version }),
               saved.contains(where: { $0.diagram.id.lowercased() == diagram.id.lowercased() && $0.diagram.version == diagram.version }) {
                available = saved.filter { $0.diagram.id.lowercased() == diagram.id.lowercased() && $0.diagram.version == diagram.version }.map(\.file)
            } else { available = try await detail(diagram).files }
            let selected = collectionReadingFiles(available)
            guard !selected.isEmpty else { throw CloudError.unavailable }
            pages += selected.map { CloudCollectionPage(diagram: diagram, file: $0) }
        }
        guard !pages.isEmpty else { throw CloudError.unavailable }
        return pages
    }
    var trashedDiagrams: [CloudDiagram] {
        lifecycle.entries.values.filter { $0.status == .trashed || $0.status == .deleting }.compactMap {
            try? JSONDecoder().decode(CloudDiagram.self, from: JSONEncoder().encode($0.document))
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    private func publishLifecycle() async throws {
        let directory = await files.organizationSyncDirectory()
        for reference in Self.liveStores {
            guard let store = reference.value, await store.files.organizationSyncDirectory() == directory else { continue }
            store.lifecycle = try await store.files.lifecycleIndex()
        }
    }
    func refreshLifecycle() async throws {
        guard lifecycleEnabled else { return }
        let snapshot = try await api.lifecycleSnapshot()
        lifecycle = try await files.applyLifecycle(snapshot)
        try await publishLifecycle()
    }
    func setTrashed(_ diagrams: [CloudDiagram], trashed: Bool) async -> Set<String> {
        guard lifecycleEnabled, !busy else { errorMessage = "共通ゴミ箱はサーバー反映の準備中です。"; return [] }
        busy = true; defer { busy = false }
        var completed = Set<String>()
        for diagram in diagrams {
            do {
                let id = diagram.id.lowercased()
                let entry = try await api.moveToTrash(diagram, revision: lifecycle.entries[id]?.revision ?? 0, trashed: trashed)
                lifecycle = try await files.applyLifecycle(entry)
                completed.insert(id)
                try await publishLifecycle()
            } catch { errorMessage = "完了した操作は保持しました。残りの資料は再読み込みしてから再試行してください。"; break }
        }
        await reloadSaved()
        return completed
    }
    func prepareDeletion(_ ids: Set<String>) async -> [LibraryDeletionPlan]? {
        guard lifecycleEnabled, !busy, !ids.isEmpty else { return nil }
        busy = true; defer { busy = false }
        do {
            var plans: [LibraryDeletionPlan] = []
            for id in ids.sorted() { plans.append(try await api.deletionPlan(id: id)) }
            return plans
        } catch { errorMessage = "削除対象を確認できませんでした。再読み込みしてから再試行してください。"; return nil }
    }
    func permanentlyDelete(_ plans: [LibraryDeletionPlan]) async -> Set<String> {
        guard lifecycleEnabled, !busy else { return [] }
        busy = true; defer { busy = false }
        var completed = Set<String>()
        for plan in plans {
            do {
                let entry = try await api.permanentlyDelete(plan)
                lifecycle = try await files.applyLifecycle(entry)
                completed.insert(plan.id)
                try await publishLifecycle()
            } catch {
                try? await refreshLifecycle()
                errorMessage = "削除を完了できない資料があります。削除中の資料は復元できません。同じ対象の削除を再試行できます。"
                break
            }
        }
        await reloadSaved()
        return completed
    }
    func isHidden(_ diagram: CloudDiagram) -> Bool {
        hiddenDiagrams.contains { $0.id.lowercased() == diagram.id.lowercased() }
    }
    func setHidden(_ diagram: CloudDiagram, hidden: Bool) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        do {
            let updated = try await files.setHidden(diagram, hidden: hidden)
            hiddenDiagrams = updated
            errorMessage = nil
            notice = hidden ? "このiPhoneで非表示にしました" : "表示に戻しました"
            return true
        } catch { errorMessage = message(error); return false }
    }
    private func download(_ diagram: CloudDiagram, file: CloudFile) async throws -> Data {
        for attempt in 0...1 {
            do {
                let grant = try await api.access(diagram: diagram, file: file)
                if cloudDate(grant.expiresAt).map({ $0 <= Date() }) == true { throw CloudError.expiredURL }
                try grant.validate(file: file)
                return try await api.download(grant)
            } catch CloudError.expiredURL { if attempt == 1 { throw CloudError.expiredURL } }
        }
        throw CloudError.expiredURL
    }
    func preferredLocalVersion(_ diagram: CloudDiagram) -> CloudDiagram {
        (localDiagrams + saved.map(\.diagram)).filter {
            $0.id.lowercased() == diagram.id.lowercased() && $0.version <= diagram.version
        }.max { $0.version < $1.version } ?? diagram
    }
    func availableUpdate(_ diagram: CloudDiagram) -> CloudDiagram? {
        guard !offline else { return nil }
        return items.filter { $0.id.lowercased() == diagram.id.lowercased() && $0.version > diagram.version }
            .max { $0.version < $1.version }
    }
    func localReadingFiles(_ diagram: CloudDiagram) async throws -> [CloudFile] {
        if let detail = try await files.cachedDetail(diagram) { return try await files.localFiles(detail) }
        return saved.filter { $0.diagram.id.lowercased() == diagram.id.lowercased() && $0.diagram.version == diagram.version }.map(\.file)
    }
    /// A cached cover is not the document's complete set of formats/pages.
    func readingFiles(_ diagram: CloudDiagram, localOnly: Bool = false) async throws -> [CloudFile] {
        if localOnly || offline { return try await localReadingFiles(diagram).filter { $0.format != .svg } }
        return try await detail(diagram).files.filter { $0.format != .svg }
    }
    func reloadSaved() async {
        do {
            lifecycle = try await files.lifecycleIndex()
            try await files.purgeDeletedCopies(lifecycle)
            if items.isEmpty { items = (try? await files.cachedCatalog()) ?? [] }
            organization = try await files.organization(); classifications = try await files.classifications(); collections = try await files.collections(); hiddenDiagrams = try await files.hiddenDiagrams(); saved = try await files.records(); localDiagrams = try await files.cachedDiagrams(); if items.isEmpty { items = try await files.cachedDiagrams(); offline = true } } catch { errorMessage = message(error) }
    }
    func detail(_ diagram: CloudDiagram) async throws -> CloudDetail {
        try diagram.validate()
        guard lifecycle.status(diagram.id) == .active else { throw CloudError.unavailable }
        if let detail = try await files.cachedDetail(diagram) {
            if offline {
                let local = try await files.localFiles(detail)
                return CloudDetail(id: detail.id, title: detail.title, type: detail.type, version: detail.version,
                                   formats: detail.formats, pageCount: detail.pageCount, tags: detail.tags, files: local)
            }
            return detail
        }
        let key = "\(diagram.id)-\(diagram.version)"
        if let task = pendingDetails[key] { return try await task.value }
        let task = Task { [api, files] in
            let detail = try await api.detail(id: diagram.id, version: diagram.version)
            try detail.validate()
            guard detail.id == diagram.id, detail.version == diagram.version,
                  detail.type == diagram.type, detail.pageCount == diagram.pageCount,
                  detail.formats == diagram.formats else { throw CloudError.invalidResponse }
            try await files.cacheDetail(detail)
            return detail
        }
        pendingDetails[key] = task
        defer { pendingDetails[key] = nil }
        return try await task.value
    }
    private func localOrDownload(_ diagram: CloudDiagram, file: CloudFile) async throws -> URL {
        let record = SavedCloudFile(diagram: diagram, file: file)
        if let url = try await files.localURL(record) { return url }
        return try await files.cacheData(download(diagram, file: file), record: record)
    }
    func open(_ diagram: CloudDiagram, file: CloudFile, persist: Bool) async -> OpenedDocument? {
        guard !busy else { return nil }
        busy = true; notice = nil; defer { busy = false }
        do {
            try file.validate(for: diagram)
            let record = SavedCloudFile(diagram: diagram, file: file)
            let local = try await localOrDownload(diagram, file: file)
            let url: URL
            if persist {
                try await files.save(Data(contentsOf: local), record: record); url = try await files.open(record)
                saved = try await files.records(); notice = "アプリ内に保存しました。オフラインで開けます。"
            } else { url = local }
            return opened(url, record: record)
        } catch { errorMessage = message(error); return nil }
    }
    func openSaved(_ record: SavedCloudFile) async -> OpenedDocument? {
        do { return opened(try await files.open(record), record: record) }
        catch { errorMessage = message(error); return nil }
    }
    func clearCache() async {
        guard !busy else { return }
        do { try await files.clearCache(); localDiagrams = []; if offline { items = [] }; notice = "一時キャッシュを削除しました。保存済み資料は残っています。" }
        catch { errorMessage = message(error) }
    }
    func clearLocalDocuments() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            try await files.clearLocalDocuments()
            saved = []; localDiagrams = []; if offline { items = [] }
            errorMessage = nil; notice = "端末の資料を削除しました。S3の資料は残っています。"
        } catch { await reloadSaved(); errorMessage = message(error) }
    }
    func saveOpened(_ document: OpenedDocument, record: SavedCloudFile) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        do {
            try await files.save(Data(contentsOf: document.url), record: record)
            saved = try await files.records(); notice = "保存しました"
            return true
        } catch { errorMessage = message(error); return false }
    }
    func isSaved(_ record: SavedCloudFile) -> Bool {
        saved.contains { $0.id == record.id && $0.file == record.file }
    }
    func cachedSlideThumbnail(_ diagram: CloudDiagram, file: CloudFile) async -> UIImage? {
        guard let url = try? await files.localURL(SavedCloudFile(diagram: diagram, file: file)) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func thumbnail(_ diagram: CloudDiagram, offline: Bool) async -> UIImage? {
        do {
            let url: URL
            if offline {
                let available = try await localReadingFiles(diagram)
                guard let file = preferredCloudFile(available),
                      let local = try await files.localURL(SavedCloudFile(diagram: diagram, file: file)) else { return nil }
                url = local
            } else {
                let detail = try await detail(diagram)
                guard let file = detail.files.first(where: { $0.format == .png && $0.page == 1 }) ?? detail.files.first(where: { $0.format == .pdf }) else { return nil }
                url = try await localOrDownload(diagram, file: file)
            }
            if url.pathExtension == "pdf" {
                return PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 420, height: 236), for: .mediaBox)
            }
            return UIImage(contentsOfFile: url.path)
        } catch { return nil }
    }
    private func opened(_ url: URL, record: SavedCloudFile) -> OpenedDocument {
        OpenedDocument(url: url, name: record.diagram.title.replacingOccurrences(of: "（モック）", with: ""), format: record.file.format.documentFormat, accessURL: url, scoped: false)
    }
    private func message(_ error: Error) -> String { (error as? CloudError)?.errorDescription ?? "処理を完了できませんでした。保存領域と接続を確認してください。" }
}

func preferredCloudFile(_ files: [CloudFile]) -> CloudFile? {
    for format in [CloudFormat.pdf, .png, .pptx] {
        if let file = files.filter({ $0.format == format }).sorted(by: { $0.page < $1.page }).first { return file }
    }
    return nil
}
