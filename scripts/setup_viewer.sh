#!/usr/bin/env bash
# setup_viewer.sh — 新しいBAM/リファレンスでビューアをセットアップする
#
# 使い方:
#   bash scripts/setup_viewer.sh <BAMファイル> <FASTAファイル>
#
# 例:
#   bash scripts/setup_viewer.sh n2_sorted.bam reference.fa

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# ─── 依存ツールチェック ─────────────────────────────────────────
echo "依存ツールを確認中..."
MISSING=0
for cmd in python3 bgzip; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "  ❌ $cmd が見つかりません"
    MISSING=1
  fi
done

# samtools 1.x（modern）チェック
SAMTOOLS="${SAMTOOLS:-}"
for candidate in /opt/homebrew/bin/samtools /usr/local/bin/samtools samtools; do
  if command -v "$candidate" &>/dev/null; then
    ver=$("$candidate" 2>&1 | grep 'Version:' | awk '{print $2}' | cut -d. -f1)
    if [[ "${ver:-0}" -ge 1 ]]; then
      SAMTOOLS="$candidate"
      break
    fi
  fi
done
if [[ -z "$SAMTOOLS" ]]; then
  echo "  ❌ samtools 1.x が見つかりません（brew install samtools）"
  MISSING=1
else
  echo "  ✅ samtools: $SAMTOOLS"
fi

if [[ $MISSING -eq 1 ]]; then
  echo ""
  echo "インストール方法:"
  echo "  brew install samtools htslib"
  exit 1
fi
echo "  ✅ 全ての依存ツールが揃っています"

# ─── 引数チェック ───────────────────────────────────────────────
BAM="${1:-}"
REF="${2:-}"

if [[ -z "$BAM" || -z "$REF" ]]; then
  echo "使い方: bash scripts/setup_viewer.sh <BAM> <FASTA>"
  echo "例:     bash scripts/setup_viewer.sh n2_sorted.bam reference.fa"
  exit 1
fi

[[ -f "$BAM" ]]     || { echo "❌ BAMが見つかりません: $BAM"; exit 1; }
[[ -f "${BAM}.bai" ]] || { echo "❌ BAIが見つかりません: ${BAM}.bai"; exit 1; }
[[ -f "$REF" ]]     || { echo "❌ FASTAが見つかりません: $REF"; exit 1; }

SAMTOOLS="${SAMTOOLS:-/opt/homebrew/bin/samtools}"
command -v "$SAMTOOLS" &>/dev/null || SAMTOOLS="samtools"

echo "========================================"
echo " Alignment Viewer セットアップ"
echo " BAM : $BAM"
echo " REF : $REF"
echo "========================================"

# ─── Step 1: リファレンスインデックス ──────────────────────────
echo ""
echo "Step 1/4: リファレンスのインデックス作成..."
if [[ ! -f "${REF}.fai" ]]; then
  "$SAMTOOLS" faidx "$REF"
  echo "   → ${REF}.fai 作成"
else
  echo "   → ${REF}.fai は既存のものを使用"
fi

# ─── Step 2: JSON生成 ───────────────────────────────────────────
echo ""
echo "Step 2/4: JSON生成 (coverage_bins / peak_loci)..."
SAMTOOLS="$SAMTOOLS" python3 scripts/make_jsons.py "$BAM"

# ─── Step 3: リファレンスFASTA抽出・変換 ───────────────────────
echo ""
echo "Step 3/4: リファレンスFASTA抽出（リードありscaffoldのみ）..."

# scaffoldリスト作成
python3 -c "
import json
with open('output/peak_loci.json') as f:
    data = json.load(f)
for d in data:
    print(d['chr'])
" > scaffold_list.txt
echo "   → $(wc -l < scaffold_list.txt | tr -d ' ') scaffolds"

# 抽出
echo "   抽出中（時間がかかる場合あります）..."
xargs "$SAMTOOLS" faidx "$REF" < scaffold_list.txt > reads_ref_all.fa

# 60文字/行に変換（IGV.js互換）
echo "   60文字/行に変換中..."
python3 << 'PYEOF'
with open('reads_ref_all.fa') as fin, open('reads_ref60.fa', 'w') as fout:
    seq, name = [], None
    def flush():
        if name:
            fout.write(name + '\n')
            s = ''.join(seq)
            for i in range(0, len(s), 60):
                fout.write(s[i:i+60] + '\n')
    for line in fin:
        line = line.rstrip()
        if line.startswith('>'):
            flush(); name = line; seq = []
        else:
            seq.append(line)
    flush()
PYEOF
rm -f reads_ref_all.fa

# インデックス作成
"$SAMTOOLS" faidx reads_ref60.fa
echo "   → reads_ref60.fa ($(du -sh reads_ref60.fa | cut -f1)) 作成"

# ─── Step 4: igv.html のURL更新 ────────────────────────────────
echo ""
echo "Step 4/4: igv.html を更新中..."

BAM_BASENAME="$(basename "$BAM")"

python3 << PYEOF
import re

with open('igv.html') as f:
    html = f.read()

# BAM URLを更新
html = re.sub(
    r"url: BASE \+ '/[^']+\.bam'",
    "url: BASE + '/${BAM_BASENAME}'",
    html
)
html = re.sub(
    r"indexURL: BASE \+ '/[^']+\.bam\.bai'",
    "indexURL: BASE + '/${BAM_BASENAME}.bai'",
    html
)
# FASTA URLを更新（reads_ref60.faを常に使用）
html = re.sub(
    r"fastaURL: BASE \+ '/[^']+'",
    "fastaURL: BASE + '/reads_ref60.fa'",
    html
)
html = re.sub(
    r"indexURL: BASE \+ '/[^']+\.fai'",
    "indexURL: BASE + '/reads_ref60.fa.fai'",
    html
)

with open('igv.html', 'w') as f:
    f.write(html)
print('   → igv.html 更新完了')
PYEOF

# ─── 完了 ──────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ✅ セットアップ完了！"
echo ""
echo " 起動コマンド:"
echo "   python3 scripts/range_server.py"
echo ""
echo " ブラウザ:"
echo "   http://localhost:8765/igv.html"
echo "========================================"
