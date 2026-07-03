# App Store スクリーンショットの自動撮影・アップロード（DialSplit）

`fastlane snapshot` でシミュレータからスクショを自動撮影し、`deliver` でアップロードします。
**まずは「メイン画面 1 カット × ja/en-US × iPhone 16 Pro Max」で仕組みを検証**し、
動いたら言語・デバイス・カットを増やす方針です。

---

## ステップ 0: 用意済みファイル

Claude が以下を用意済みです:

- `fastlane/uitest/SnapshotHelper.swift` … fastlane 公式ヘルパー（撮影処理）
- `fastlane/uitest/DialSplitUITests.swift` … 撮影用 UI テスト（今は 1 カット）
- `fastlane/Snapfile` … 撮影対象の言語・デバイス設定（検証用に絞ってある）
- `fastlane/Fastfile` … レーン `screenshots` / `upload_screenshots` / `screenshots_and_upload` を追加済み

`fastlane/uitest/` の 2 つの .swift は「置き場所」です。次のステップで Xcode の
UITest ターゲットに取り込みます。

---

## ステップ 1: Xcode で UITest ターゲットを追加（← これだけ手動 GUI 操作）

fastlane snapshot には UITest ターゲットが必須です。Xcode でないと追加できません。

1. `DialSplit.xcodeproj` を Xcode で開く
2. メニュー **File > New > Target…**
3. **UI Testing Bundle** を選択 → Next
4. 設定:
   - Product Name: **`DialSplitUITests`**
   - Target to be Tested: **DialSplit**
   - Language: Swift
   - → Finish
5. 自動生成された `DialSplitUITests/DialSplitUITests.swift`（雛形）を、
   Claude が用意した `fastlane/uitest/DialSplitUITests.swift` の内容で置き換える
   （Finder で中身をコピペするか、Xcode 上でファイル内容を貼り替え）
6. `fastlane/uitest/SnapshotHelper.swift` を Xcode にドラッグして
   **DialSplitUITests ターゲットにのみ**追加する（Target Membership を UITest だけにチェック）

> ヒント: SnapshotHelper.swift はアプリ本体ターゲットには入れないこと（UITest 専用）。

---

## ステップ 2: スキーム設定（テストを共有可能に）

fastlane はスキーム経由で UITest を実行します。

1. Xcode の **Product > Scheme > Manage Schemes…**
2. `DialSplit` スキームの **Shared** にチェックが入っていることを確認
3. **Edit Scheme… > Test** タブで、`DialSplitUITests` がテスト対象に含まれていることを確認

（別スキームを作る場合は、`fastlane/Snapfile` の `scheme("DialSplit")` をその名前に変更）

---

## ステップ 3: 撮影して確認（アップロードしない）

```bash
cd /Users/sumpositive/GitLocal/DialSplit
fastlane screenshots
```

- 初回はシミュレータのビルド＆起動で数分かかる
- 成功すると `fastlane/screenshots/` に言語別フォルダ＋PNG が出力され、
  一覧 HTML（`screenshots.html`）が開く
- ja と en-US で「01MainScreen」が撮れていれば検証成功 🎉

うまくいかない場合の主な原因:
- シミュレータ名が違う → `Snapfile` の `devices([...])` を、
  `xcrun simctl list devices` に出る名前に合わせる
- UITest ターゲット名やスキームが違う → `Snapfile` の `scheme` を修正

---

## ステップ 4: カット・言語・デバイスを増やす（検証OK後）

- **カット追加**: `DialSplitUITests.swift` の `testTakeScreenshots` 内に、
  画面遷移の操作 + `snapshot("02Settings")` のように追記
  （設定画面を開くボタンのタップ等。要素特定にはアクセシビリティ識別子があると安定）
- **言語・デバイス**: `Snapfile` の「本番フェーズ」ブロックをコメント解除し、
  検証用の `devices`/`languages` と差し替え（8 言語＝ ja, en-US, de-DE, es-ES, fr-FR, it, ko, zh-Hant）

---

## ステップ 5: アップロード（審査提出はしない）

撮影済みの `fastlane/screenshots/` を反映:

```bash
cd /Users/sumpositive/GitLocal/DialSplit
fastlane upload_screenshots
```

撮影とアップロードを一気に行うなら:

```bash
fastlane screenshots_and_upload
```

- API キー認証（`.env` の ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH）はメタデータ更新と共通
- `skip_metadata: true` なので説明文等には触らない／スクショだけ差し替え
- `submit_for_review: false` なので審査には出ない

---

## 注意

- **スクショの必須サイズは iPhone 6.9"（iPhone 16 Pro Max 等）**。ここが埋まっていれば
  他サイズは自動流用される場合が多い（App Store Connect の仕様に従う）。
- スクショも、配信済みバージョンでは差し替え可否がストア状態に依存することがある。
  エラーが出たら状態（準備中／配信済み）を確認。
- 端末フレームやキャッチコピーを載せたい場合は `frameit` を別途組み込む
  （今回は素のスクショから開始）。
