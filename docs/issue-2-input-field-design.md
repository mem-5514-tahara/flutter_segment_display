# ISSUE #2 調査レポート：セグメントディスプレイへのユーザー入力対応

## ISSUEの概要

[Issue #2](https://github.com/janstol/flutter_segment_display/issues/2)（2020年9月）では、`SegmentDisplay` をテキストフィールドとして使えるか、あるいはラッパーで実現できるかという問い。

---

## 結論：実現可能

`SegmentDisplay` は描画専用の `StatelessWidget`（`CustomPainter` ベース）であり、入力機能を持たない。しかし **入力ロジックを上位ウィジェットで管理し、結果を `value` に渡す** 設計にすれば、既存 API を一切壊さずに `SegmentDisplayField` として実装できる。

---

## 現在のアーキテクチャと入力追加の関係

```
value (String)
  ↓ CharacterSegmentMap（char → bitmask）
  ↓ createDisplaySegments() → List<Segment>
  ↓ SegmentDisplayPainter（CustomPainter）
  ↓ Canvas
```

`SegmentDisplay` は `value` を受け取って描くだけなので、入力 State を外部（新規の `StatefulWidget`）に持てばよく、既存コードへの変更は不要。

---

## 技術的課題

### 1. テキスト入力の取得方法

Flutter でソフトウェアキーボード（IME）を呼び出すには、`TextField` / `EditableText` が内部で使っている `TextInputConnection`（`TextInputClient` ミックスイン経由）が必要。`RawKeyboardListener` は物理キーボードのみ対応でモバイル非対応。

### 2. カーソル表示

セグメントディスプレイには通常のテキストカーソルがない。`customCharacterMap` を利用して以下の文字を点滅させることで代用できる。

| ディスプレイ種別 | 推奨カーソル文字 | bitmask | 見た目 |
|---|---|---|---|
| 7-segment | `_` | `0x08` | 下線（底辺のみ点灯） |
| 14-segment | `\|` | `0x0012` | 縦棒 |
| 16-segment | `\|` | `0x0012` | 縦棒 |

`Timer.periodic` でカーソルを `value` の末尾に付与／除去することでブリンクを実現。

### 3. 使用可能文字の制限

`CharacterSegmentMap` に存在しない文字は空白で描画される（`canDisplay()` が `false`）。入力時にフィルタリングが必要。また 7-segment は英字に大文字/小文字の制限があるため、自動変換（例：`toLowerCase()` / `toUpperCase()`）を検討する必要がある。

### 4. テキスト選択・カーソル移動

セグメントの個別強調表示ができないため、テキスト選択は**対応不可**。カーソル位置も**末尾固定**が現実的。ペーストは文字フィルタリング後に末尾追記として実装可能。

---

## 設計アプローチの比較

### アプローチA：Hidden TextField + SegmentDisplay（最もシンプル）

```dart
Stack([
  Offstage(
    child: TextField(controller: _controller, focusNode: _focusNode),
  ),
  GestureDetector(
    onTap: () => _focusNode.requestFocus(),
    child: SegmentDisplay(value: _displayValue),
  ),
])
```

- **利点**：Flutter の IME・変換・アクセシビリティをそのまま利用できる。実装コストが最小。
- **欠点**：`Offstage` に隠れた `TextField` は不格好。フォーカス競合のリスクあり。Semantics の二重登録。

### アプローチB：TextInputClient 実装（最もクリーン）★推奨

`TextInputClient` ミックスインを実装し、`TextInput.attach(this, config)` でキーボードに接続。`updateEditingValue` コールバックで入力を受け取り、`setState` で `value` を更新する。

- **利点**：Flutter の `EditableText` と同じメカニズム。隠しウィジェット不要。IME 完全対応。
- **欠点**：Flutter 内部 API の変更に追随する必要がある（ただし安定しており破壊的変更は稀）。

### アプローチC：RawKeyboardListener（デスクトップ限定）

```dart
Focus(
  focusNode: _focusNode,
  onKeyEvent: (node, event) { /* キー処理 */ },
  child: GestureDetector(...),
)
```

- **利点**：実装が単純。
- **欠点**：モバイルのソフトウェアキーボードに非対応。汎用ライブラリとしては不採用。

---

## 推奨設計：SegmentDisplayField（アプローチB）

### API 案

```dart
class SegmentDisplayField extends StatefulWidget {
  const SegmentDisplayField({
    super.key,
    required this.displayType,        // seven / fourteen / sixteen
    this.controller,                  // TextEditingController（省略時は内部管理）
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,                   // characterCount に連動、超過入力を拒否
    this.showCursor = true,
    this.cursorBlinkDuration = const Duration(milliseconds: 500),
    // --- SegmentDisplay 視覚パラメータ ---
    this.size = 10.0,
    this.characterSpacing = 7.0,
    this.backgroundColor,
    this.segmentStyle,
    this.showDisabledDividers = false,
    this.keyboardType,                // 省略時はディスプレイ種別から自動選択
  });

  final SegmentDisplayType displayType;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final bool showCursor;
  final Duration cursorBlinkDuration;
  final TextInputType? keyboardType;
  // ...
}
```

### 内部ロジックのポイント

| 項目 | 実装方針 |
|---|---|
| キーボード接続 | `TextInputClient` + `TextInput.attach()` |
| 状態管理 | `TextEditingController`（外部注入可） |
| カーソルブリンク | `FocusNode` のリスナーで `hasFocus` を監視し、フォーカス時のみ `Timer.periodic` を開始。フォーカス喪失・`dispose()` 時に必ず `timer.cancel()` |
| 文字フィルタリング | `updateEditingValue` 受信時に `canDisplay()` でフィルタ |
| maxLength 超過 | フィルタ後に末尾 `maxLength` 文字のみ保持 |
| バックスペース | `updateEditingValue` の `TextEditingValue.text` の差分で検出 |
| フォーカス取得 | `GestureDetector.onTap` → `_focusNode.requestFocus()` |
| キーボードアクション | `performAction(TextInputAction action)` で「完了」「改行」を検知 → `onSubmitted` を発火 |
| IME変換中 | `updateEditingValue` で `value.composing.isValid` が `true` の間は表示を更新しない（確定待ち）。英数字特化のディスプレイ（7-segment 等）では `keyboardType` を `TextInputType.number` / `TextInputType.visiblePassword` / `TextInputType.url` など **インライン変換が発生しないキーボード種別** に固定し、IME 変換そのものを抑制するのが最も安全。省略時はディスプレイ種別に応じてデフォルトを自動選択（7-segment → `number`、14/16-segment → `visiblePassword`）する実装が親切 |

### 表示レンダリング

カーソル表示時：`_displayValue = _controller.text + _cursorChar`  
カーソル非表示時：`_displayValue = _controller.text`

これを `SegmentDisplay(value: _displayValue, customCharacterMap: _cursorMap)` に渡すだけで、既存の描画パイプラインをそのまま利用できる。

---

## パッケージへの変更スコープ

### 新規ファイル
- `lib/src/display/segment_display_field.dart`（`SegmentDisplayField` の実装）

### 既存ファイルへの変更
- `lib/segment_display.dart`：エクスポート行を1行追加するのみ

### 既存 API への影響
**ゼロ**。`SegmentDisplay` とその派生クラスに変更なし。

---

## 制約・注意事項

| 制約 | 内容 |
|---|---|
| カーソル移動 | 末尾固定。中間への挿入は非対応 |
| テキスト選択 | 非対応（セグメント強調の描画機構がない） |
| IME変換中 | `composing.isValid` が `true` の間は表示を更新しない仕様が安全。英数字特化のディスプレイでは `keyboardType` を `TextInputType.visiblePassword` 等に固定し IME インライン変換を抑制するのが最も確実。省略時はディスプレイ種別でデフォルトを自動選択 |
| 文字セット | ディスプレイ種別ごとの `CharacterSegmentMap` に依存。`customCharacterMap` で拡張は可能 |
| タイマーリーク | `Timer.periodic` は `hasFocus == false` 時・`dispose()` 時に必ず `cancel()` すること。放置すると画面裏で `setState` が走りパフォーマンス・バッテリーに影響 |
| アクセシビリティ | `SegmentDisplay` の `Semantics(label: 'Segment display', value: value)` がそのまま利用可能 |

---

## 実装判断

このISSUEは **ラッパーで実現可能** という回答が正しい。パッケージ本体への追加コストは低く、`TextInputClient` ベースの `SegmentDisplayField` として提供するのが最も筋の良い設計。既存 API を壊さないため、オプション機能として追加しやすい。
