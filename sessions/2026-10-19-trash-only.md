# 非表示を廃止し共通ゴミ箱へ統一

本人指定でカード/管理メニュー/確認ダイアログと非表示一覧状態を撤去。旧非表示資料は一覧候補/まとめへ戻す。旧JSONの互換保持、lifecycleによるゴミ箱/削除中除外を維持。AWS/API変更なし。検証と実機結果はdocs/local-hidden-documents.mdへ追記する。

署名付きSimulator 52テスト合格、カードメニュー目視、署名build/codesign合格。Vespera/Miraへ更新・起動成功（11:03 JST）。本人実機操作は未確認。
