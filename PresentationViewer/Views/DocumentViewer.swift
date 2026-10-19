import SwiftUI
import QuickLook
import PDFKit

@MainActor
struct DocumentViewer: View {
    let document: OpenedDocument
    let libraryActions: AnyView?
    let imagePages: ImagePageControls?
    let externalPageNavigation: Bool
    let displayIntent: ViewerDisplayIntent
    @StateObject private var pdfSession: PDFReadingSession
    @ObservedObject private var external = ExternalDisplayCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = true
    @State private var slideRailVisible = false
    @State private var canvasZoomed = false
    @State private var titleVisible = false
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone && document.format != .pptx }

    init(document: OpenedDocument, libraryActions: AnyView? = nil, imagePages: ImagePageControls? = nil, displayIntent: ViewerDisplayIntent = .presentation, externalPageNavigation: Bool = false) {
        self.document = document
        self.libraryActions = libraryActions
        self.imagePages = imagePages
        self.externalPageNavigation = externalPageNavigation
        self.displayIntent = displayIntent
        let session = PDFReadingSession(url: document.format == .pdf ? document.url : nil)
        session.isPresenting = true
        _pdfSession = StateObject(wrappedValue: session)
    }
    private var supportsPaging: Bool { document.format == .pdf || imagePages != nil }
    private var currentPage: Int { document.format == .pdf ? pdfSession.pageIndex : imagePages?.pageIndex ?? 0 }
    private var totalPages: Int { document.format == .pdf ? pdfSession.pageCount : imagePages?.pageCount ?? 1 }
    private var showControls: Bool { controlsVisible || document.format == .pptx }

    var body: some View {
        Group {
            if isPhone {
                HStack(spacing: 0) {
                    readingCanvas
                    phoneControls.frame(width: 60)
                        .opacity(showControls ? 1 : 0)
                        .allowsHitTesting(showControls).accessibilityHidden(!showControls)
                }
            } else {
                standardReader
            }
        }
        .background(Color.black).foregroundStyle(.white).preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear { if document.format == .pdf { external.begin(pdfSession) } }
        .onDisappear { external.end(pdfSession) }
    }

    private var readingCanvas: some View {
        HStack(spacing: 0) {
            if controlsVisible && slideRailVisible && supportsPaging { slideSidebar.frame(width: 76) }
            documentCanvas.frame(maxWidth: .infinity, maxHeight: .infinity)
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                    guard supportsPaging, !canvasZoomed,
                          abs(value.translation.width) > 60,
                          abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    movePage(previous: value.translation.width > 0)
                })
        }
    }

    private var phoneControls: some View {
        VStack(spacing: 0) {
            Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("資料を閉じる").keyboardShortcut(.cancelAction)
            Button { titleVisible = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("資料名：\(document.name)")
                .popover(isPresented: $titleVisible) {
                    Text(document.name).font(.headline).padding().presentationCompactAdaptation(.popover)
                }
            if let libraryActions { libraryActions }
            if supportsPaging {
                Button { slideRailVisible.toggle() } label: { Image(systemName: "sidebar.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(slideRailVisible ? "ページ一覧を閉じる" : "ページ一覧を開く")
            }
            Spacer(minLength: 0)
            if supportsPaging {
                pageButton(previous: true)
                Text("\(min(currentPage + 1, totalPages))/\(totalPages)")
                    .font(.caption.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityLabel("全\(totalPages)ページ中の\(currentPage + 1)ページ目")
                pageButton(previous: false)
            }
        }.frame(maxHeight: .infinity)
    }

    private var standardReader: some View {
        VStack(spacing: 0) {
            // Reserve the controls' space even while hidden, so a tap never resets zoom.
            header.opacity(showControls ? 1 : 0).allowsHitTesting(showControls).accessibilityHidden(!showControls)
            readingCanvas
            if supportsPaging {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    pageButton(previous: true)
                    Text("\(min(currentPage + 1, totalPages))/\(totalPages)")
                        .font(.subheadline.monospacedDigit()).accessibilityLabel("全\(totalPages)ページ中の\(currentPage + 1)ページ目")
                    pageButton(previous: false)
                }.padding(.horizontal, 20).frame(maxWidth: .infinity).frame(height: 64)
                    .opacity(controlsVisible ? 1 : 0).allowsHitTesting(controlsVisible).accessibilityHidden(!controlsVisible)
            }
        }
    }
    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("資料を閉じる").keyboardShortcut(.cancelAction)
            Text(document.name).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if let libraryActions { libraryActions }
            if supportsPaging {
                Button { slideRailVisible.toggle() } label: {
                    Image(systemName: "sidebar.left").frame(width: 44, height: 44)
                }.accessibilityLabel(slideRailVisible ? "ページ一覧を閉じる" : "ページ一覧を開く")
            }
        }.padding(.horizontal, 8).frame(minHeight: 48).background(.ultraThinMaterial)
    }
    private func toggleControls() { withAnimation(.easeInOut(duration: 0.15)) { controlsVisible.toggle() } }
    @ViewBuilder private var documentCanvas: some View {
        switch document.format {
        case .pptx:
            if QLPreviewController.canPreview(document.url as NSURL) { QuickLookView(url: document.url) }
            else { ViewerErrorView(message: "このPPTXはQuick Lookで表示できません。PDFを使用してください。") }
        case .pdf:
            PDFDocumentView(session: pdfSession, thumbnailsVisible: false, onZoomChanged: { canvasZoomed = $0 })
                .simultaneousGesture(TapGesture().onEnded { toggleControls() })
        case .svg: ViewerErrorView(message: "SVGの表示は終了しました。PDFまたはPNGを使用してください。")
        case .png, .jpg, .jpeg:
            ImageDocumentView(url: document.url, presenting: true, onTap: toggleControls, onZoomChanged: { canvasZoomed = $0 }).id(document.url)
        }
    }
    private var slideSidebar: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Button {
                            if document.format == .pdf { pdfSession.selectPage(index) }
                            else { imagePages?.selectPage?(index) }
                        } label: {
                            ZStack {
                                if document.format != .pdf {
                                    PresentationImageThumbnail(index: index, currentURL: index == currentPage ? document.url : nil, load: imagePages?.thumbnail)
                                }
                                if let page = pdfSession.document?.page(at: index) {
                                    Image(uiImage: page.thumbnail(of: CGSize(width: 112, height: 64), for: .mediaBox))
                                        .resizable().scaledToFit().opacity(0.85)
                                }
                                Text("\(index + 1)").font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .shadow(color: .black.opacity(0.6), radius: 1)
                            }
                            .frame(width: 68, height: 44)
                            .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(index == currentPage ? 0.6 : 0.12), lineWidth: index == currentPage ? 1.5 : 0.5))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).id(index)
                        .disabled(document.format != .pdf && imagePages?.selectPage == nil)
                        .accessibilityLabel("スライド \(index + 1)")
                        .accessibilityAddTraits(index == currentPage ? .isSelected : [])
                    }
                }.padding(4)
            }
            .scrollIndicators(.hidden)
            .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .onAppear { proxy.scrollTo(currentPage, anchor: .center) }
            .onChange(of: currentPage) { _, index in
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }

    private func pageButton(previous: Bool) -> some View {
        Button { movePage(previous: previous) } label: { Image(systemName: previous ? "chevron.left" : "chevron.right") }
            .accessibilityLabel(previous ? "前のページ" : "次のページ")
            .keyboardShortcut(previous ? .leftArrow : .rightArrow, modifiers: [])
            .disabled(document.format == .pdf && !externalPageNavigation
                ? (previous ? currentPage == 0 : currentPage + 1 >= totalPages)
                : (previous ? imagePages?.canPrevious != true : imagePages?.canNext != true))
            .buttonStyle(PresentationSideButtonStyle())
    }
    private func movePage(previous: Bool) {
        if document.format == .pdf && !externalPageNavigation {
            pdfSession.movePage(previous ? -1 : 1)
        } else if previous {
            if imagePages?.canPrevious == true { imagePages?.previous() }
        } else if imagePages?.canNext == true { imagePages?.next() }
    }
}

/// Resolve the scene from the viewer itself so external displays are never rotated.
@MainActor
private final class ViewerOrientationController: ObservableObject {
    weak var viewController: UIViewController?
    @Published var errorMessage: String?

    func request(_ orientations: UIInterfaceOrientationMask, allowingRotation: Bool = false) {
        let orientations = AppOrientationPolicy.effectiveMask(orientations, idiom: UIDevice.current.userInterfaceIdiom)
        AppOrientationPolicy.mask = allowingRotation ? .allButUpsideDown : orientations
        guard let viewController, let scene = viewController.view.window?.windowScene else {
            errorMessage = "画面の準備ができていません。もう一度お試しください。"
            return
        }
        errorMessage = nil
        scene.windows.filter { $0.isKeyWindow }.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { [weak self] _ in
            Task { @MainActor in
                self?.errorMessage = "この表示状態では画面の向きを変更できません。iPadでは全画面で開いてからお試しください。"
            }
        }
    }
}

private struct ViewerOrientationAnchor: UIViewControllerRepresentable {
    let controller: ViewerOrientationController

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        controller.viewController = viewController
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ViewerErrorView: View {
    let message: String
    var body: some View {
        ContentUnavailableView("表示できません", systemImage: "doc.badge.exclamationmark", description: Text(message))
    }
}

private struct PresentationSideButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Generous side controls; the full rectangle participates in hit testing.
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 44, height: UIDevice.current.userInterfaceIdiom == .pad ? 52 : 44)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.white.opacity(0.3) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
    }
}

struct ImagePageControls {
    let canPrevious: Bool
    let canNext: Bool
    let previous: () -> Void
    let next: () -> Void
    var pageIndex: Int = 0
    var pageCount: Int = 1
    var selectPage: ((Int) -> Void)? = nil
    var thumbnail: ((Int) async -> UIImage?)? = nil
}

private struct PresentationImageThumbnail: View {
    let index: Int
    let currentURL: URL?
    let load: ((Int) async -> UIImage?)?
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().opacity(0.85)
            } else {
                Color.clear
            }
        }.task(id: currentURL) {
            if let currentURL { image = UIImage(contentsOfFile: currentURL.path) }
            else { image = await load?(index) }
        }
    }
}

/// Library classification determines the action; page count alone does not identify illustrations.
enum ViewerDisplayIntent {
    case presentation, illustration

    func orientation(for size: CGSize?) -> UIInterfaceOrientationMask {
        guard self == .illustration else { return .landscape }
        guard let size, size.width > 0, size.height > 0 else { return .portrait }
        return size.width > size.height ? .landscape : .portrait
    }
}
