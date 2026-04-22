# DialSplit

A skeuomorphic bill-splitting calculator for iOS, built with SwiftUI.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)

## User Guide

- [English](https://azukid.com/en/sumpo/DialSplit/dialsplit.html)
- [日本語](https://azukid.com/jp/sumpo/DialSplit/dialsplit.html)

## Overview

DialSplit splits a total amount evenly across 1–3 panels, each with a scroll-wheel dial to set the number of people. The per-person amount updates instantly as you spin the dial.

Originally inspired by WariKan (2011), fully rebuilt in SwiftUI with SPM dependencies.

## Features

- Scroll-wheel dial input via [AZDial](https://github.com/SumPositive/AZDial)
- BCD decimal arithmetic via [AZCalc](https://github.com/SumPositive/AZCalc) — no floating-point errors
- 1–3 panels with custom names and tier presets
- Skeuomorphic leather texture background (brown / black)
- Brass-style dial frames
- Configurable rounding mode (四捨五入 / 切り捨て / 切り上げ / 銀行丸め)
- People lock and full control lock
- Dial sensitivity tuning via dial settings sheet
- In-app tip (StoreKit 2) and rewarded ad (AdMob) support

## Architecture

```
DialSplit/
├── App/              — App entry point, AppSettings
├── Features/
│   ├── Split/        — SplitView, PanelView, SplitViewModel
│   └── Settings/     — SettingsView
└── Components/       — BrassFrame, LeatherBackground
```

**Key dependencies**
- [AZDial](https://github.com/SumPositive/AZDial) — SwiftUI scroll-wheel dial control
- [AZCalc](https://github.com/SumPositive/AZCalc) — BCD decimal arithmetic

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6

## Changelog

### 2.1.0
- Added people lock and full control lock
- Added dial settings sheet with sensitivity tuning
- Refreshed settings UI layout
- Added coin-toss animation to the tip sheet
- Moved tip and ad support buttons directly into Settings

### 2.0.1
- Bug fixes

## License

MIT License. See [LICENSE](LICENSE) for details.
