# S3保存容量と月額費用

2026-10-19。旧「保存料金シミュレーション」の容量/料金手入力を廃止。画面初回と更新ボタンで認証付き GET /v1/storage-capacity を取得。HTTPSCloudAPIのprotocol要件として実装し、旧metadata集計に代用しない。

専用S3全版・旧版・ゴミ箱・管理ファイルと削除マーカーの保存byteを合算。未完了multipartを除く。固定参考条件：東京Standard 0.025 USD/GiB月、150円/USD・税10%、50 TiBまで。Standard以外/不明や上限超過は容量のみ表示。実請求ではなく現在容量を1か月保持した場合の保存費。通信/API/認証等を含まない。

利用者別s3-storage-cost-history.jsonに取得時容量/料金/日時を最大365回保存。旧storage-cost-history.jsonは保持し混在させない。取得失敗は前回値/日時を維持。初回失敗は取得不能と案内。サンプルは実S3ではないと表示する。

サーバー実装は隣接diagram-design-systemのviewer/src/lib/storage-capacity.ts。詳細・料金・権限承認案は同repoのdocs/s3-storage-capacity.mdとdocs/s3-storage-capacity-aws-proposal.md。2026-10-19本人承認後、本番API/IAM適用・本人認証GETとS3 CLI全版容量一致を確認。Vespera/Miraへ署名版の更新インストール・起動成功。実画面目視/手操作は未確認。実行結果はsessions/2026-10-19-s3-storage-capacity.md。

本番実測は593,772,472 bytes / 852オブジェクト版 / 削除マーカー0 / Standardのみ、保存費目安約2.28円/月。隣接repoのsessions/2026-10-19-s3-storage-capacity-deployment.mdに適用証跡。
