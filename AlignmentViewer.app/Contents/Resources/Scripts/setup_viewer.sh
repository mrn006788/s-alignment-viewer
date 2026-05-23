#!/usr/bin/env bash
# setup_viewer.sh — Set up the viewer for a new BAM / reference pair
#
# Usage:
#   bash setup_viewer.sh <BAM file> <FASTA file> [workspace dir]
#
# Arguments:
#   BAM file      : sorted, indexed BAM
#   FASTA file    : reference genome
#   workspace dir : output directory (default: directory containing BAM)
#
# Environment:
#   SCRIPTS_DIR   : directory containing make_jsons.py (default: this script's dir)
#   IGV_TEMPLATE  : path to igv.html template (optional)

set -euo pipefail

# Script's own directory (works whether called from anywhere)
SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"

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
  echo "Usage: bash setup_viewer.sh <BAM> <FASTA> [workspace]"
  echo "Example: bash setup_viewer.sh sample.bam reference.fa /path/to/workspace"
  exit 1
fi

# Resolve absolute paths
BAM="$(cd "$(dirname "$BAM")" && pwd)/$(basename "$BAM")"
REF="$(cd "$(dirname "$REF")" && pwd)/$(basename "$REF")"

# Workspace: 3rd argument, or directory containing BAM
WORKSPACE="${3:-$(dirname "$BAM")}"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

[[ -f "$BAM" ]]       || { echo "❌ BAM not found: $BAM"; exit 1; }
[[ -f "${BAM}.bai" ]] || { echo "❌ BAI not found: ${BAM}.bai"; exit 1; }
[[ -f "$REF" ]]       || { echo "❌ FASTA not found: $REF"; exit 1; }

echo "========================================"
echo " Alignment Viewer Setup"
echo " BAM       : $BAM"
echo " REF       : $REF"
echo " Workspace : $WORKSPACE"
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
echo "Step 2/5: Generating JSON (coverage_bins / peak_loci)..."
SAMTOOLS="$SAMTOOLS" python3 "$SCRIPTS_DIR/make_jsons.py" "$BAM"

# ─── Step 3: Extract & reformat reference FASTA ────────────────────
echo ""
echo "Step 3/5: Extracting reference sequences (scaffolds with reads)..."

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

# ─── Step 4: Copy & update igv.html ───────────────────────────────
echo ""
echo "Step 4/5: Setting up igv.html..."

BAM_BASENAME="$(basename "$BAM")"

# Use template from IGV_TEMPLATE env var, or find igv.html near scripts
IGV_TEMPLATE="${IGV_TEMPLATE:-}"
if [[ -z "$IGV_TEMPLATE" ]]; then
  # Look for template next to scripts dir (app bundle layout)
  CANDIDATE="$(dirname "$SCRIPTS_DIR")/igv.html"
  if [[ -f "$CANDIDATE" ]]; then
    IGV_TEMPLATE="$CANDIDATE"
  fi
fi

# Copy template to workspace if it's not already there (or if template is newer)
if [[ -n "$IGV_TEMPLATE" && "$IGV_TEMPLATE" != "$WORKSPACE/igv.html" ]]; then
  cp "$IGV_TEMPLATE" "$WORKSPACE/igv.html"
  echo "   → igv.html copied from template"
fi

python3 << PYEOF
import re, sys, os

html_path = os.path.join("${WORKSPACE}", "igv.html")
if not os.path.isfile(html_path):
    print("   ⚠️  igv.html not found in workspace, skipping URL update")
    sys.exit(0)

with open(html_path) as f:
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

with open(html_path, 'w') as f:
    f.write(html)
print('   → igv.html updated')
PYEOF

# ─── Step 5: Save last workspace ───────────────────────────────────
echo ""
echo "Step 5/5: Saving workspace path..."
LAST_WS_FILE="$HOME/.alignmentviewer_workspace"
echo "$WORKSPACE" > "$LAST_WS_FILE"
echo "   → $LAST_WS_FILE"

# ─── Done ──────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ✅ Setup complete!"
echo ""
echo " Workspace: $WORKSPACE"
echo " Start the viewer:"
echo "   python3 $SCRIPTS_DIR/range_server.py $WORKSPACE"
echo ""
echo " Then open:"
echo "   http://localhost:8765/igv.html"
echo "========================================"
