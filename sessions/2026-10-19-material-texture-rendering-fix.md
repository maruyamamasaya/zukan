# 素材が出ない問題の修正

本人指摘で共有UIの名前指定Imageが素材を描画しない問題を再現。PNGをUIImageへ直接復号し、original表示と素材別キャッシュへ変更。旧下地だけの結果と修正後の画素変動を比較し、素材の画素検査を共有repoへ追加。

iPad/iPhone各72 XCTest成功、両Simulatorで屋久杉/黒漆の実表示確認。既存Team/Bundle IDで署名build・codesign検証後、Mira/Vesperaへ11:07に上書き更新・起動成功。資料/認証/整理情報の初期化なし。先行のゴミ箱などの変更を保持。[正本と証跡](../../diagram-design-system/docs/bookshelf-material-themes.md#素材が描画されない問題の修正)。本人の実機評価は未確認。
