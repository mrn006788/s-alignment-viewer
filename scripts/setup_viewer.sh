#!/usr/bin/env bash
# setup_viewer.sh — Set up the viewer for a new BAM / reference pair
#
# Usage:
#   bash scripts/setup_viewer.sh <BAM file> <FASTA file>
#
# Example:
#   bash scripts/setup_viewer.sh n2_sorted.bam reference.fa

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# ─── Dependency check ──────────────────────────────────────────────
echo "Checking dependencies..."
MISSING=0
for cmd in python3 bgzip; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "  ❌ $cmd not found"
    MISSING=1
  fi
done

# Find samtools 1.x
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
  echo "  ❌ samtools 1.x not found (brew install samtools)"
  MISSING=1
else
  echo "  ✅ samtools: $SAMTOOLS"
fi

if [[ $MISSING -eq 1 ]]; then
  echo ""
  echo "Install missing tools with:"
  echo "  brew install samtools htslib"
  exit 1
fi
echo "  ✅ All dependencies found"

# ─── Argument check ────────────────────────────────────────────────
BAM="${1:-}"
REF="${2:-}"

if [[ -z "$BAM" || -z "$REF" ]]; then
  echo "Usage: bash scripts/setup_viewer.sh <BAM> <FASTA>"
  echo "Example: bash scripts/setup_viewer.sh n2_sorted.bam reference.fa"
  exit 1
fi

[[ -f "$BAM" ]]       || { echo "❌ BAM not found: $BAM"; exit 1; }
[[ -f "${BAM}.bai" ]] || { echo "❌ BAI not found: ${BAM}.bai"; exit 1; }
[[ -f "$REF" ]]       || { echo "❌ FASTA not found: $REF"; exit 1; }

echo "========================================"
echo " Alignment Viewer Setup"
echo " BAM : $BAM"
echo " REF : $REF"
echo "========================================"

# ─── Step 1: Reference index ───────────────────────────────────────
echo ""
echo "Step 1/4: Indexing reference..."
if [[ ! -f "${REF}.fai" ]]; then
  "$SAMTOOLS" faidx "$REF"
  echo "   → ${REF}.fai created"
else
  echo "   → ${REF}.fai already exists"
fi

# ─── Step 2: Generate JSON files ───────────────────────────────────
echo ""
echo "Step 2/4: Generating JSON (coverage_bins / peak_loci)..."
SAMTOOLS="$SAMTOOLS" python3 scripts/make_jsons.py "$BAM"

# ─── Step 3: Extract & reformat reference FASTA ────────────────────
echo ""
echo "Step 3/4: Extracting reference sequences (scaffolds with reads)..."

# Build scaffold list
python3 -c "
import json
with open('output/peak_loci.json') as f:
    data = json.load(f)
for d in data:
    print(d['chr'])
" > scaffold_list.txt
echo "   → $(wc -l < scaffold_list.txt | tr -d ' ') scaffolds"

# Extract
echo "   Extracting (this may take a while)..."
xargs "$SAMTOOLS" faidx "$REF" < scaffold_list.txt > reads_ref_all.fa

# Reformat to 60-char/line (required for IGV.js)
echo "   Reformatting to 60 chars/line..."
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

# Index
"$SAMTOOLS" faidx reads_ref60.fa
echo "   → reads_ref60.fa ($(du -sh reads_ref60.fa | cut -f1)) created"

# ─── Step 4: Update igv.html URLs ──────────────────────────────────
echo ""
echo "Step 4/4: Updating igv.html..."

BAM_BASENAME="$(basename "$BAM")"

python3 << PYEOF
import re

with open('igv.html') as f:
    html = f.read()

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
print('   → igv.html updated')
PYEOF

# ─── Done ──────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ✅ Setup complete!"
echo ""
echo " Start the viewer:"
echo "   python3 scripts/range_server.py"
echo ""
echo " Then open:"
echo "   http://localhost:8765/igv.html"
echo "========================================"
