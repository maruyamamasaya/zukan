# 今月のAWS費用表示（ローカル）

Request：図鑑の費用と共通費を分け、CE取得回数を抑制。AWS変更前に追加費用提示。
Investigation：現画面は容量ベースの保存費だけ。専用認証API/共有7日cacheを利用する設計。
Changes：CloudLibraryAPI.monthlyBilling、HTTPS専用endpoint、Decimal/総額/期間検証、今月の費用と共通未配賦・分類内訳・元明細・取得日時/次回日時を表示。Mockへ偽の請求額は追加しない。USD計上値と150円/USD参考換算、追加税なし、保存費目安と合算なし。
Files Changed：CloudAPI.swift、CloudLibraryView.swift、CloudLibraryTests.swift、README/CURRENT/仕様。
Validation：arm64 iPhone17e iOS26.5 Simulator74 XCTest合格。最終関連テストは追記。diff --check合格。隣接viewer45合格/1スキップ・型検査成功。
Result：ローカル実装済み。AWS/IAM/タグ適用・実機配布は未実施。隣接repoのdocs/monthly-billing-aws-proposal.mdが追加費用/承認案。
Remaining Issues：本番CE/配賦タグ反映・iPad実画面の確認は承認後。共通未配賦には過去の図鑑分/他用途もあり、図鑑負担と断定しない。

最終追記：最終表示文言を含むビルドと月内費用APIの関連1 XCTestも成功。
