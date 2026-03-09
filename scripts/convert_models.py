#!/usr/bin/env python3
"""
CoreMLモデル変換スクリプト

YOLOv8, Depth Anything V2, DeepLabV3 を CoreML 形式で準備します。

必要なライブラリ:
    pip install -r scripts/requirements.txt

使い方:
    bash scripts/setup_and_convert.sh              # 推奨（全モデル変換）
    python convert_models.py                       # デフォルト: 全モデル変換
    python convert_models.py --yolo-variant yolov8s  # 特定のYOLOバリアント
    python convert_models.py --all-yolo            # 全YOLOバリアントを変換
    python convert_models.py --depth-variant base   # Base サイズの深度モデル
    python convert_models.py --all-depth            # 全深度モデルバリアント変換
    python convert_models.py --skip-depth           # 深度モデルをスキップ
    python convert_models.py --skip-segmentation    # セグメンテーションをスキップ
"""

import argparse
import os
import sys
import importlib.metadata
import urllib.request
import shutil

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "MoveNnOnIphone", "MLModels")

# 必要な依存ライブラリの最低バージョン
REQUIRED_PACKAGES = {
    "torch": "2.1.0",
    "coremltools": "7.0",
    "ultralytics": "8.0.0",
    "transformers": "4.35.0",
}

# 利用可能なYOLOバリアント
YOLO_VARIANTS = {
    "yolov8n": {"pt": "yolov8n.pt", "description": "Nano - 最速・軽量"},
    "yolov8s": {"pt": "yolov8s.pt", "description": "Small - バランス型"},
    "yolov8m": {"pt": "yolov8m.pt", "description": "Medium - 高精度"},
    "yolov8x": {"pt": "yolov8x.pt", "description": "Extra Large - 最高精度"},
}

# Depth Anything V2 バリアント
DEPTH_VARIANTS = {
    "small": {
        "hf_name": "depth-anything/Depth-Anything-V2-Small-hf",
        "output_name": "DepthAnythingV2SmallF16",
        "description": "Small - 軽量・高速",
    },
    "base": {
        "hf_name": "depth-anything/Depth-Anything-V2-Base-hf",
        "output_name": "DepthAnythingV2BaseF16",
        "description": "Base - バランス型",
    },
    "large": {
        "hf_name": "depth-anything/Depth-Anything-V2-Large-hf",
        "output_name": "DepthAnythingV2LargeF16",
        "description": "Large - 最高精度",
    },
}

# Apple公式 DeepLabV3 モデル
DEEPLABV3_MODELS = {
    "DeepLabV3": {
        "url": "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3.mlmodel",
        "description": "Full precision (8.6MB)",
    },
    "DeepLabV3FP16": {
        "url": "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3FP16.mlmodel",
        "description": "FP16 (4.3MB)",
    },
    "DeepLabV3Int8LUT": {
        "url": "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3Int8LUT.mlmodel",
        "description": "Int8 quantized (2.3MB)",
    },
}


def _parse_version(ver_str):
    """バージョン文字列をタプルに変換 (packaging が無い場合のフォールバック)"""
    parts = []
    for p in ver_str.split(".")[:3]:
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    return tuple(parts)


def check_dependencies():
    """依存ライブラリのバージョンを確認し、不足があればエラー終了"""
    try:
        from packaging.version import Version

        def version_ok(installed, required):
            return Version(installed) >= Version(required)
    except ImportError:
        def version_ok(installed, required):
            return _parse_version(installed) >= _parse_version(required)

    errors = []
    for pkg, min_ver in REQUIRED_PACKAGES.items():
        try:
            installed_ver = importlib.metadata.version(pkg)
            if not version_ok(installed_ver, min_ver):
                errors.append(
                    f"  {pkg}: インストール済み {installed_ver} → 必要 >= {min_ver}"
                )
        except importlib.metadata.PackageNotFoundError:
            errors.append(f"  {pkg}: 未インストール (必要 >= {min_ver})")

    if errors:
        print("=" * 50)
        print("エラー: 依存ライブラリの要件を満たしていません")
        print("=" * 50)
        for e in errors:
            print(e)
        print()
        print("以下のコマンドで仮想環境をセットアップしてください:")
        print("  bash scripts/setup_and_convert.sh")
        print()
        print("または手動で:")
        print("  python3 -m venv venv")
        print("  source venv/bin/activate")
        print("  pip install -r scripts/requirements.txt")
        sys.exit(1)

    print("依存ライブラリの確認: OK")
    print()


def convert_yolov8(variant="yolov8n"):
    """YOLOv8 を CoreML 形式に変換"""
    if variant not in YOLO_VARIANTS:
        print(f"Error: 不明なバリアント '{variant}'")
        print(f"利用可能: {', '.join(YOLO_VARIANTS.keys())}")
        return False

    info = YOLO_VARIANTS[variant]
    print("=" * 50)
    print(f"{variant} ({info['description']}) の CoreML 変換を開始")
    print("=" * 50)

    try:
        from ultralytics import YOLO
    except ImportError:
        print("Error: ultralytics がインストールされていません")
        print("  pip install ultralytics")
        return False

    model = YOLO(info["pt"])
    model.export(
        format="coreml",
        nms=True,
        imgsz=640,
    )

    # Move the exported model
    src = f"{variant}.mlpackage"
    dst = os.path.join(OUTPUT_DIR, f"{variant}.mlpackage")
    if os.path.exists(src):
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        os.rename(src, dst)
        print(f"モデルを保存しました: {dst}")
        return True
    else:
        print("Warning: エクスポートされたモデルが見つかりません")
        return False


def convert_depth_anything(variant="small"):
    """Depth Anything V2 を CoreML 形式に変換"""
    if variant not in DEPTH_VARIANTS:
        print(f"Error: 不明なバリアント '{variant}'")
        print(f"利用可能: {', '.join(DEPTH_VARIANTS.keys())}")
        return False

    info = DEPTH_VARIANTS[variant]
    print()
    print("=" * 50)
    print(f"Depth Anything V2 {variant.capitalize()} ({info['description']}) の CoreML 変換を開始")
    print("=" * 50)

    try:
        import torch
        import coremltools as ct
        from transformers import AutoModelForDepthEstimation, AutoImageProcessor
    except ImportError:
        print("Error: 必要なライブラリがインストールされていません")
        print("  pip install torch coremltools transformers")
        return False

    model_name = info["hf_name"]
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

    # coremltools は upsample_bicubic2d をサポートしていないため、
    # トレース中のみ bicubic → bilinear に置換する
    import torch.nn.functional as F
    _original_interpolate = F.interpolate

    def _patched_interpolate(*args, **kwargs):
        if kwargs.get("mode") == "bicubic":
            kwargs["mode"] = "bilinear"
            kwargs.pop("antialias", None)
        return _original_interpolate(*args, **kwargs)

    print("モデルをトレース中 (bicubic → bilinear 置換)...")
    F.interpolate = _patched_interpolate
    try:
        traced = torch.jit.trace(wrapper, dummy_input)
    finally:
        F.interpolate = _original_interpolate

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
    output_path = os.path.join(OUTPUT_DIR, f"{info['output_name']}.mlpackage")
    mlmodel.save(output_path)
    print(f"モデルを保存しました: {output_path}")
    return True


def download_deeplabv3(variant="DeepLabV3FP16"):
    """Apple公式 DeepLabV3 モデルをダウンロード"""
    if variant not in DEEPLABV3_MODELS:
        print(f"Error: 不明なバリアント '{variant}'")
        print(f"利用可能: {', '.join(DEEPLABV3_MODELS.keys())}")
        return False

    info = DEEPLABV3_MODELS[variant]
    print()
    print("=" * 50)
    print(f"DeepLabV3 ({info['description']}) のダウンロードを開始")
    print("=" * 50)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{variant}.mlmodel")

    if os.path.exists(output_path):
        print(f"既にダウンロード済み: {output_path}")
        return True

    url = info["url"]
    print(f"ダウンロード中: {url}")

    try:
        urllib.request.urlretrieve(url, output_path)
        print(f"モデルを保存しました: {output_path}")
        return True
    except Exception as e:
        print(f"Error: ダウンロードに失敗しました: {e}")
        return False


def parse_args():
    parser = argparse.ArgumentParser(
        description="CoreMLモデル変換スクリプト"
    )
    parser.add_argument(
        "--yolo-variant",
        choices=list(YOLO_VARIANTS.keys()),
        default="yolov8n",
        help="変換するYOLOバリアント (default: yolov8n)",
    )
    parser.add_argument(
        "--all-yolo",
        action="store_true",
        help="全YOLOバリアントを変換",
    )
    parser.add_argument(
        "--depth-variant",
        choices=list(DEPTH_VARIANTS.keys()),
        default="small",
        help="変換するDepth Anythingバリアント (default: small)",
    )
    parser.add_argument(
        "--all-depth",
        action="store_true",
        help="全Depth Anythingバリアントを変換",
    )
    parser.add_argument(
        "--deeplabv3-variant",
        choices=list(DEEPLABV3_MODELS.keys()),
        default="DeepLabV3FP16",
        help="ダウンロードするDeepLabV3バリアント (default: DeepLabV3FP16)",
    )
    parser.add_argument(
        "--all-deeplabv3",
        action="store_true",
        help="全DeepLabV3バリアントをダウンロード",
    )
    parser.add_argument(
        "--skip-depth",
        action="store_true",
        help="深度推定モデルの変換をスキップ",
    )
    parser.add_argument(
        "--skip-yolo",
        action="store_true",
        help="YOLOモデルの変換をスキップ",
    )
    parser.add_argument(
        "--skip-segmentation",
        action="store_true",
        help="セグメンテーションモデルのダウンロードをスキップ",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    print("CoreML モデル変換スクリプト")
    print()

    check_dependencies()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    results = {}

    # YOLO conversion
    if not args.skip_yolo:
        if args.all_yolo:
            for variant in YOLO_VARIANTS:
                results[variant] = convert_yolov8(variant)
                print()
        else:
            variant = args.yolo_variant
            results[variant] = convert_yolov8(variant)

    # Depth conversion
    if not args.skip_depth:
        if args.all_depth:
            for dv in DEPTH_VARIANTS:
                results[f"Depth Anything V2 ({dv})"] = convert_depth_anything(dv)
        else:
            dv = args.depth_variant
            results[f"Depth Anything V2 ({dv})"] = convert_depth_anything(dv)

    # DeepLabV3 download
    if not args.skip_segmentation:
        if args.all_deeplabv3:
            for variant in DEEPLABV3_MODELS:
                results[f"DeepLabV3 ({variant})"] = download_deeplabv3(variant)
        else:
            variant = args.deeplabv3_variant
            results[f"DeepLabV3 ({variant})"] = download_deeplabv3(variant)

    print()
    print("=" * 50)
    print("変換結果:")
    for name, ok in results.items():
        status = "OK" if ok else "FAILED"
        print(f"  {name:30s} {status}")
    print("=" * 50)

    if any(results.values()):
        print()
        print("次のステップ:")
        print(f"1. {OUTPUT_DIR} 内のモデルファイルを確認")
        print("2. xcodegen generate でプロジェクト生成")
        print("3. Xcodeでビルドして実行")


if __name__ == "__main__":
    main()
