2026-10-20：本番取得障害を修復。APIの読取仕様と保存仕様の一致確認・不正版隔離、両クライアントの美術史対応、10GBの永続閲覧キャッシュ、認証更新/一時失敗再試行を実装。Mira/Vesperaで本人ログインによる実PDF取得・PDFKit描画・通信なし再表示を確認。[記録](sessions/2026-10-20-fetch-stability.md)。

2026-10-20：iPhone/iPadの一覧表紙を縮小・バックグラウンド生成・メモリ再利用へ変更。iPhone/iPad Simulator各77 XCTest合格。2026-10-20 01:11 JSTまでにMira/VesperaへRelease署名版を更新・起動済み。実機スクロール速度比較は未実施。[仕様](docs/cloud-library.md#一覧表紙の軽量化2026-10-20)、[検証記録](sessions/2026-10-20-library-thumbnails.md)。

2026-10-19：既存容量画面へ「今月のAWS費用」を追加するローカル実装。図鑑配賦分/共通未配賦・内訳・取得日時・7日共有枠を表示。本人承認後、サーバーは無効flagで配備・Project配賦タグActive。CE反映待ちのため金額取得/実機更新は保留。実機確認対象はMiraだけ。本人承認で8時間おき最大4回の反映確認と成功後の更新を設定済み。[仕様](docs/monthly-billing.md)。

2026-10-19：保存費画面を「S3保存容量と月額費用」に変更、容量/料金の手入力を廃止。全版実容量endpointへ接続。本人承認後、本番API/IAM適用・CLI容量照合が成功。Vespera/Miraへ更新インストール・起動済み。実機画面操作は未確認。[仕様](docs/s3-storage-capacity.md)。

2026-10-19：S3専用・共通サイドバー版を本人指示でVespera/Miraへ更新済み。起動/実機操作の確認は本人が後日実施。[状態](docs/s3-only-bookshelf.md)。

2026-10-19：S3専用化とMac共通のサイドバー整理を実装。ローカル資料入口を廃止、資料種別→すべて/未整理→フォルダ→ゴミ箱→本棚管理へ整理。72 XCTest・署名build成功、実機入替/確認は後日。[記録](docs/s3-only-bookshelf.md)。

2026-10-19：ゴミ箱へ「ゴミ箱を空にする…」追加。S3全版容量と関連ファイル数の確認後に既存完全削除へ進む。52 XCTest合格、Vespera/Mira更新・起動成功。今回実資料削除なし。

2026-10-19：端末内の「非表示」を画面から廃止し、共通ゴミ箱へ統一。旧非表示の資料は通常一覧へ戻し、自動削除/ゴミ箱移動なし。[仕様](docs/local-hidden-documents.md)。

2026-10-19：屋久杉/黒漆の素材未描画をPNG直接復号で修正。共有の画素検査を追加、iPad/iPhone各72テスト成功・実素材目視、Mira/Vesperaへ11:07再更新/起動成功。初回は配色確認のみで素材の検証不足。[仕様と配備](docs/material-themes.md)。

2026-10-19：iPhone右端操作列とiPad右下の大型ページボタンをSimulatorで確認し、Vespera/Miraへ更新・起動成功。[画面確認と証跡](docs/unified-reader.md#右端操作の画面確認更新2026-10-19)。

2026-10-19：iPhoneのPDF/画像閲覧を右端の縦操作列へ変更し、上下の操作バー領域を資料表示へ戻した。実機未反映。仕様・検証は[統合ビューアー](docs/unified-reader.md)。

# 現在地

2026-10-10。既存ローカル資料とモック図解ライブラリを維持。Phase 11B-2のPKCE/Keychain・本番設定切替・利用者別保存・URL再取得をローカル実装。署名付きSimulator27テスト合格。接続iPhone更新成功、最終起動は端末Lockedで未確認。AWS公開APIは承認後にデプロイ済み。iOSに公開接続設定を反映、既定モックは維持。本人のメール／owner設定は回答待ち。[適用記録](docs/phase11b2-deployment.md)。実Cognito／実API／iOS実S3・実機操作は未検証。

正本：[検証](docs/phase11b2-validation.md)、[ライブラリ](docs/cloud-library.md)、[README](README.md)。このrepoにAGENTS.mdはなく、diagram-design-system側のAWS承認境界と今回のユーザー指示を適用する。

Phase 11B-3：実Cognito設定・S3公開ブロックを読取確認。本人登録・招待メール送信・owner限定更新が完了。本人の本番ログイン・資料一覧表示成功。本人報告で実機PDF/PNG/PPTXの取得・表示・保存成功。機内モード＋Wi-Fi無効のオフライン閲覧も3形式成功。Phase 11B-3完了。[手順と未実施事項](docs/phase11b3-validation.md)。

2026-10-10：登録資料の容量画面を追加。「その他」から全ライブラリ最新版の件数・成果物容量・取得完了日時を確認・更新できる。既存認証APIを使用し、AWS/API変更なし。Simulatorの29 XCTest合格とサンプル2件・2.4 MBの画面目視を確認。実S3集計・実機更新は未実施。[検証](docs/capacity-validation.md)。

独立一枚図対応：プレゼン資料／図解ライブラリ／ローカル資料の3タブ、オンライン/保存済みtype分類、共通認証を追加。最終31テスト合格、Simulator初期画面目視、既存iPhone Vespera更新/起動成功。本番APIも本人承認後UPDATE_COMPLETE・コードハッシュ一致。本人の新図解表示/拡大操作は確認待ち。[証跡](docs/illustration-validation.md)。

本番設定の誤表示修正：設定済みでも保存ログイン復元失敗を「未設定」と表示する処理を修正。設定/復元を分け、アクティブ復帰時再読取と再試行を追加。32 XCTest・署名build合格。本人の再表示確認待ち。[記録](docs/illustration-validation.md)。

接続準備のままになる続報へ対応：タブごとに共有認証のPublished初期化結果を直接監視するgateへ変更。iOS26の33テスト合格、既存iPhone更新/起動成功。[記録](docs/illustration-validation.md)。

2026-10-10：オンライン閲覧・サムネイルを端末キャッシュ優先へ変更。版別詳細を再利用し、アクティブ復帰で一覧の最新版を確認する。保存済みの旧版は維持。[仕様](docs/cloud-library.md)、[検証](docs/cache-validation.md)。

クラウド資料のゴミ箱移動・復元のUI/APIクライアントをローカル実装。端末保存コピーを保持。本人承認後、本番API/AWSのstate専用権限を反映し、Vespera更新/起動成功。実機移動/復元操作は未確認。[仕様](docs/library-trash.md)。

最新の資料整理：本人の希望でクラウドゴミ箱UIをiPhone内の非表示に切替。非表示/再表示はローカル保存のみ、全版と保存済み一覧へ適用、再起動/キャッシュ削除で維持。既存AWS/APIへの変更なし。[仕様](docs/local-hidden-documents.md)。

端末非表示の検証・反映：39 XCTest、署名build/codesign合格。Vesperaへ更新・起動成功。本人実機の非表示/再表示操作は未確認。

2026-10-10：検索を右上のアイコンへ移動、全て/保存済み切替を廃止し統合一覧へ変更。保存はマーク表示。39 XCTest合格・Simulator一覧目視済み。実機更新と対話操作は未実施。[記録](docs/ui-simplification.md)。

一覧UI簡素化の実機反映：署名build/codesign合格、Vespera更新インストールと更新版起動成功。実機操作は本人確認待ち。[記録](docs/ui-simplification.md)。

2026-10-10：閲覧中央の再生/全画面ボタン、一枚図の縦横比による向き選択を追加。40 XCTest合格・Simulator操作確認。[記録](docs/reader-start-button.md)。

中央開始ボタン版の署名build/codesign合格、Vespera更新/起動成功。実機操作は本人確認待ち。

2026-10-10：図解の端末内「まとめ」を追加。複数資料を1カードに整理し、名前/読む順番の編集・まとめ解除・全画面前後移動・使用ページの一括保存に対応。利用者別の設定を再起動/キャッシュ削除後も保持。AWS/API変更なし。[仕様・検証](docs/diagram-collections.md)。

図解まとめの検証・反映：最終44 XCTestと署名build/codesign合格。Simulatorで作成/順番編集/再起動保持/横画面全画面のページ移動を確認し、Vesperaへ更新・起動成功。本人の実機操作は確認待ち。[証跡](docs/diagram-collections.md)。

2026-10-12：一時コピーのオフライン再起動一覧を追加。取得済み形式だけで開き、通信復帰時は通常一覧へ戻る。確認付きの端末資料一括削除を追加。AWS変更なし。[検証](docs/offline-copies-validation.md)。

端末コピー改善版：2026-10-12本人依頼でVesperaへ署名更新インストール・起動成功。本人の操作確認は未実施。[証跡](docs/offline-copies-validation.md)。

2026-10-12：認証エラーとその他メニューから直接再ログインできる導線、成功後の一覧再読込、タブ選択状態の明示保持を追加。端末コピーは保持。Simulator 46 XCTest合格。実認証・タブの実機確認と実機更新は未実施。[記録](docs/reauthentication-validation.md)。

実機反映（2026-10-12 JST）：本人のデプロイ依頼後、既存Teamで署名Debug buildとcodesign検証合格。Vesperaへ同Bundle IDで更新インストールし、10:49 JSTに既存プロセス終了・更新版起動成功。端末資料の削除やアンインストールなし。本人の再ログイン/タブ操作確認は未実施。証跡：outputs/reauthentication/device-{build,install,launch}.log。

2026-10-13：プレゼン中の透過縦一覧・下中央ページ数・下寄りページ送り・透過終了ボタンを実装。Windowsのproject整合性検査合格。iOSビルド/実機確認は未実施。[仕様・検証](docs/presentation-overlay.md)。

2026-10-13：横向き標準。起動時に横向きを要求し、通常画面は縦・左右横へ回転可能。プレゼン終了/閲覧終了は横向きへ戻して回転を許可。縦長図解の全画面は既存の縦向き選択を維持。Windows構造検査のみ、iOSビルド/実機更新は未実施。

2026-10-13：資料カードは端末の保存/キャッシュ版を優先し、新版がある場合だけ「更新あり」から取得。通常の保存状態マークを除去。[仕様・検証範囲](docs/local-update-notice.md)。Windows構造検査合格、iOSビルド/実機反映は未実施。

2026-10-13：iPhone横向き一覧を基本3列に統一し、表紙の余白を縮小。狭幅/アクセシビリティ文字は2列、縦向き/iPadは維持。Windows構造検査合格、iOSビルド/実機更新は未実施。[仕様](docs/landscape-library.md)。

2026-10-13：資料ごとの仕事／私用／その他と自由タグ編集、上部切替・絞り込みを追加。利用者別端末保存、全版共有。Windows構造検査のみ、iOSビルド・XCTest・実機反映は未実施。[仕様・検証](docs/library-classification.md)。

2026-10-14：最新mainのVespera更新・起動成功。LibraryViewの並行処理コンパイルエラーを最小修正。署名build/codesignとSimulator49 XCTest合格。実機操作は未確認。[記録](docs/vespera-install-20261014.md)。

2026-10-14：iPhone一覧の常設分類/タブを左下の引き出しへ集約。プレゼンの一覧と下操作を本文から分離。Simulator49 XCTestとbuild合格、横向きPNGの目視確認。実機反映は未実施。[仕様・検証](docs/library-sidebar.md)。

同UIの実機反映：本人依頼後、Vesperaの署名build/codesign・更新インストール・更新版起動成功。実機の操作感は本人確認待ち。[記録](docs/library-sidebar.md)。

2026-10-14追加改修：一覧入口を右下48pt丸ボタンへ変更し、右から左へパネル展開。資料閲覧のタイトルバーを除去し、資料名/形式/保存/閉じるを右パネルへ配置。最終Simulator/Device build・codesign、横向き目視、Vespera更新インストール成功。[記録](docs/library-sidebar.md)。

追加改修版の実機起動：端末ロック（Locked）で起動要求が拒否された。更新インストールは成功。ロック解除後の起動・操作確認は未完了。

2026-10-14：再生アイコンを除去しPNG/PDFのタップ開始へ変更。下操作行を除去、左上ページ数/右上終了/左右中央前後・横スワイプを実装。両形式のSimulator目視と最終build/codesign合格、Vespera更新インストール成功。[記録](docs/library-sidebar.md)。

タップ開始/左右操作版：Vesperaの更新版起動成功。実機の操作確認は本人確認待ち。

2026-10-14：iPhoneアプリ全体を左右の横向き専用へ変更。起動/復帰と縦長図解/閲覧終了の方向を統一。[仕様・検証](docs/iphone-landscape-only.md)。

横向き専用版の実機反映：2026-10-14 JST、Vesperaへ署名build/codesign・更新インストール・更新版起動成功。実機操作は本人確認待ち。[記録](docs/iphone-landscape-only.md)。

2026-10-14：右メニュー幅を260ptへ縮小、iPhoneの資料を閉じる操作を外出し。通常閲覧は左上、全画面は右上×で直接閉じる。実機build/codesign・Vespera更新/起動成功。本人操作確認待ち。[記録](docs/library-sidebar.md)。

2026-10-15：保存料金シミュレーションを追加。既存最新版容量と手入力、単価/為替/税率、利用者別の容量・料金履歴グラフに対応。旧版を含むS3総量の自動取得は未対応。AWS変更なし。[仕様・検証](docs/storage-cost-simulator.md)。

保存料金シミュレーションの実機反映：2026-10-15、既存署名build/codesign・Vespera更新インストール・更新版起動成功。実機の画面操作は未確認。[記録](docs/storage-cost-simulator.md)。

2026-10-15：iOS内の20MB制限で2040年40ページ資料が開けない問題を修正。承認済みID/版/ファイルサイズ/SHA256の原本PDF/PPTXだけ許可し、他資料の制限を維持。53 XCTest（実29.64MB PDFの保存/40ページ/オフライン再表示含む）・実機署名build合格。[仕様・検証](docs/large-presentation-size-fix.md)。

同修正版をVesperaへ更新・起動成功。端末内資料と認証情報を保持。本人の今回資料の表示確認は待機。[記録](docs/large-presentation-size-fix.md)。

2026-10-17：一覧末尾の自動追加、一覧キャッシュの先行復元、認証復元失敗時の端末コピー閲覧、共通5GB一時キャッシュ整理を追加。[仕様・検証](docs/incremental-library.md)。最終検証結果は同文書を参照。

スクロール読込版の実機反映（2026-10-17 JST）：本人依頼後、Vesperaへ署名build/codesign検証・更新インストール・更新版起動成功。実機操作は本人確認待ち。[記録](docs/incremental-library.md)。

2026-10-17：整理の共有SwiftパッケージLibraryOrganizationを隣接diagram-design-system/packagesから参照。分類/タグ/まとめのデータ型をtypealiasへ移し、既存JSON・利用者分離・まとめの閲覧動作を維持。同期・フォルダUI追加・実機配布は今回なし。詳細はdocs/shared-organization.md。

2026-10-17：共有整理パッケージを使い、クラウド資料の本棚フォルダ（全て/未整理/階層）と複数選択一括移動を追加。タグ/まとめ/保存済みは既存のまま、利用者別organization.jsonのみ追加。同期/ローカル外部資料タブは変更なし。操作・検証はdocs/library-folders.md。実機配布なし。

フォルダ整理版の実機反映（2026-10-17 22:03 JST）：本人依頼でVesperaへ既存署名/同Bundle IDの上書き更新・起動成功。アンインストール/保存資料削除なし。実機のフォルダ操作と既存資料の表示は本人確認待ち。[記録](docs/library-folders.md)。

2026-10-17：同期の検証画面を共有LibraryOrganizationUIから接続。初回統合・状態・競合解決・再試行は別の検証コピーに限定し、元の設定へ書戻さない。iOS60 XCTest合格、HTTP共通セッション成功。新画面の実タップはツール接続タイムアウトで未確認。実機配布/AWS変更なし。[操作](docs/local-sync-ui.md)。

2026-10-17：Simulatorサンプルの明示テスト起動時だけ、通常画面の整理保存と同期受信を接続。Macとのフォルダ/所属/タグ往復を実画面で確認、62テスト合格。反映ジャーナル/初回バックアップで旧3JSONを保持。実データ/実機/AWSへの適用なし。[仕様](docs/local-sync-ui.md)。

2026-10-17：テスト本棚に管理JSONだけの接続前バックアップ/統合件数と競合確認/画面から同期停止して復元を追加。資料本体は対象外。64テストとSimulator実操作で失敗後の元JSON完全復元を確認。実機/既存データ/AWS未変更。AWS変更前は必ず料金試算。[仕様](docs/local-sync-ui.md)。

テスト本棚の同期に全端末合計5回/時・待ち時刻・同意した1回だけ追加を接続。上限中の編集を保持し、再起動/切断/管理復元で台帳をリセットしない。64テストとSimulator実画面を確認。AWS/本番/実機未変更。[仕様](docs/local-sync-ui.md)。

認証付き整理同期HTTPS（2026-10-18、テストのみ）：既存CloudOIDC/Keychainから同じ利用者のBearerを提供し、必要時の専用scopeログインとsilent refreshを追加。共通bootstrap/50操作＋実JSONバイト上限/部分ACK後の永続再送を、明示的なSimulatorテスト本棚への接続注入で利用する。通常起動/既存ログイン/実機/AWSは未変更。[仕様](docs/local-sync-ui.md)。

2026-10-18：整理同期の準備画面を追加。既存CloudOIDCで追加scopeのログイン成功後にバックアップ/統合確認へ進む導線を実装。Bundleの明示有効化がない現行ビルドは準備中・通信なし。追加scope取得時は画面を再生成せず、失敗/キャンセルでは古いtokenで接続しない。Simulator66テスト合格、CUAは接続timeoutで新画面未操作。実機/AWS/既存本棚は未変更。[詳細](docs/local-sync-ui.md)。

2026-10-18：通常の整理同期接続を有効化し、Vesperaへ更新インストール成功。利用者別の通常organization-sync領域と単一キューを2つのクラウド画面で共有し、受信/復元後に両画面を再読込する。Simulator67テスト合格。実機の分類・まとめは更新前後バイト一致（分類1/自由タグ0/まとめ2・18資料参照）。2026-10-19 0:01、本人ログイン/自動管理バックアップ/受信3送信3・変更解除競合0の確認後、実機初回同期とMacへの往復反映まで成功（両端末版9/待ち0/競合0）。既存情報を保持し、両端末のフォルダ/所属/順序・分類1・まとめ2/18参照の一致を確認。AWS構成変更なし。[接続手順と状態](docs/local-sync-ui.md#通常実機の接続2026-10-18)。

2026-10-19：iPadの広幅本棚へ左フォルダ／検索／分類パネル、compact幅・大文字時の引き出し、横スクロール選択操作、閲覧のcompactメニューを追加。iPadの起動／閲覧時の強制回転を解除。iPad Simulator67 XCTest・generic iOS build合格、縦横の本棚／PNG閲覧／整理操作／大文字を目視確認。実ウィンドウ縮小と実iPadは未確認。[仕様・検証](docs/ipad-layout.md)。

2026-10-19：常設フォルダ/薄い本棚バー/一行検索を元repoへ適用。既存署名build・codesignとVesperaへの上書き更新/起動成功。共通ゴミ箱は準備中で無効、AWS変更なし。[反映と検証](docs/mobile-bookshelf-deployment.md)。

同版の最終検証：arm64 iPhone 17e/iOS 26.5 Simulatorで68 XCTest・失敗0。画面読み取りで新しい本棚構造を確認。画像目視は画面ツールtimeoutで未完了。Vesperaの更新版起動成功、本人による実機操作確認待ち。

2026-10-19：iPad Miraへ端末指定署名build・インストール・起動成功。本人が本棚／本番ログイン／実資料一覧を確認。閲覧・回転・オフライン確認は継続中。[検証](docs/ipad-layout.md#miraへの実機反映2026-10-19)。

2026-10-19：表紙PNGだけを閲覧一覧と見なしてPDF/残りPNGを隠す不具合を修正。オンラインは全manifest、オフラインのみ取得済みに限定。69 XCTest合格、iPad SimulatorでPDF表示・形式切替・PNGスワイプ2枚目/次ボタン3枚目を確認。[原因・検証](docs/reader-cover-cache-fix.md)。

2026-10-19：iPhone/iPadのPDF・PNG閲覧を統合。開くと単ページ、タップで操作切替、スワイプでページ送り、拡大中はパンを優先。両Simulatorで各71 XCTestと実操作確認後に実機反映。[操作・検証](docs/unified-reader.md)。

統合ビューアーの実機反映：10:14 JST、Mira/Vesperaとも上書き更新・更新版起動成功。両Simulator確認後に反映し、認証/保存資料を保持。実機操作は本人確認待ち。[記録](docs/unified-reader.md#実機反映)。
