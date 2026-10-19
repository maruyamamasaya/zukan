# 本棚の屋久杉・黒漆テーマ

最新修正（2026-10-19）：初回の名前指定Imageでは素材が出ていないことを共有SwiftUI実描画で再現し、PNGの直接復号へ修正。合成率も調整。iPad/iPhone各72 XCTest成功・両素材をSimulator目視。Mira/Vesperaへ11:07に再更新・起動成功。初回証跡は配色切替までで、素材の検証不足だった。[原因と修正証跡](../../diagram-design-system/docs/bookshelf-material-themes.md#素材が描画されない問題の修正)。

両方ともダーク基調。iPadは「管理」、iPhoneは上部「…」の先頭にある「本棚のテーマ」から切り替える。ローカル資料も上部メニュー／引き出しに対応。初期値は黒漆。選択は端末別に保持し、整理情報へ同期しない。iPhone横向きと資料本来の色を保持する。

共通正本・生成プロンプト・素材保存先・検証は[共有仕様](../../diagram-design-system/docs/bookshelf-material-themes.md)。実装は既存のLibraryOrganizationUIパッケージを使い、Xcodeプロジェクトへの新規ソース登録は不要。

検証：iPad/iPhone Simulator各71 XCTest成功、両テーマ目視、iPhoneのメニュー先頭配置と再起動保持を確認。画像証跡は共有repoの `outputs/material-themes/`。実機配備は共有仕様へ記録。本人の実機評価と大文字/コントラスト増加の目視は未実施。

2026-10-19 10:58 JST、MiraとVesperaへ既存署名/Bundle IDで上書きインストール・起動成功。アンインストールやデータ初期化なし。本人のテーマ選択と質感の確認は待機。
