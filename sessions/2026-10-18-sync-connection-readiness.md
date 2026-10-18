# 同期接続の準備

Request: 本番接続前の仕上げをまとめて進める。既存データ/AWSは変更しない。
Changes: 共通SyncSetupViewのメニュー導線、既存認証の追加scopeログイン成功後のbinding接続（Bundle明示有効化のみ）。失敗では停止し、追加scope時はシートを保持。
Validation: Simulator66 XCTestと署名ビルド成功。専用CUAは2回timeout、新画面操作/実Cognito/実機は未検証。
Result: 現行は準備中、既定無効。保存済み資料/利用者管理情報/AWS/実機未変更。
Remaining: AWSセッション再認証→ライブ構成差分/料金の確認と承認→実適用→少量の実端末確認。
