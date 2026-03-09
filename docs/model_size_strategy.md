# モデルバンドルサイズ戦略

## 現状のモデルサイズ一覧

| モデル | サイズ（概算） | デフォルトバンドル |
|--------|---------------|-------------------|
| YOLOv8n (Nano) | ~12MB | Yes |
| YOLOv8s (Small) | ~22MB | No |
| YOLOv8m (Medium) | ~50MB | No |
| YOLOv8x (Extra Large) | ~130MB | No |
| Depth Anything V2 Small | ~100MB | Yes |
| Depth Anything V2 Base | ~200MB | No |
| Depth Anything V2 Large | ~600MB | No |
| DeepLabV3 FP16 | ~4MB | Yes |
| DeepLabV3 Full | ~9MB | No |
| DeepLabV3 Int8 | ~2MB | No |
| **合計（全モデル）** | **~1.1GB** | - |
| **合計（デフォルトのみ）** | **~116MB** | - |

## App Store の制限

- **セルラーダウンロード上限**: 200MB（Wi-Fi不要でダウンロード可能な上限）
- **App Store 上限**: 4GB（アプリ全体）
- **推奨**: 初回ダウンロードは小さく、必要に応じて追加

## 推奨戦略: デフォルト軽量 + オンデマンドダウンロード

### バンドルに含めるモデル（~116MB）
- YOLOv8n (Nano) - 12MB
- Depth Anything V2 Small - 100MB
- DeepLabV3 FP16 - 4MB

### オンデマンドでダウンロード可能にするモデル
- YOLOv8s/m/x
- Depth Anything V2 Base/Large
- DeepLabV3 Full/Int8

## 実装方法

### 方法1: Apple On-Demand Resources (ODR) ← 最も推奨

**メリット:**
- Apple CDN から配信（自前サーバー不要）
- Xcode の設定だけで実装可能
- App Thinning と統合されている
- ストレージ圧迫時に自動クリーンアップ

**デメリット:**
- Apple Developer Program 加入が必須（$99/年）
- モデルファイルをアプリ提出時に含める必要がある（審査用）
- App Store 経由でのみ配信

**実装手順:**
1. Xcode でモデルファイルにタグを付ける（例: `yolov8s-model`）
2. `NSBundleResourceRequest` でダウンロード要求
3. ダウンロード完了後に `Bundle.main` からアクセス

### 方法2: 自前サーバーからダウンロード（ModelDownloadManager）← 実装済み

**メリット:**
- 完全な制御が可能
- Apple Developer Program なしでも実装可能
- 任意のタイミングでモデルを追加・更新可能
- CDN（CloudFront, Firebase Hosting 等）で高速配信

**デメリット:**
- サーバーコストが発生
- ダウンロードUIを自前で実装する必要がある
- App Review でネットワーク要件を説明する必要がある

**実装状態:** `ModelDownloadManager.swift` に基盤を実装済み。
サーバーURLを設定すればすぐに使用可能。

### 方法3: CloudKit + CKAsset

**メリット:**
- Apple の無料枠あり
- iCloud 連携

**デメリット:**
- 大きなファイルには不向き
- 複雑な実装

## あとからモデルを追加する方法

### Q: リリース後に新しいモデルを追加できるか？

**はい、可能です。**

1. **アプリアップデート**: 新バージョンで新モデルをバンドルに追加
2. **サーバーダウンロード**: `ModelDownloadManager` 経由で新モデルを配信
3. **ODR**: 新しいODRタグを追加してアップデート提出

### Q: ユーザーが選択的にダウンロードできるか？

**はい。** 現在の `ModelDownloadManager` の設計がまさにそれをサポートしています:
- 設定画面でモデル一覧を表示
- 「ダウンロード」ボタンで選択的にダウンロード
- ダウンロード済みモデルの削除も可能

## 推奨リリース戦略

### Phase 1（初回リリース）
- デフォルト3モデルのみバンドル（~116MB）
- 設定画面に「追加モデル」セクション表示（Coming Soon）

### Phase 2（アップデート）
- サーバーを用意してモデルダウンロード機能を有効化
- または ODR を設定してApple CDN経由で配信

### Phase 3（拡張）
- 新しいモデル（SAM, MobileNetV3 等）を追加
- モデルの自動更新機能
