# iPhone資料領域拡大

本人の「文字が読めるよう資料を広げ、タイトル・左右・ページ数を別の場所へ」に対応。DocumentViewerをiPhoneだけ右端60ptの操作列へ変更。CloudLibraryViewの保存/形式を縦配置に対応。iPad/PPTXの既存配置維持。先行未コミット変更を保持。

検証：git diff --check合格。旧verify_project.pyは既存の共有Swift packageを禁止するため失敗（今回依存追加なし）。Xcodeビルド結果はdocs/unified-reader.mdに追記。画面操作・実機反映は未実施。

本人の画面確認/実機反映依頼を受け、Simulatorで確認。追加依頼でiPadを右下の64×52ptボタンへ変更。両実機へ同Team/Bundle ID更新・起動成功。詳細はdocs/unified-reader.md。
