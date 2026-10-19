# PDF・PNGの統合ビューアー

2026-10-19。本人指定の操作方針：iPhone/iPad両方、一覧からすぐ1ページ、スワイプでページ送り、ピンチで拡大、タップで操作表示/非表示。Simulatorの実操作確認後に実機反映する。

## 操作

資料を開くとPDF/PNGをそのまま1ページ表示する。通常閲覧とプレゼンの開始/終了をなくし、閉じるで本棚へ戻る。最初は操作を表示するが、本文タップで表示/非表示を切り替える。上部に閉じる・タイトル・クラウド資料の保存/形式切替・ページ一覧、下部に前/現在ページ/次を集約。操作を隠してもスワイプは使える。操作行の領域を保持して表示切替による拡大率リセットを防ぐ。ページ一覧は必要時だけ開く。

PDFは既存PDFKitのsinglePage、画像は既存UIScrollViewで縦横比を保持する。PDFViewScaleChangedと画像zoom delegateから拡大状態を受け、拡大中の横ドラッグはページ送りへ流さない。全体表示では横スワイプで前後に進む。iPhoneの横向き専用とiPadの任意回転を維持する。PDF外部画面は閲覧開始から既存sessionを利用する。

PPTXは既存Quick Lookを利用し、システム側の操作を保持する。SVG対象外。ローカル資料・クラウド資料・図解まとめは共通DocumentViewerを使う。保存/認証/同期と先行した表紙キャッシュ修正は維持する。

## 検証

- iPad Pro 11インチ M5 / iOS26.5 Simulator：71 XCTest、失敗0。
- iPhone17e / iOS26.5 Simulator：71 XCTest、失敗0。
- 新規回帰：実UIHostingControllerにPDFビューアーを配置して初回singlePage/3ページ/区切りなしを確認。画像の拡大・fit復帰でページ送り防止用状態が更新されることを確認。
- iPad手動：一覧からPDF単ページ、タップで操作非表示/再表示、非表示中スワイプで2ページ目、ページ一覧から3ページ目、PDF→PNG、拡大中ドラッグでページ維持、fit復帰後PNG2ページ目、保存済み表示、閉じる。
- iPhone手動：横画面でPDF単ページ、スワイプ2ページ目、タップで操作切替、一覧から3ページ目、PDF→PNG、PNG2ページ目、画像拡大中ドラッグでページ維持。
- git diff --check合格。実機向け署名ビルド後、両実機へ同Bundle IDで上書き更新する。

画像の拡大確認はUIKitのアクセシビリティ拡大操作を使う。二本指ピンチそのものの手動ジェスチャーは今回のツールでは未確認。PPTX・外部ディスプレイ・全資料の実操作・全文字サイズは未確認。Simulatorのモック確認と本番実資料の本人確認を区別する。

ログ/画像：outputs/unified-reader/。

## 実機反映

10:14 JST、Mira（iPad）・Vespera（iPhone）へ同Team/Bundle IDで上書きインストールと更新版起動成功。アンインストール・認証情報/保存資料の削除なし。実機での本番資料の操作感は本人確認待ち。

## iPhoneの資料領域拡大（2026-10-19）

iPhoneのPDF/画像では上下の操作行をなくし、右端60ptの縦列へ閉じる・資料名・保存/形式・一覧・前後/ページ数を集約する。資料名は情報ボタンのポップオーバーで確認する。タップ非表示時も横幅を保持し、倍率リセットを防ぐ。資料領域の高さから操作行96ptを除き、縦横比を保って大きく表示する。iPad/PPTXは既存配置を維持。実機更新・実画面の確認は未実施。

今回の検証：iOS Simulator Debug（arm64/x86_64）ビルド成功、git diff --check合格。旧構造検査は既存Swift package禁止条件で失敗。実画面の配置・実機の読みやすさは未確認。ビルドログ：/tmp/zukan-phone-reader-build.log。

## 右端操作の画面確認・更新（2026-10-19）

iPhone SimulatorでPDF/PNGの表示、前後ページ、タイトルのポップオーバー、操作非表示/復帰を確認。上下の操作バーを使わず本文が拡大し、右端列と重ならない。iPadは本人の追加指定によりページ操作を下部右端へ移動、前後ボタンを64×52pt・背景/枠付きに変更。縦横画面で配置と前後移動を確認。画面証跡：outputs/reader-controls/ipad-landscape.png。

既存Team U29GY347DY・Bundle ID com.example.PresentationViewerで署名ビルド/codesign検証成功。Vesperaへ10:43に更新インストール/起動成功、Miraも更新インストール/10:43起動成功。保存資料/認証を消すアンインストールなし。本人の実機操作は未確認。ログ：/tmp/zukan-reader-device-{build,install,launch}.log、/tmp/zukan-reader-ipad-{install,launch}.log。

回帰テストの初回は共有パッケージのarm64/x86_64混在でリンク失敗。arm64専用の新規DerivedDataで再試行。

arm64再試行はViewerStateTests 12件・失敗0で合格。git diff --check合格。ログ：/tmp/zukan-reader-tests-arm64.log。
