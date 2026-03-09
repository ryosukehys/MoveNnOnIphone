# Privacy Policy / プライバシーポリシー

**Last updated / 最終更新日: 2026-03-09**

## 日本語

### はじめに

AI Vision Camera（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。本プライバシーポリシーは、本アプリにおけるデータの取り扱いについて説明するものです。

### 収集する情報

**本アプリは、個人情報を一切収集・送信しません。**

本アプリで使用されるすべての画像データおよびカメラ映像は、お使いのデバイス上でのみ処理され、外部サーバーに送信されることはありません。

### カメラの使用

本アプリは、以下の目的でカメラへのアクセスを必要とします：

- リアルタイム物体検出
- 写真撮影および物体検出
- 深度推定のための画像取得
- セマンティックセグメンテーションのための画像取得

カメラで撮影された画像は、デバイス上のML（機械学習）モデルによって処理されます。画像データがデバイス外に送信されることはありません。

### 写真ライブラリの使用

ユーザーが検出結果を保存する際に、写真ライブラリへの書き込みアクセスを必要とします。保存した画像はユーザーのデバイス上にのみ保管されます。

### 機械学習処理

本アプリは以下のMLモデルを使用しますが、すべての推論処理はデバイス上で完結します：

- YOLOv8（物体検出）
- Depth Anything V2（深度推定）
- DeepLabV3（セマンティックセグメンテーション）

これらのモデルはアプリバンドルに含まれており、追加のダウンロードやネットワーク通信は不要です。

### データの保存

本アプリは、以下の設定情報をデバイス上にローカル保存します：

- 選択中のモデルバリアント
- 信頼度閾値の設定値

これらの設定はUserDefaultsに保存され、外部に送信されることはありません。

### 第三者サービス

本アプリは、アナリティクス、広告、トラッキングなどの第三者サービスを一切使用しません。

### 子どものプライバシー

本アプリはデータを収集しないため、13歳未満の子どもを含むすべてのユーザーが安全にご利用いただけます。

### プライバシーポリシーの変更

本ポリシーは予告なく変更される場合があります。変更があった場合は、本ページの「最終更新日」を更新します。

### お問い合わせ

プライバシーに関するご質問は、以下までお問い合わせください：

- GitHub: https://github.com/ryosukehys/MoveNnOnIphone/issues

---

## English

### Introduction

AI Vision Camera ("the App") respects user privacy and is committed to protecting personal information. This Privacy Policy describes how data is handled within the App.

### Information We Collect

**The App does not collect or transmit any personal information.**

All image data and camera footage used by the App is processed exclusively on your device and is never sent to external servers.

### Camera Usage

The App requires camera access for the following purposes:

- Real-time object detection
- Photo capture and object detection
- Image acquisition for depth estimation
- Image acquisition for semantic segmentation

Images captured by the camera are processed by on-device ML (machine learning) models. Image data is never transmitted outside the device.

### Photo Library Usage

Write access to the photo library is required when the user saves detection results. Saved images are stored only on the user's device.

### Machine Learning Processing

The App uses the following ML models, but all inference processing is performed entirely on-device:

- YOLOv8 (Object Detection)
- Depth Anything V2 (Depth Estimation)
- DeepLabV3 (Semantic Segmentation)

These models are included in the app bundle and require no additional downloads or network communication.

### Data Storage

The App locally stores the following settings on the device:

- Selected model variants
- Confidence threshold settings

These settings are saved in UserDefaults and are never transmitted externally.

### Third-Party Services

The App does not use any third-party services such as analytics, advertising, or tracking.

### Children's Privacy

Since the App does not collect data, it can be safely used by all users, including children under 13.

### Changes to This Privacy Policy

This policy may be updated without notice. When changes are made, the "Last Updated" date on this page will be updated.

### Contact

For privacy-related questions, please contact us at:

- GitHub: https://github.com/ryosukehys/MoveNnOnIphone/issues
