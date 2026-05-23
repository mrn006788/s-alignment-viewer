#!/usr/bin/env python3
"""
Generate JSON files from a BAM file:
  output/all_scaffolds.json   - all scaffolds with read counts
  output/coverage_bins.json   - 100 kb bin coverage per scaffold
  output/peak_loci.json       - peak read position per scaffold

Usage:
  python3 scripts/make_jsons.py <BAM file>
"""
import json, subprocess, sys, os

BAM = sys.argv[1] if len(sys.argv) > 1 else 'n1_sorted.bam'
BIN_SIZE = 100_000
SAMTOOLS = os.environ.get('SAMTOOLS', 'samtools')
OUT = 'output'
os.makedirs(OUT, exist_ok=True)

# ─── 1. all_scaffolds.json ─────────────────────────────────────────
print('① Getting scaffold list (samtools idxstats)...')
res = subprocess.run([SAMTOOLS, 'idxstats', BAM],
                     capture_output=True, text=True, check=True)
all_scaffolds = []
for line in res.stdout.strip().split('\n'):
    cols = line.split('\t')
    if len(cols) < 3 or cols[0] == '*':
        continue
    chr_name, length, reads = cols[0], int(cols[1]), int(cols[2])
    all_scaffolds.append({
        'chr': chr_name,
        'len': length,
        'reads': reads,
        'mapped': reads > 0,
    })

with open(f'{OUT}/all_scaffolds.json', 'w') as f:
    json.dump(all_scaffolds, f, separators=(',', ':'))
print(f'   → {len(all_scaffolds)} scaffolds saved')

# ─── 2. coverage_bins.json ─────────────────────────────────────────
print('② Computing coverage bins (100 kb/bin)...')
mapped = [s for s in all_scaffolds if s['reads'] > 0]
cov_bins = []

for i, s in enumerate(mapped):
    chr_name = s['chr']
    length = s['len']
    num_bins = (length + BIN_SIZE - 1) // BIN_SIZE
    bins = [0] * num_bins

    res = subprocess.run([SAMTOOLS, 'view', BAM, chr_name],
                         capture_output=True, text=True, timeout=60)
    for line in res.stdout.strip().split('\n'):
        if not line:
            continue
        cols = line.split('\t')
        if len(cols) > 3:
            pos = int(cols[3])
            idx = (pos - 1) // BIN_SIZE
            if 0 <= idx < num_bins:
                bins[idx] += 1

    covered = sum(1 for b in bins if b > 0)
    cov_bins.append({
        'chr': chr_name,
        'len': length,
        'total_reads': s['reads'],
        'covered_bins': covered,
        'num_bins': num_bins,
        'bins': bins,
    })

    if (i + 1) % 50 == 0 or (i + 1) == len(mapped):
        print(f'   {i+1}/{len(mapped)} done')

with open(f'{OUT}/coverage_bins.json', 'w') as f:
    json.dump(cov_bins, f, separators=(',', ':'))
print(f'   → {len(cov_bins)} scaffolds saved')

# ─── 3. peak_loci.json ─────────────────────────────────────────────
print('③ Computing peak positions...')
cov_sorted = sorted(cov_bins, key=lambda d: d['total_reads'], reverse=True)
peaks = []

for i, d in enumerate(cov_sorted):
    chr_name = d['chr']
    bins = d['bins']
    peak_i = max(range(len(bins)), key=lambda i: bins[i]) if bins else 0
    bin_start = peak_i * BIN_SIZE
    bin_end   = (peak_i + 1) * BIN_SIZE

    # For top 50 scaffolds: find the most frequent read position in the peak bin
    if i < 50:
        res = subprocess.run(
            [SAMTOOLS, 'view', BAM, f'{chr_name}:{bin_start}-{bin_end}'],
            capture_output=True, text=True, timeout=15)
        positions = []
        for line in res.stdout.strip().split('\n'):
            cols = line.split('\t')
            if len(cols) > 3:
                try:
                    positions.append(int(cols[3]))
                except ValueError:
                    pass
        if positions:
            peak_pos = max(set(positions), key=positions.count)
        else:
            peak_pos = (bin_start + bin_end) // 2
    else:
        peak_pos = (bin_start + bin_end) // 2

    start = max(1, peak_pos - 500)
    end   = peak_pos + 1000
    peaks.append({
        'chr': chr_name,
        'total_reads': d['total_reads'],
        'len': d['len'],
        'peak_pos': peak_pos,
        'locus': f'{chr_name}:{start}-{end}',
    })

with open(f'{OUT}/peak_loci.json', 'w') as f:
    json.dump(peaks, f, separators=(',', ':'))
print(f'   → {len(peaks)} scaffolds saved')
print('✅ JSON generation complete')
