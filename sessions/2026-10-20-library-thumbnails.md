# 資料一覧の表紙軽量化

## Request

iPad/iPhoneの一覧のカクつきに対し、表紙縮小・背景処理・画像キャッシュを実装する。

## Investigation

CloudLibraryStoreはMainActor上でUIImage(contentsOfFile:)とPDF表紙生成を行い、CloudCover再表示時の縮小済みメモリキャッシュがなかった。

## Changes / Files Changed

- CloudLibraryStore.swift：ImageIOの長辺640px縮小・即時展開、PDFの比率維持縮小を専用actorで直列実行。ストア別NSCache（80枚/24MiB目安）と端末コピー削除時の世代失効、削除状態確認を追加。
- CloudLibraryView.swift：カードtaskのキャンセル後は結果を反映しない。
- CloudLibraryTests.swift：大きいPNG/PDFの寸法・比率、欠損入力、画像インスタンス再利用、全コピー削除後の失効を検証。
- docs/cloud-library.md：仕様・キャッシュの境界を記載。

## Validation

- iPhone 17 Pro / iOS 26.5 Simulator：ローカル署名で77 XCTest全件合格（失敗0）。
- iPad Pro 11-inch M5 / iOS 26.5 Simulator：ローカル署名で77 XCTest全件合格（失敗0）。
- 新規試験2件：大きいPNG/PDFの縮小・縦横比/欠損入力、端末コピー削除後の失効と再取得。既存試験に画像インスタンス再利用の検査を追加。
- ログ：/private/tmp/zukan-thumbnail-tests-signed.log、/private/tmp/zukan-thumbnail-ipad-tests-signed.log。両方 **TEST SUCCEEDED**。
- 初回の署名なし実行は既存Keychain試験2件で3 assertion失敗。ローカル署名の再実行で全件合格。最初のSDK未指定実行もターゲット不一致で失敗し、-sdk iphonesimulatorを明示して解消。
- python3 tools/verify_project.py は既存の共有Swiftパッケージを「Unexpected package dependency」として拒否するため失敗。検査は変更せず、Xcode実ビルド/全件試験と区別する。
- 両repoのgit diff --check合格。diagram-design-systemのnpm run verify -- docsは247文書のリンク先検査とdiff検査合格。

## Result / Remaining Issues

実機スクロールの比較は未実施。初回取得時の原本通信量、表紙以外の一覧計算は今回の対象外。AWS変更なし。

## 実機反映（本人依頼、2026-10-20 JST）

既存Team U29GY347DY/Bundle ID com.example.PresentationViewerでRelease実機ビルド成功。macOS証明書信頼情報へアクセスできる環境でcodesign --verify --deep --strict合格（sandbox内検証はCSSMERR_TP_NOT_TRUSTED）。Mira（iPad Pro 12.9第4世代）/Vespera（iPhone 17e）へ上書きインストール成功、各01:10:58/01:11:07に更新版起動成功。アンインストール・保存データ初期化なし。本人のスクロール操作と速度比較は未確認。

証跡：/private/tmp/zukan-thumbnail-device-build.log、/private/tmp/zukan-thumbnail-{mira,vespera}-{install,launch}.log。実機ビルド成果物：/private/tmp/zukan-thumbnail-device/Build/Products/Release-iphoneos/PresentationViewer.app。
