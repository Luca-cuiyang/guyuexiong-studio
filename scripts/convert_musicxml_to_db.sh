#!/bin/bash
# DB Studio - 批量把架子鼓课程 musicxml 转成 .db（使用 DB Score 转换，保证鼓音色正确）
# 转换完成后直接写入跨平台中文字体和 FluidR3_GM 音轨，避免首次打开再回退。
# 每次运行都会覆盖重转，确保没有历史错误版本残留。
set -u

# 可通过 DBS/ROOT 环境变量覆盖，避免绑定到某个用户目录。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DBS="${DBS:-$SCRIPT_DIR/../applebuild/dbscore.app/Contents/MacOS/dbscore}"
ROOT="${ROOT:-$HOME/Desktop}"
NORMALIZER="${NORMALIZER:-$SCRIPT_DIR/normalize_db_course_assets.py}"
BOOKS=(
  "A1-军鼓课程" "A2-节奏课程" "A3-填充课程" "A4-手脚协调"
  "B1-军鼓课程" "B2-节奏课程" "B3-填充课程" "B4-手脚协调"
  "C1-军鼓课程" "C2-节奏课程" "C3-填充课程" "C4-手脚协调"
)

total=0
done=0
failed=0

if [ ! -x "$DBS" ]; then
  echo "找不到可执行的 DB Score：$DBS" >&2
  exit 1
fi
if [ ! -f "$NORMALIZER" ]; then
  echo "找不到 .db 源数据规范化工具：$NORMALIZER" >&2
  exit 1
fi

for book in "${BOOKS[@]}"; do
  while IFS= read -r f; do
    total=$((total+1))
    out="${f%.musicxml}.db"
    rm -f "$out"
    "$DBS" "$f" -o "$out" -f >/dev/null 2>&1
    if [ -f "$out" ] && python3 "$NORMALIZER" --quiet "$out" >/dev/null; then
      done=$((done+1))
    else
      failed=$((failed+1))
      echo "FAILED: $f"
    fi
  done < <(find "$ROOT/$book" -name "*.musicxml" | sort)
done

echo "转换完成：共 $total 个，成功 $done 个，失败 $failed 个"
