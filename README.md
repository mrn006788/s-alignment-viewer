# 🧬 Alignment Viewer

A browser-based BAM alignment viewer built on IGV.js.  
The left sidebar lists scaffolds sorted by read count. Click a scaffold to jump to the read-dense region automatically.

---

## Requirements

| Tool | Check | Install (Mac) |
|------|-------|---------------|
| Python 3 | `python3 --version` | Built-in |
| samtools 1.x | `samtools --version` | `brew install samtools` |
| htslib (bgzip) | `bgzip --version` | `brew install htslib` |

> **No Homebrew?**  
> `curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash`

---

## Quick Start

### 1. Place your data files

Put the following files in this folder (not included in the repository):

```
sample.bam        ← sorted BAM file
sample.bam.bai    ← BAM index (created with: samtools index sample.bam)
reference.fa      ← reference genome (FASTA)
```

> If your BAM is not sorted:
> ```bash
> samtools sort input.bam -o sample.bam
> samtools index sample.bam
> ```

### 2. Run setup

```bash
bash scripts/setup_viewer.sh sample.bam reference.fa
```

Takes a few minutes on first run (extracting reference sequences).

### 3. Start the server and open the browser

```bash
python3 scripts/range_server.py
```

Then open → **http://localhost:8765/igv.html**

Press `Ctrl + C` to stop the server.

---

## Using the App Launcher

**Double-click** `AlignmentViewer.command` (or `AlignmentViewer.app`) to start the server and open the browser automatically.

**To use new data**, drag & drop your `.bam` file (and optionally your reference `.fa`) onto `AlignmentViewer.app`. The setup runs automatically in a Terminal window.

---

## Interface

```
┌──────────────────────────────────────────────┐
│ 🔬 IGV Viewer                                │
├──────────────┬───────────────────────────────┤
│ 🔍 Search    │  Start:[    ] End:[    ]       │
│  scaffold    │  [Go] [Peak] [+] [−]          │
│──────────────│───────────────────────────────│
│ scaffold_3   │                               │
│ 76,439 reads │       Alignment display       │
│ ████████░░   │   (click sidebar to navigate) │
│ scaffold_2   │                               │
│ 36,571 reads │                               │
│ ████░░░░░░   │                               │
└──────────────┴───────────────────────────────┘
```

| Action | How |
|--------|-----|
| Select scaffold | Click in the left sidebar |
| Jump to read-dense position | "Peak" button |
| Navigate to coordinates | Enter Start/End then click "Go" |
| Zoom in / out | +/− buttons or mouse wheel |
| Search scaffold | Type in the search box (top-left) |

---

## Switching to a different dataset

```bash
bash scripts/setup_viewer.sh new_sample.bam new_reference.fa
python3 scripts/range_server.py
```

---

## File layout

```
igv.html                    ← main viewer
output/
  all_scaffolds.json        ← scaffold list with read counts
  coverage_bins.json        ← 100 kb bin coverage data
  peak_loci.json            ← peak read positions per scaffold
reads_ref60.fa              ← extracted reference (auto-generated)
reads_ref60.fa.fai          ← its index
scripts/
  setup_viewer.sh           ← setup for new data
  make_jsons.py             ← generates JSON files
  range_server.py           ← HTTP server (Range-request capable)
AlignmentViewer.command     ← double-click launcher (Terminal)
AlignmentViewer.app         ← double-click / drag & drop launcher
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `samtools: command not found` | `brew install samtools` |
| `bgzip: command not found` | `brew install htslib` |
| No reads displayed | Confirm BAM is sorted and indexed |
| Page won't open | Make sure `python3 scripts/range_server.py` is running |
| Jump doesn't work | Re-run `setup_viewer.sh` |
| App won't open | Right-click → Open, or run: `xattr -cr AlignmentViewer.app` |
