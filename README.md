# 🧬 Alignment Viewer

BAMファイルのアライメントをブラウザで視覚的に探索するツールです。  
左サイドバーでscaffoldを選ぶとリードが多い場所に自動でジャンプします。

---

## 必要なもの

| ツール | 確認コマンド | インストール（Mac） |
|--------|-------------|-------------------|
| Python 3 | `python3 --version` | 標準で入っている |
| samtools 1.x | `samtools --version` | `brew install samtools` |
| htslib | `bgzip --version` | `brew install htslib` |

> **Homebrew がない場合:**  
> `curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash`

---

## クイックスタート

### 1. データファイルを配置する

このフォルダに以下のファイルを置く（GitHubには含まれていません）：

```
sample.bam        ← ソート済みBAMファイル
sample.bam.bai    ← BAMインデックス（samtools index で作成）
reference.fa      ← リファレンスゲノム（FASTA）
```

> BAMがソートされていない場合:
> ```bash
> samtools sort input.bam -o sample.bam
> samtools index sample.bam
> ```

### 2. セットアップを実行する

```bash
bash scripts/setup_viewer.sh sample.bam reference.fa
```

初回は数分かかります（リファレンス抽出のため）。

### 3. サーバを起動してブラウザで開く

```bash
python3 scripts/range_server.py
```

ブラウザで → **http://localhost:8765/igv.html**

終了するには `Ctrl + C`。

---

## 使い方

```
┌──────────────────────────────────────────────┐
│ 🔬 IGV Viewer                                │
├──────────────┬───────────────────────────────┤
│ 🔍 scaffold  │  Start:[    ] End:[    ]       │
│  を検索      │  [移動] [ピークへ] [＋] [－]  │
│──────────────│───────────────────────────────│
│ scaffold_3   │                               │
│ 76,439 reads │      リード表示エリア          │
│ ████████░░   │   （クリックで選択した場所へ） │
│ scaffold_2   │                               │
│ 36,571 reads │                               │
│ ████░░░░░░   │                               │
└──────────────┴───────────────────────────────┘
```

| 操作 | 方法 |
|------|------|
| scaffold を選ぶ | 左サイドバーをクリック |
| リード集中位置へ移動 | 「ピークへ」ボタン |
| 任意の座標へ移動 | Start/End を入力して「移動」 |
| 拡大・縮小 | ＋／－ボタン、またはマウスホイール |
| scaffold を検索 | 左上の検索ボックスに名前を入力 |

---

## 別のサンプルに切り替えるとき

```bash
bash scripts/setup_viewer.sh new_sample.bam new_reference.fa
python3 scripts/range_server.py
```

---

## ファイル構成

```
igv.html                    ← メインビューア
output/
  all_scaffolds.json        ← scaffold一覧
  coverage_bins.json        ← カバレッジデータ
  peak_loci.json            ← scaffold別ピーク位置
reads_ref60.fa              ← 抽出済みリファレンス（自動生成）
reads_ref60.fa.fai          ← そのインデックス
scripts/
  setup_viewer.sh           ← セットアップ（新データ時に実行）
  make_jsons.py             ← JSON生成スクリプト
  range_server.py           ← HTTPサーバ（IGV用）
  serve-viewer.sh           ← 旧サーバ（非推奨）
```

---

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `samtools: command not found` | `brew install samtools` を実行 |
| `bgzip: command not found` | `brew install htslib` を実行 |
| リードが表示されない | BAMがソート・インデックス済みか確認 |
| ページが開かない | `python3 scripts/range_server.py` が起動しているか確認 |
| ジャンプしない | `setup_viewer.sh` を再実行 |
