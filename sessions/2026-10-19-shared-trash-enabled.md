# 共通ゴミ箱有効化

本人承認後、本番APIの合成資料移動/復元/全削除と既存資料保持を確認。LibraryLifecycleEnabled=true、HTTPSのみsupportsLifecycle=true。デモ接続が同期APIを要求して一覧が空になる回帰を修正。71 XCTest失敗0、署名build/codesign、Vesperaへの既存アプリ更新・起動に成功。Macも更新/共通通知受信を確認。制作原本は削除しない。詳細はdocs/mobile-bookshelf-deployment.mdと隣接diagram-design-system/docs/shared-trash-deployment.md。
