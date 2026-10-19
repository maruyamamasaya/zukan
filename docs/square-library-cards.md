# 正方形の資料カード

2026-10-19。クラウド資料・図解のまとめ・ローカル資料でSquareLibraryCardを共用。カード全体の縦横比を1:1、余白12ptで統一する。タイトルは最大2行、短い場合も2行分を確保し、長い場合は末尾を省略。サムネイルは残り領域に全体表示し、画像自体は切り抜かない。補足（ページ数/形式）は1行。元タイトルとアクセシビリティの全文ラベルは保持する。

DocumentTile.swiftの共通枠をCloudLibraryView.swiftのCloudCoverでも使用する。画面ごとに既存グリッドの列幅へ適応するため、端末間の絶対ptサイズを同一に固定する仕様ではなく、同一グリッド内で正方形サイズを統一する。

iPad Simulator72 XCTest・失敗0、署名build/codesign成功。iPhone/iPad両Simulator画面で正方形とタイトル配置を確認。Vespera/Miraへ既存bundleを更新・起動。ログと画像は隣接diagram-design-system/outputs/のios-square-card-*、square-card-*。最大文字サイズや非常に狭いSplit Viewは追加確認対象。
