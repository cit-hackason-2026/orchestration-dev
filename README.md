# orchestration-dev

CIT ハッカソン 2026 「Arduino オーケストラ」開発リポジトリ。
4 つの楽器 (clarinet / flute / organ / percussion) を Arduino と Processing で制御し、同期演奏を行うプロジェクトです。

## ディレクトリ構成

```
orchestration-dev/
├── README.md                  ← このファイル
├── sync/                      ← 全楽器共通の同期方針・共通コード
│   ├── README.md
│   ├── 同期方針計画書.html / .md   ← 同期方針の本体 (HTML と Markdown の 2 形式)
│   ├── arduino/               ← 全楽器共通の Arduino コード (マスター時計等)
│   ├── processing/            ← 全楽器共通の Processing コード (指揮者 UI 等)
│   └── memo/                  ← 同期に関する自由スペース
├── clarinet/
│   ├── README.md
│   ├── clarinet_design.html             ← 楽器設計資料
│   ├── clarinet_design_answers.json     ← 設計シートの回答 (自分で埋める)
│   ├── arduino/                         ← Arduino スケッチ (.ino)
│   ├── processing/                      ← Processing スケッチ (.pde)
│   ├── sound/                           ← 音源と FFT スペクトル
│   │   ├── sample/                      ← 目標とする音 (本物の楽器録音など)
│   │   ├── output/                      ← 実際にこの楽器で作れた音
│   │   └── spectrum/                    ← FFT で解析したスペクトル画像
│   └── memo/                            ← 自由スペース (写真・メモ等何でもOK)
├── flute/        (同上の構成)
├── organ/        (同上の構成)
└── percussion/   (同上の構成)
```

各楽器ディレクトリの中に、その楽器固有の Arduino と Processing のコードを置きます。
全楽器で共通の同期方針 (タイミング・通信・テンポなど) は [`sync/同期方針計画書.html`](sync/同期方針計画書.html) を参照してください。

---

## はじめての方へ — Git / GitHub の使い方

このリポジトリは **GitHub の Issue と Pull Request** で作業を管理します。
「これから作業するぞ」「直したぞ」を Issue / PR として残すことで、誰が何をやっているかチームで共有できます。

### 1. リポジトリを手元に取ってくる (clone)

最初の一回だけ実行します。

```bash
git clone https://github.com/cit-hackason-2026/orchestration-dev.git
cd orchestration-dev
```

### 2. 最新を取り込む (pull)

作業を始める前に、必ず `main` の最新を取り込みます。
これをやらないと、他の人の変更とぶつかって面倒になります。

```bash
git checkout main
git pull origin main
```

---

## Issue のやり方

Issue は「やるべきこと / 困っていること」を 1 件 1 枚のチケットとして残す仕組みです。
**作業を始める前に Issue を立てる** のが基本です。

### Issue を立てる手順

1. GitHub の本リポジトリページを開く
   → https://github.com/cit-hackason-2026/orchestration-dev
2. 上部メニューの **「Issues」** タブをクリック
3. 緑色の **「New issue」** ボタンを押す
4. 以下を埋めて **「Submit new issue」** で作成

### Issue に書くこと (テンプレ)

```markdown
## 概要
何をやるのか / 何が起きているのかを 1〜2 行で

## 背景・目的
なぜこれをやるのか (例: 「同期方針計画書の §2 に従ってクラリネットの音程テストを行うため」)

## やること (チェックリスト)
- [ ] Arduino で MIDI ノート受信を実装
- [ ] Processing 側からテストデータを送信
- [ ] 動作確認

## 関連資料
- 設計資料: clarinet/clarinet_design.html
- 同期方針: sync/同期方針計画書.html
```

### Issue のタイトルの付け方

タイトルは **「動詞 + 対象」** で簡潔に。

| 良い例 | よくない例 |
|---|---|
| `clarinet: ノート受信を実装する` | `お願い` |
| `flute: ピッチがずれるバグを直す` | `バグ` |
| `organ: 設計資料を更新する` | `更新` |

楽器名を頭に付けると、誰が見るべき Issue かすぐ分かります。

### ラベル (label) を付ける

Issue の右側の「Labels」から種類を選びます。最初は以下くらいでOK:

- `bug` … 動かない / 壊れている
- `enhancement` … 新機能を追加する
- `question` … 相談・質問
- `clarinet` / `flute` / `organ` / `percussion` … 担当楽器

### 担当 (Assignees) を付ける

「自分がやる」と決めたら、右側の「Assignees」で自分を割り当ててください。
**Assignee がいない Issue = 誰もやっていない** という運用にすると、放置を防げます。

---

## ブランチを切ってコードを書く

`main` ブランチに直接コミットしないでください。 Issue ごとに **作業用ブランチ** を切ります。

```bash
# Issue #12 の作業を始める例
git checkout -b feature/12-clarinet-midi
```

ブランチ名の付け方の例:

- `feature/<issue番号>-<短い説明>` … 新機能
- `fix/<issue番号>-<短い説明>` … バグ修正

例: `feature/12-clarinet-midi`, `fix/7-flute-pitch-drift`

**すでにあるブランチに移動するとき** は `-b` を付けずに `git checkout <ブランチ名>`:

```bash
git checkout main                       # main に戻る
git checkout feature/12-clarinet-midi   # 作業中のブランチに戻る
```

---

## コミットの書き方

こまめにコミットしましょう。1 コミット = 1 つの意味のある変更が目安です。

```bash
git add .
git commit -m "clarinet: MIDI ノート受信処理を追加"
```

> `git add .` は **今いるディレクトリ以下の変更を全部** ステージに上げます。簡単ですが、関係ないファイルまで巻き込まないよう、コミット前に `git status` で何が含まれているか必ず確認してください。

### 一部のファイルだけコミットしたいとき

`git add .` だと余計な変更まで含まれてしまうことがあります。
**特定のファイルだけ** をコミットしたいときは、ファイル名を直接指定します。

```bash
# 1 ファイルだけ
git add clarinet/arduino/clarinet.ino

# 複数ファイルをまとめて (スペース区切り)
git add clarinet/arduino/clarinet.ino clarinet/processing/clarinet.pde

# ディレクトリ単位で
git add clarinet/arduino/
```

ステージに上げるファイルを選んだら、 `git status` で **緑色 (Changes to be committed)** に出ているファイルだけがコミットに含まれることを確認してから `git commit -m "..."` してください。

> **どっちを使うべき?**
> - 自分が変更したのが 1 件の作業に関するものだけ → `git add .` でOK
> - 複数の作業が混ざっている / 設定ファイルが意図せず変わっている → ファイル指定の方が安全

メッセージは **「楽器名: 何をしたか」** の形にすると見やすいです。

---

## Pull Request (PR) を出す

ブランチで作業が終わったら、 `main` に取り込んでもらうために PR を出します。

```bash
git push origin feature/12-clarinet-midi
```

push した後に GitHub のページを開くと、 PR 作成のボタンが出てきます。

### PR に書くこと

```markdown
## 概要
何を変えたか (1〜3 行)

## 関連 Issue
Closes #12

## 動作確認
- [ ] Arduino で書き込みが成功する
- [ ] Processing から送信したノートが鳴る
```

> **コツ:** 本文に `Closes #12` と書くと、 PR がマージされたとき自動で Issue #12 が閉じます。

### レビューしてもらう

右側の **「Reviewers」** からチームメンバーを指定。
レビュアーが OK を出したら **「Merge pull request」** で `main` に取り込みます。

---

## よくあるトラブル

| 状況 | 対処 |
|---|---|
| `git pull` で conflict が出た | 慌てず `<<<<<<<` のある行を編集して解決 → `git add` → `git commit` |
| 間違えて `main` で作業してしまった | `git checkout -b feature/xxx` で今いる変更ごと新ブランチに移動できる |
| push したら拒否された | だいたい `git pull origin main` してから再 push で直る |
| よく分からない | **遠慮なく Issue に `question` ラベルで質問を立てる** |

---

