# S3保存容量と月額費用

Request：手入力を廃止し実S3保存量から保存費を表示。
Investigation：既存最新版metadata集計では旧版/ゴミ箱/管理ファイルが抜ける。
Changes：CloudLibraryAPIにcapacity要件、HTTPSCloudAPIは認証付きv1/storage-capacityを利用。画面初回取得、全手入力廃止、固定参考条件、全版件数/削除マーカー/日時。履歴をs3-storage-cost-history.jsonへ分離し同取得日時重複を防止。既存履歴は保持。
Files Changed：CloudAPI.swift、CloudFiles.swift、CloudLibraryView.swift、CloudLibraryTests.swift、README/CURRENT/仕様。
Validation：iPhone17e iOS26.5 arm64 Simulatorで73 XCTest成功。最終履歴重複変更後の関連2テスト結果は追記。diff --check合格。隣接viewer35合格/1スキップ・型検査成功。URLProtocolのモック検証は実S3取得ではない。
Result：ローカル実装済み、API本番配備/実機更新/画面目視は未実施。隣接diagram-design-systemのdocs/s3-storage-capacity-aws-proposal.mdで料金・IAM/code変更を提示し承認待ち。
Remaining Issues：未完了multipart除外、参考為替150円/USD/税10%・東京Standard 0.025 USD/GiB月の固定条件。実請求ではない。

最終追記：履歴の同取得日時重複防止を含む関連2 XCTestも成功。

本人承認後の本番適用・端末反映は[続きの記録](2026-10-19-s3-storage-capacity-deployment.md)で完了。
