# 資料取得障害の復旧と10GBキャッシュ

## Request

Mac/iOSの取得失敗の原因特定・修正・実機更新・実取得確認、両アプリ10GB保持、今後の保存/API不整合防止。AWSは内容と料金提示後に本人が適用を明示承認。

## Investigation

本人認証200に対し本番catalog/lifecycleは409 INVALID_MANIFEST。美術史v3のslide-NNNパスと43.8MB PDF/30.1MB PPTXの限定承認が本番API未反映で全件を停止。S3保存自体は成功。隣接repoの修復で53資料/警告0・状態200へ復旧。

## Changes / Files Changed

CloudModelsの2パス形式対応/共通限定承認、CloudAPIの401更新・429/5xx/通信失敗の限定再試行、CloudLibraryStoreの詳細キャッシュ優先/本文一時失敗復帰/隔離件数通知。CloudFilesは10GB、Application Supportへ旧キャッシュを引き継ぎ・バックアップ除外、資料/版単位LRUで詳細と本文を保持。既存のサムネイル修正を保持。

## Validation

最終Simulator結果・実機配布は以下へ追記。本人ログインの実機限定testLiveProductionReadAndOfflineReopenはMira/Vesperaの両方で合格。実アプリのHTTPS/API/S3とSHA256/PDFKitで美術史22ページ・リフキン1ページを取得し、OfflineAPIで同じファイルを再表示した。通常試験ではライブ検証をスキップする。本人データ/認証情報を初期化せず、検証用一時領域だけを使用した。

## Result / Remaining Issues

全53資料の全形式を全端末で開いた検証ではない。資料のフォルダ所属は取得・保存と別で、新規資料を自動分類しない。AWS変更の正本・具体的な証跡は隣接diagram-design-system/sessions/2026-10-20-library-fetch-stability.md。

## 最終確認と追加の分類修正

iPhone/iPad Simulator各82 XCTest・1スキップ・失敗0。APIの401→429→成功で更新1回、S3一時失敗→再取得→キャッシュ再利用を確認。iPad内部親の通常フォルダ列挙・親選択時の未整理欠落・空の移動先を修正し、種類の入口と分類先を分離。新規分類先作成と選択資料移動を同じ管理保存で実施し、再起動後の保持も合格。共通Swift50合格。通常Release署名buildとMira/Vesperaの上書き更新・起動成功。両実機のApplication SupportにDiagramLibraryCacheが存在することを読取確認した。

Vesperaの最終追加再試験は自動ロックで待機したため停止。先行の実取得/PDF描画/通信なし再表示の合格と、最新全件Simulator合格を分けて記録する。実機描画添付は隣接repo outputs/fetch-stability/{mira,vespera}-attachments。本人のフォルダを検証用に変更していない。

最終通常起動：Miraは01:58 JST、Vesperaは本人の再ロック解除後02:01 JSTに起動成功を確認。フォルダ修正込み最終配布後のVespera起動は、先行したロック拒否と区別する。
