# MoveNnOnIphone

iPhoneのカメラを使用した AI ビジョンアプリ。YOLOv8 によるリアルタイム物体検出と Depth Anything V2 による深度推定を実行できます。

## 機能

### リアルタイム物体検出 (YOLO)
- カメラ映像からリアルタイムで物体を検出
- 検出された物体を矩形とカテゴリ名で表示
- FPS 表示

### 写真物体検出 (YOLO)
- 撮影した写真に対して物体検出を実行
- 検出結果を矩形・カテゴリ名・信頼度で表示
- 検出結果一覧表示
- 写真の保存

### 深度推定 (Depth Anything V2)
- 撮影した写真の深度マップを生成
- Turbo カラーマップで可視化
- 元画像と深度マップの切り替え表示
- 深度マップの保存

### 設定
- YOLO 信頼度閾値の調整 (5% - 95%)
- モデル読み込み状態の確認
- 使い方ガイド

## セットアップ

### 必要環境
- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ の iPhone 実機（シミュレータではカメラ使用不可）

### 手順

#### 1. CoreML モデルの準備

##### 方法 A: 変換スクリプトを使用

```bash
# 必要なライブラリをインストール
pip install ultralytics coremltools torch transformers

# モデルを変換
python scripts/convert_models.py
```

##### 方法 B: 手動でモデルを取得

**YOLOv8n:**
```bash
pip install ultralytics
yolo export model=yolov8n.pt format=coreml nms=True imgsz=640
```

**Depth Anything V2:**
- [Hugging Face](https://huggingface.co/depth-anything/Depth-Anything-V2-Small-hf) からモデルを取得
- `coremltools` で CoreML 形式に変換

#### 2. Xcode プロジェクトの生成

##### 方法 A: XcodeGen を使用（推奨）

```bash
# XcodeGen をインストール
brew install xcodegen

# プロジェクトを生成
xcodegen generate

# Xcode で開く
open MoveNnOnIphone.xcodeproj
```

##### 方法 B: 手動で Xcode プロジェクトを作成

1. Xcode で新規プロジェクト作成 (App, SwiftUI, iOS)
2. プロジェクト名: `MoveNnOnIphone`
3. `MoveNnOnIphone/` フォルダ内の全 `.swift` ファイルをプロジェクトに追加
4. `Info.plist` を設定
5. Deployment Target を iOS 17.0 に設定

#### 3. CoreML モデルの追加

1. 変換済みの `.mlpackage` または `.mlmodel` ファイルを準備
2. Xcode のプロジェクトナビゲータにドラッグ＆ドロップ
3. 「Copy items if needed」にチェック
4. ターゲット `MoveNnOnIphone` にチェック

必要なモデルファイル:
- `yolov8n.mlpackage` (または `yolov8n.mlmodel`)
- `DepthAnythingV2SmallF16.mlpackage` (または `DepthAnythingV2SmallF16.mlmodel`)

#### 4. ビルドと実行

1. Signing & Capabilities で開発チームを設定
2. iPhone 実機を接続
3. ビルドして実行

## プロジェクト構成

```
MoveNnOnIphone/
├── project.yml                      # XcodeGen 設定
├── MoveNnOnIphone/
│   ├── MoveNnOnIphoneApp.swift      # アプリエントリポイント
│   ├── ContentView.swift            # メインタブビュー
│   ├── AppSettings.swift            # 設定管理
│   ├── Camera/
│   │   ├── CameraManager.swift      # カメラ制御
│   │   └── CameraPreviewView.swift  # カメラプレビュー (UIKit Bridge)
│   ├── ML/
│   │   ├── YOLODetector.swift       # YOLO 物体検出
│   │   └── DepthEstimator.swift     # Depth Anything 深度推定
│   ├── Views/
│   │   ├── RealTimeDetectionView.swift   # リアルタイム検出画面
│   │   ├── PhotoDetectionView.swift      # 写真検出画面
│   │   ├── DepthEstimationView.swift     # 深度推定画面
│   │   ├── SettingsView.swift            # 設定画面
│   │   └── BoundingBoxOverlay.swift      # バウンディングボックス描画
│   ├── MLModels/                    # CoreML モデル配置場所
│   ├── Assets.xcassets/
│   └── Info.plist
├── scripts/
│   └── convert_models.py           # モデル変換スクリプト
└── README.md
```

## 技術詳細

| コンポーネント | 技術 |
|---|---|
| UI フレームワーク | SwiftUI |
| カメラ | AVFoundation |
| ML 推論 | Vision + CoreML |
| YOLO モデル | YOLOv8n (CoreML, NMS 内蔵) |
| 深度推定モデル | Depth Anything V2 Small (CoreML, Float16) |
| 最小 iOS バージョン | 17.0 |
