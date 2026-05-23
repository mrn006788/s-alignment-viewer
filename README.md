# 🧬 Alignment Viewer

A browser-based BAM alignment viewer built on [IGV.js](https://github.com/igvteam/igv.js).  
The left sidebar lists scaffolds sorted by read count. Click a scaffold to jump to the read-dense region automatically.

> **macOS only** (Apple Silicon & Intel)

---

## Quick Start

### Step 1 — Download the app

Download **AlignmentViewer.app.zip** from the [Releases page](../../releases) and unzip it.  
Move `AlignmentViewer.app` anywhere you like (Desktop, Applications, etc.).

> **First launch only:** macOS may block the app because it is not from the App Store.  
> Right-click → **Open** → **Open** to allow it.  
> If that doesn't work, run in Terminal:
> ```bash
> xattr -cr /path/to/AlignmentViewer.app
> ```

### Step 2 — Install dependencies

The app requires **samtools** and **htslib**. If you don't have them:

```bash
# Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install samtools htslib
```

Verify:
```bash
samtools --version   # should show 1.x or later
bgzip --version
```

### Step 3 — Launch and select your files

Double-click `AlignmentViewer.app`. File picker dialogs will appear:

1. **Select your BAM file** (sorted; index `.bai` is auto-created if missing)
2. **Select your reference FASTA file** (`.fa` / `.fasta` / `.fna`)

A Terminal window will open and run the setup (a few minutes on first run).  
When finished, the viewer opens automatically in your browser.

> **Drag & drop:** You can also drop a BAM + FASTA onto the app icon at the same time.

### Step 4 — Next time: just double-click

Double-clicking `AlignmentViewer.app` restarts the server and reopens the last dataset.  
If setup was already done, you can also choose **Open** when prompted.

---

## Interface

```
┌──────────────────────────────────────────────────┐
│ 🔬 IGV Viewer                                    │
├────────────────┬─────────────────────────────────┤
│ 🔍 Search      │  Start:[      ] End:[      ]    │
│  scaffold…     │  [Go] [Peak] [+] [−]            │
│ Min reads: 1   │─────────────────────────────────│
│ ━━━━━━━━━━━━   │                                 │
│ scaffold_3     │       Alignment display          │
│ 76,439 reads   │   (click sidebar to navigate)   │
│ ████████░░     │                                 │
│ scaffold_2     │                                 │
│ 36,571 reads   │                                 │
│ ████░░░░░░     │                                 │
└────────────────┴─────────────────────────────────┘
```

| Action | How |
|--------|-----|
| Select scaffold | Click in the left sidebar |
| Jump to read-dense region | **Peak** button |
| Navigate to coordinates | Enter Start / End → **Go** |
| Zoom in / out | **+** / **−** buttons or mouse wheel |
| Search scaffold by name | Type in the search box (top-left) |
| Filter by minimum reads | Drag the **Min reads** slider |

---

## Switching to a different dataset

Drop the new `.bam` + `.fa` files onto `AlignmentViewer.app`, or double-click and select new files.  
Setup runs automatically and the viewer switches to the new data.

---

## Preparing your BAM (if needed)

If your BAM is not sorted or indexed:

```bash
samtools sort input.bam -o sample.bam
samtools index sample.bam
```

---

## Requirements

| Tool | Version | Install |
|------|---------|---------|
| Python 3 | 3.8+ | Built-in on macOS |
| samtools | 1.x+ | `brew install samtools` |
| htslib (bgzip) | any | `brew install htslib` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| App won't open | Right-click → Open, or `xattr -cr AlignmentViewer.app` |
| `samtools: command not found` | `brew install samtools` |
| `bgzip: command not found` | `brew install htslib` |
| No reads displayed | Check that BAM is sorted and indexed (`.bai` exists) |
| Browser doesn't open | Open manually: `http://localhost:8765/igv.html` |
| Setup seems stuck | Check the Terminal window for error messages |
| Reference not visible | Zoom in further with **+** or mouse wheel |

---

## For developers

Clone the repository and rebuild the app after editing scripts:

```bash
git clone https://github.com/mrn006788/s-alignment-viewer.git
cd s-alignment-viewer
bash scripts/build_app.sh
```

`build_app.sh` compiles the AppleScript, bundles scripts into the app, and signs it.
