# 🧬 Alignment Viewer — n1

BAMファイルのカバレッジ・アライメントを視覚的に探索するWebビューア。

## 公開版（GitHub Pages）

📊 **Plotlyチャート**（ゲノム全体俯瞰・カバレッジ詳細）はブラウザのみで動作。  
🔬 **IGV リードビューア**はローカルサーバが必要。

## ローカル起動

```bash
bash scripts/serve-viewer.sh
# → http://localhost:8765/index.html
```

## ファイル構成

```
index.html              ← メインビューア（GitHub Pages対応版）
output/
  all_scaffolds.json    ← scaffold一覧（28,176件）
  coverage_bins.json    ← カバレッジデータ（1,060 scaffolds）
  viewer.html           ← ローカル専用ビューア（旧版）
scripts/
  serve-viewer.sh       ← ローカルHTTPサーバ起動
  hourly-log.sh         ← 定期ログ取得
  install-cron.sh       ← cron設定
```

> **注意**: BAMファイル・FASTAファイルは `.gitignore` により除外されています。  
> ローカル実行には `n1_sorted.bam`, `n1_sorted.bam.bai`, `reference.fa`, `reference.fa.fai` が必要です。
