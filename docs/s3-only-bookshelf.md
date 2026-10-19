> 2026-10-19：本人の追加指示でVespera/MiraへS3専用・共通サイドバー版を更新インストール済み。起動/ログイン/実機操作は本人が後日確認する。元資料・設定は保持。隣接diagram-design-system/sessions/2026-10-19-s3-unified-app-install.mdに反映証跡。

# S3専用本棚とサイドバー整理（実機確認待ち）

2026-10-19本人指示。ローカル資料のタブ/メニューを廃止し、製品は既存のS3認証本棚だけを表示する。サンプル/本番切替も廃止。端末保存/オフラインコピーはS3由来の閲覧用として維持し、旧ローカル原本は削除しない。

本棚の入口を資料種別→すべて/未整理→字下げした階層フォルダ→ゴミ箱→本棚を管理の順に整理。作成/同期/設定は左下へ集約し、上部は検索/絞り込み/選択を中心とする。同期の検証は管理内の詳細へ移す。iPhoneは種類選択を本棚バー、iPadは左本棚に置く。

自動検証72 XCTest失敗0、署名ビルドを作成。実iPhone/iPadの入替・ログイン・S3突合や手操作は本人の希望で後日。詳細は隣接diagram-design-system/docs/s3-only-bookshelf.mdとdocs/unified-bookshelf-sidebar.md。ログは同repo outputs/ios-s3-only-*、ios-unified-sidebar-*、ios-s3-unified-sidebar-device-build.log。AWS構成変更なし。
