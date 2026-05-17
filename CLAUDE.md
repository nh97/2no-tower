# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

ファンタジー風3Dタワーディフェンス「Magic Tower Defense」。Godot 4.6 (Mobile renderer) で実装、将来的に iOS/Android へエクスポート予定。

## 技術スタック

- **エンジン**: Godot 4.6, GDScript, viewport 1280x720
- **レンダラ**: Mobile (`project.godot::rendering/renderer/rendering_method=mobile`)
- **Autoload**: `GameManager` (グローバル状態/シグナル), `AudioManager` (動的合成SFX + BGMファイル再生)

## 実行コマンド

- **エディタ起動**: Godot で `project.godot` を開く
- **F5**: 実行 (`scenes/main.tscn` がメインシーン)
- テストフレームワークは未導入。動作確認は F5 実機プレイのみ

### Web ビルド / 試遊

- **書き出し**: `godot --headless --export-release "Web" build/web/index.html`
  - 前提: Godot Editor で 4.6.2 stable の Web エクスポートテンプレートをインストール済 (Editor → Manage Export Templates)
- **ローカル試遊**: `cd build/web && python3 -m http.server 8000` → `http://localhost:8000/`
- **GitHub Pages デプロイ**: `main` ブランチに push すると `.github/workflows/deploy.yml` が自動でビルド+デプロイ。公開URL: `https://nh97.github.io/claude_3dcg_test/`
- **設定**: スレッド OFF (`variant/thread_support=false`) で SharedArrayBuffer 不要、静的ホスティングで動作

## ディレクトリ構成

- `scenes/main.tscn` — 唯一のシーン。`World` (Node3D + world.gd) と `UI` (CanvasLayer + ui.gd) を持つだけ
- `scripts/` — 全 GDScript。シーンは持たず、3Dノードは `world.gd._ready` で動的構築
- `audio/bgm.mp3` — BGM (SFXは AudioManager が `AudioStreamWAV` を実行時合成)

## アーキテクチャの重要パターン

### enum Kind + CONFIG 辞書による多態化
タワー (`tower.gd`)・敵 (`enemy.gd`) は **サブクラスを作らず**、`enum Kind` と `const CONFIG := { Kind.X: {...} }` でバリエーションを管理する。新種追加は CONFIG にエントリを足すだけで UI ボタン (`Tower.Kind.values()` で自動生成) や `_build_visual()` が追従する。Projectile も同様にパラメータポリモーフィズム (`aoe_radius`, `slow_amount` 等のフィールドで挙動差を表現)。

### シグナル中心の疎結合
`GameManager` が全状態 (money/lives/wave/state/selected_tower/sell_request/boss_*) のシグナル発火源。UI は `_ready` でこれらに接続するだけ。World/PlacementSlot/Enemy も GameManager のメソッド経由で状態変更し、直接 UI を触らない。

### 動的シーン構築
`world.gd._ready` で環境/カメラ/地面/経路/ゴール/スロット/敵コンテナを全部 `add_child` で組む。`.tscn` はほぼ空。新規ノード追加時は既存の `_build_*` ヘルパーに倣う。

### 3D ピッキングの落とし穴 (重要)
- `Viewport.physics_object_picking = true` を `world.gd._ready` で明示設定しないと `StaticBody3D.input_event` が発火しない
- `CollisionObject3D` 派生 (Area3D 含む) はデフォルトで pickable。クリック対象でないものは **`input_ray_pickable = false`** を必ず設定する (Ground, Tower 本体, Tower の Range Area3D, Enemy Body すべて設定済み)。これを怠ると Tower の射程球などがクリックを横取りしてスロット選択が効かなくなる
- `Camera3D.look_at()` は `add_child` 後に呼ぶ (tree 外では機能しない)

### AudioManager の SFX 設計
SFX は `_make_tone` / `_make_sequence` で PackedByteArray を生成し `AudioStreamWAV` を実行時合成。ファイル不要で動作するが、後日ファイル差し替える場合は `_sfx_streams[SFX.X] = load(path)` の1行置換でOK。プレイヤーはプール (`SFX_POOL_SIZE=6`) でラウンドロビン。

## コーディング規約

- GDScript ファイル先頭で `class_name X extends Y` を宣言 (autoload を除く)
- 型ヒントを明示 (`var x: int`, `func f() -> void`)
- ループ内のローカル変数も型注釈する (例: `var cfg: Dictionary = CONFIG[kind]`)
- UI ラベル/ボタン文言は日本語 + 絵文字でOK (例: `"🪄 魔法"`)
