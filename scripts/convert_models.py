#!/usr/bin/env python3
"""
CoreMLモデル変換スクリプト

YOLOv8 と Depth Anything V2 を CoreML 形式に変換します。

必要なライブラリ:
    pip install -r scripts/requirements.txt

使い方:
    bash scripts/setup_and_convert.sh          # 推奨（venv自動作成）
    bash scripts/setup_and_convert.sh /path/to/venv  # 既存venv指定
    python convert_models.py                   # 手動実行
"""

import os
import sys
import importlib.metadata

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "MoveNnOnIphone", "MLModels")

# 必要な依存ライブラリの最低バージョン
REQUIRED_PACKAGES = {
    "torch": "2.1.0",
    "coremltools": "7.0",
    "ultralytics": "8.0.0",
    "transformers": "4.35.0",
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
    # packaging モジュールを試行、無ければタプル比較にフォールバック
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
    output_path = os.path.join(OUTPUT_DIR, "DepthAnythingV2SmallF16.mlpackage")
    mlmodel.save(output_path)
    print(f"モデルを保存しました: {output_path}")
    print("Xcodeプロジェクトに DepthAnythingV2SmallF16.mlpackage を追加してください")
    return True


def main():
    print("CoreML モデル変換スクリプト")
    print()

    check_dependencies()

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
