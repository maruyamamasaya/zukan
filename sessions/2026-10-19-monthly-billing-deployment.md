# 今月のAWS費用：配備と反映待ち

Request：本人承認後AWSへ適用し、確認成功後iOSへ反映。実機確認はiPad Miraだけ。
Changes：隣接repoで無効flagのコード/IAM/固定S3 cacheを配備し、Project配賦タグActive。iOS署名device build/codesign成功。
Validation：CEのGetTagsでは図鑑の値がまだ空。0円と判断せず、有料金額照会とiOS更新を保留。既存の実機bundleを変更しない。
Result：サーバー基盤の配備はUPDATE_COMPLETE。費用取得/実機反映は未完了。8時間おき最大4回の自動継続は、自動化の明示承認がないとして自動承認レビューに拒否され、作成していない。
Remaining：タグ反映→本番費用と共有cache検証→成功後iOS反映/起動、Miraのみで実機確認。詳細は隣接repo sessions/2026-10-19-monthly-billing-deployment.md。

続報：本人が自動化を明示承認。aws-ipad heartbeatを8時間間隔/最大4回で作成し、反映後のAWS有効化・Mira更新/確認を継続するよう設定済み。

## 初回を即時確認

本人指示で初回確認を手動実行。2026-10-19T05:56:30.665164+00:00時点も図鑑タグ値は空。1/4回消化、管理照会6/10要求、有料金額照会0。AWS有効化/iPad更新は行わず、残り3回を8時間おきの自動確認へ変更した。
