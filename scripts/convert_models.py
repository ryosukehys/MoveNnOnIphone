#!/usr/bin/env python3
"""
CoreMLモデル変換スクリプト

YOLOv8 と Depth Anything V2 を CoreML 形式に変換します。

必要なライブラリ:
    pip install ultralytics coremltools torch transformers

使い方:
    python convert_models.py
"""

import os
import sys

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "MoveNnOnIphone", "MLModels")


def convert_yolov8():
    """YOLOv8n を CoreML 形式に変換"""
    print("=" * 50)
    print("YOLOv8n の CoreML 変換を開始")
    print("=" * 50)

    try:
        from ultralytics import YOLO
    except ImportError:
        print("Error: ultralytics がインストールされていません")
        print("  pip install ultralytics")
        return False

    model = YOLO("yolov8n.pt")
    model.export(
        format="coreml",
        nms=True,
        imgsz=640,
    )

    # Move the exported model
    src = "yolov8n.mlpackage"
    dst = os.path.join(OUTPUT_DIR, "yolov8n.mlpackage")
    if os.path.exists(src):
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        os.rename(src, dst)
        print(f"モデルを保存しました: {dst}")
        print("Xcodeプロジェクトに yolov8n.mlpackage を追加してください")
        return True
    else:
        print("Warning: エクスポートされたモデルが見つかりません")
        return False


def convert_depth_anything():
    """Depth Anything V2 Small を CoreML 形式に変換"""
    print()
    print("=" * 50)
    print("Depth Anything V2 Small の CoreML 変換を開始")
    print("=" * 50)

    try:
        import torch
        import coremltools as ct
        from transformers import AutoModelForDepthEstimation, AutoImageProcessor
    except ImportError:
        print("Error: 必要なライブラリがインストールされていません")
        print("  pip install torch coremltools transformers")
        return False

    model_name = "depth-anything/Depth-Anything-V2-Small-hf"
    print(f"モデルをダウンロード中: {model_name}")

    processor = AutoImageProcessor.from_pretrained(model_name)
    model = AutoModelForDepthEstimation.from_pretrained(model_name)
    model.eval()

    # Trace the model
    input_size = 518
    dummy_input = torch.randn(1, 3, input_size, input_size)

    class DepthWrapper(torch.nn.Module):
        def __init__(self, model):
            super().__init__()
            self.model = model

        def forward(self, x):
            return self.model(x).predicted_depth

    wrapper = DepthWrapper(model)

    print("モデルをトレース中...")
    traced = torch.jit.trace(wrapper, dummy_input)

    print("CoreML に変換中...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.ImageType(
                name="image",
                shape=(1, 3, input_size, input_size),
                scale=1.0 / 255.0,
                bias=[0, 0, 0],
            )
        ],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
    )

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, "DepthAnythingV2SmallF16.mlpackage")
    mlmodel.save(output_path)
    print(f"モデルを保存しました: {output_path}")
    print("Xcodeプロジェクトに DepthAnythingV2SmallF16.mlpackage を追加してください")
    return True


def main():
    print("CoreML モデル変換スクリプト")
    print()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    yolo_ok = convert_yolov8()
    depth_ok = convert_depth_anything()

    print()
    print("=" * 50)
    print("変換結果:")
    print(f"  YOLOv8n:           {'OK' if yolo_ok else 'FAILED'}")
    print(f"  Depth Anything V2: {'OK' if depth_ok else 'FAILED'}")
    print("=" * 50)

    if yolo_ok or depth_ok:
        print()
        print("次のステップ:")
        print(f"1. {OUTPUT_DIR} 内のモデルファイルを確認")
        print("2. Xcodeでプロジェクトを開く")
        print("3. モデルファイルをプロジェクトにドラッグ＆ドロップ")
        print("4. ビルドして実行")


if __name__ == "__main__":
    main()
