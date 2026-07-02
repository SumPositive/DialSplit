fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios preview_metadata

```sh
[bundle exec] fastlane ios preview_metadata
```

説明文・プロモーションテキストの差分を確認する（force: false なので送信前に確認プロンプトで停止）

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

説明文・プロモーションテキストを App Store Connect に反映する（審査提出はしない）

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
