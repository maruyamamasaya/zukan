# 常設フォルダ本棚の実機反映（2026-10-19）

選択されたスマホ横向き案を元のzukanへ反映。上部の本棚/種別切替・現在フォルダ・件数・検索/選択/管理と、左側のすべて/未整理/階層フォルダ/ゴミ箱を配置する。検索は一行で開き、取得済み資料を絞り込む。既存の分類・タグ・まとめ・非表示・閲覧と整理同期を保持する。

## 反映と検証

通常実行は引き続きEPERMだったが、本人の元repo反映/実機確認の明示依頼を根拠に、承認付き実行で検証済み差分を適用した。アプリ側の設定の再変更は行っていない。余分な末尾空白1か所を適用時に修正。

- 元repoのgit diff --check合格。
- 既存Team/Bundle IDの署名付き実機Debug buildとcodesign --verify --deep --strict合格。
- 既存iPhone Vesperaへ同Bundle IDで上書きインストール成功、更新版の起動成功（2026-10-19 09:39 JST）。アンインストールや端末内資料の削除はしていない。
- Simulatorの最初の試行はx86_64/arm64の依存module混在でビルド失敗。arm64を明示した再試行で68 XCTest・失敗0、TEST SUCCEEDED。追加した端末コピーの復元/完全削除/再生成防止も合格。
- Simulatorの画面読み取りで本棚バー・種別/現在地/件数・検索/選択/管理・常設フォルダ・ゴミ箱入口を確認。スクリーンショット取得と後続の画面操作ツールはtimeoutReachedで不成立のため、画像での目視評価は未完了。実機の画面操作/表示品質は本人確認待ち。

ログは /private/tmp/zukan-bookshelf-device-{build,install,launch}.log と /private/tmp/zukan-bookshelf-simulator-tests.log。署名済みappは /private/tmp/zukan-bookshelf-device/Build/Products/Debug-iphoneos/PresentationViewer.app。

## 共通ゴミ箱の境界

共通モデル/APIクライアント/削除確認と端末コピーの削除通知処理も反映したが、BundleのLibraryLifecycleEnabledは既定無効のまま。ゴミ箱はサーバー反映待ちを表示する。S3完全削除と端末間のゴミ箱操作は今回有効化していない。AWS/本番APIを変更していない。

本番有効化前の残件は、隣接diagram-design-system/docs/shared-library-trash.mdを正とする。制作原本は自動削除の対象外。
