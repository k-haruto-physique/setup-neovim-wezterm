# claude/ — Claude Code statusLine

Claude Code 入力欄の真上に出る 2 段ステータスラインの**正本一式**。
（2026-06-18 に旧独立リポ `Repositories/statusline` を本リポへ合体・退役。以降はここが唯一の正本。表示レイヤーは 2026-05-21 に WezTerm addon から Claude Code 内蔵 `statusLine` へ移管済。）

## ファイル

| ファイル | 用途 |
|---|---|
| `statusline.ps1` | **正本スクリプト**（`statusLine.command` から呼ばれる）。`~/.claude/statusline.ps1` へ配置（現状は symlink 切れの実体コピー＝ハッシュ一致。次に編集したら再リンク要 → backlog W1） |
| `statusline-spec.md` | **設計仕様**（カラーパレット / アイコン / 数値セマンティクス / データソース / 既知の罠 / 変遷ログ / 技術的負債） |
| `CHANGELOG.md` | 修正履歴（2026-06-15 stdin StreamReader 化バグ修正ほか） |

## アーキテクチャ

```
Claude Code が JSON を stdin に流す
  → statusline.ps1 がパース
  → 2 行を stdout に出力
  → Claude Code が入力欄の上に描画
```

更新トリガー（公式仕様）: 新規アシスタント応答ごと / `/compact` 完了時 / パーミッションモード変更時 / vim モードトグル時（300ms デバウンス）。詳細仕様は `statusline-spec.md`。

## 既知の制約

- **コンテキスト残量**は Claude Code stdin 専用値のため外部からは取得不可。
- **週間使用制限残量**は ccusage では取れず、Anthropic 非公開 OAuth (`/api/oauth/usage`) が必要。

## 参考

- [ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline) — UI デザイン参考
- [ccusage](https://github.com/ryoppippi/ccusage) — 使用データ取得 CLI
