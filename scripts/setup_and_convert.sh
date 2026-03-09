#!/bin/bash
set -euo pipefail

# ============================================================
# CoreML モデル変換セットアップスクリプト
#
# 使い方:
#   bash scripts/setup_and_convert.sh              # デフォルト (yolov8n + depth)
#   bash scripts/setup_and_convert.sh /path/to/venv # 既存の venv を指定
#   bash scripts/setup_and_convert.sh --all-yolo   # 全YOLOバリアント変換
#   bash scripts/setup_and_convert.sh --yolo-variant yolov8s  # 特定バリアント
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 最初の引数が / or . で始まる場合は venv パスとして扱う
VENV_PATH="$PROJECT_DIR/venv"
CONVERT_ARGS=()

for arg in "$@"; do
    if [[ "$arg" == /* ]] || [[ "$arg" == ./* ]] || [[ "$arg" == ../* ]]; then
        VENV_PATH="$arg"
    else
        CONVERT_ARGS+=("$arg")
    fi
done

log()  { echo "[INFO]  $1"; }
warn() { echo "[WARN]  $1"; }
error(){ echo "[ERROR] $1" >&2; exit 1; }

echo "=============================================="
echo " CoreML モデル変換セットアップ"
echo "=============================================="
echo ""

# --- Step 1: Python3 の確認 ---
if ! command -v python3 &>/dev/null; then
    error "python3 が見つかりません。Python 3.8 以上をインストールしてください。"
fi

PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log "Python バージョン: $PYTHON_VER"

# --- Step 2: 仮想環境の作成または再利用 ---
if [ -f "$VENV_PATH/bin/activate" ]; then
    log "既存の仮想環境を使用: $VENV_PATH"
else
    log "仮想環境を作成中: $VENV_PATH"
    python3 -m venv "$VENV_PATH"
    log "仮想環境を作成しました"
fi

# --- Step 3: 仮想環境を有効化 ---
log "仮想環境を有効化中..."
source "$VENV_PATH/bin/activate"

# --- Step 4: pip のアップグレード ---
log "pip をアップグレード中..."
pip install --upgrade pip --quiet

# --- Step 5: 依存ライブラリのインストール ---
echo ""
log "依存ライブラリをインストール中..."
log "（初回は torch のダウンロードに時間がかかる場合があります: 約800MB）"
echo ""
pip install -r "$SCRIPT_DIR/requirements.txt"

# --- Step 6: インストール確認 ---
echo ""
log "インストール済みバージョン:"
python3 -c "
import importlib.metadata
for pkg in ['torch', 'coremltools', 'ultralytics', 'transformers']:
    try:
        ver = importlib.metadata.version(pkg)
        print(f'  {pkg}: {ver}')
    except Exception:
        print(f'  {pkg}: 未インストール')
"

# --- Step 7: モデル変換の実行 ---
echo ""
log "CoreML モデル変換を開始..."
echo ""
python3 "$SCRIPT_DIR/convert_models.py" "${CONVERT_ARGS[@]}"

# --- Step 8: 完了 ---
echo ""
echo "=============================================="
log "セットアップ完了"
echo "=============================================="
echo ""
log "モデルファイルの場所:"
log "  $PROJECT_DIR/MoveNnOnIphone/MLModels/"
echo ""
log "次のステップ:"
log "  1. xcodegen generate でプロジェクト生成"
log "  2. Xcode でプロジェクトを開く"
log "  3. ビルドして iPhone 実機で実行"
echo ""
log "追加のYOLOバリアントを変換するには:"
log "  bash scripts/setup_and_convert.sh --yolo-variant yolov8s"
log "  bash scripts/setup_and_convert.sh --all-yolo"
