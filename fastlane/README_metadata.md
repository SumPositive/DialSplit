# App Store メタデータの更新手順（DialSplit）

説明文（description）とプロモーションテキスト（promotional_text）を
**8言語**まとめて App Store Connect に反映するための fastlane 設定です。

- 対象アプリ: `com.azukid.AzSplitIt`（App ID `467941202`）
- 更新される項目: `description` と `promotional_text` のみ
  （キーワード・スクショ・価格・バイナリは触りません）

対応ロケール（App Store Connect のコード）:
`ja` / `en-US` / `de-DE` / `es-ES` / `fr-FR` / `it` / `ko` / `zh-Hant`

各テキストは `fastlane/metadata/<locale>/description.txt` と
`fastlane/metadata/<locale>/promotional_text.txt` にあります。編集すればそのまま反映対象になります。

---

## 1. 準備（初回のみ）

### 1-1. fastlane をインストール
```bash
cd /Users/sumpositive/GitLocal/DialSplit
# Bundler 経由（推奨）
gem install bundler
bundle install
```
（`bundle install` がうまくいかない場合は `brew install fastlane` でも可）

### 1-2. App Store Connect API キー（.p8）を発行
App Store Connect → **ユーザーとアクセス** → **統合（Integrations）** → **App Store Connect API**
→ **キーを生成**（ロールは `App Manager` 以上）

発行時に以下を控える／保存する:
- **Key ID**（例: `ABC123DEFG`）
- **Issuer ID**（UUID）
- **AuthKey_XXXX.p8**（ダウンロードは1回だけ。再取得不可）

`.p8` は `fastlane/` 直下に置くと `.gitignore` 済みで安全です:
```bash
mv ~/Downloads/AuthKey_ABC123DEFG.p8 fastlane/
```

> ⚠️ `.p8` は秘密鍵です。Git にコミットしない・第三者に渡さないこと。
> （`.gitignore` に `*.p8` を追加済みですが念のため確認してください）

---

## 2. 実行

環境変数で API キーを渡します（毎回のセッションで設定）:
```bash
export ASC_KEY_ID="ABC123DEFG"
export ASC_ISSUER_ID="00000000-0000-0000-0000-000000000000"
export ASC_KEY_PATH="./fastlane/AuthKey_ABC123DEFG.p8"
```

### 2-1. まず内容確認（送信しない dry-run）
```bash
bundle exec fastlane preview_metadata
```
`verify_only` で検証のみ行い、実際の変更は送信されません。

### 2-2. 反映（審査提出はしない）
```bash
bundle exec fastlane upload_metadata
```
`submit_for_review: false` なので、メタデータが保存されるだけで**審査には出ません**。
App Store Connect 画面で確認し、問題なければ手動で審査提出、または次回アプリ更新時に一緒に提出されます。

> `bundle exec` を付けない場合は素の `fastlane preview_metadata` でも動きます。

---

## 3. テキストを直したいとき

該当ファイルを編集して、再度 `upload_metadata` を実行するだけです:
```
fastlane/metadata/<locale>/description.txt
fastlane/metadata/<locale>/promotional_text.txt
```

文字数の目安（App Store の上限）:
- description: 4000 文字
- promotional_text: **170 文字**（今回の各言語は全て収めてあります）

---

## 4. 補足

- `deliver` は「置いてあるファイルの項目だけ」を更新します。keywords.txt などを
  置いていないので、既存のキーワード等は上書きされません。
- 韓国語・繁体字の説明文はアプリ名を `割勘(DialSplit)` と併記しています。
  App Store 上の「App名」設定に合わせ、不要なら各 description.txt の先頭を調整してください。
- プリセット訳語（大富豪/社長/金/特上 など）はアプリ内ローカライズ
  （`preset.name.*`）と一致させています。
