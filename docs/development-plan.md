# fcitx5-hazkey Development Plan

リポジトリ内での最新のビルド方針・作業手順・未解決事項を一枚に集約したドキュメントです。特に断りが無い限り、`fcitx5-hazkey/` 直下でコマンドを実行します。

---

## 1. 現状とゴール

- SwiftPM manifest は `swift-tools-version: 6.1` のまま維持する。
- Nix で Swift 6.1.3 公式バイナリを取り込み、FHS ユーザ空間越しに実行することで glibc 依存を解消する。
- 最終ゴールは `nix build .#fcitx5-hazkey -L` を単独実行すれば再現ビルドが通る状態。
- **段階目標（小さなゴール）** を順番に達成 → 各段階ごとに git commit を作成し、小さく確実に前進する。

---

## 2. 前提条件

- Linux x86_64、Nix 2.18+（flakes 有効）
- `nixpkgs` チャンネルは `nixos-25.05` を想定
- Zenzai 機能を使う場合は Vulkan 対応 GPU が必須

---

## 3. 日常フロー（Nix ベース）

| #   | コマンド                                                        | 目的                                                                |
| --- | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1   | `git clone --recursive …` → `cd fcitx5-hazkey`                  | ソース取得                                                          |
| 2   | `git pull --rebase` / `git submodule update --init --recursive` | 既存クローンの同期                                                  |
| 3   | `nix develop` _(任意)_                                          | CMake / Ninja / Qt / fcitx5 / Swift 6.1.3 FHS ラッパー入り DevShell |
| 4   | `nix build .#fcitx5-hazkey -L`                                  | 再現ビルド（結果は `result/`）                                      |
| 5   | `nix profile install .#fcitx5-hazkey` _(任意)_                  | ホスト環境へ導入                                                    |

> DevShell 内で `swift --version` を実行することで FHS ラッパーの動作確認が可能。  
> `nix build` は Swift ビルド時に FHS ランタイムを利用するため、ホストに Swift をインストールする必要はない。

---

## 4. 手動ビルド（Nix 不使用環境向け・最終手段）

1. Swift 6.1.3 以上 / fcitx5 / Qt6 / CMake / Ninja / Protobuf / Gettext を OS のパッケージで導入
2. `git clone --recursive …` → `mkdir build && cd build`
3. `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr ..`
4. `ninja` → `sudo ninja install`
5. `fcitx5 -rd` で再起動し、Hazkey を追加

※ Swift ランタイムの `lib` を `LD_LIBRARY_PATH` に通すか、`patchelf` で RPATH を明示すること。

---

## 5. Swift 6.1 ツールチェーン方針（最新版）

1. `flake.nix` で公式 tarball を `fetchurl` → `stdenv.mkDerivation` で展開（`swiftUnwrapped`）。
2. `pkgs.buildFHSUserEnv` で `swiftUnwrapped` + 必要なライブラリ（curl/krb5/ldap など）をまとめた FHS シェルを生成し、`runScript = "${swiftUnwrapped}/bin/swift"` とする。
3. `nix/package.nix` から `hazkeySwiftToolchain` として FHS ラッパーを参照し、CMake には `-DSWIFT_EXECUTABLE=<…>/bin/swift` を渡す。

### TODO（2025-??-?? 時点）

- [ ] `nix build` 実行時に FHS ラッパー内部で `bwrap: setting up uid map: Permission denied` が発生しているため、`buildFHSUserEnvBubblewrap` ではなく `buildFHSUserEnv` へ切り替え済み。以降は `swift build` がサブコマンド呼び出しでも FHS コンテナ内を使うようエントリポイントを確認する。
- [ ] Swift 6.1.3 ランタイムの RPATH をビルド後に `patchelf` で再設定し、`libswiftCore.so` などを実行時に確実に解決する。
- [ ] `nix develop` で `swift --version` が成功することを確認し、手元での手動ビルドを封じて `nix build` のみで CI を回す。

---

## 6. 既知のハマりどころ

- **`ninja: multiple rules generate protocol/*.pb.h`**  
  → C++ / Qt 双方がビルドディレクトリ配下の `generated/` に吐くよう修正済み（`fcitx5-hazkey/src`、`hazkey-settings/` の CMakeLists）。
- **Swift ビルドの失敗理由が不明瞭**  
  → `hazkey-server/build_swift.cmake` に標準出力 / 標準エラーをそのまま表示するログを追加済み。失敗時はログに現れる `bwrap` / `libcurl.so` などを順次潰す。
- **`buildFHSUserEnv` での sandbox 関連エラー**  
  → rootless ユーザ namespace が無効な環境だと `bwrap` が UID マップを張れずに失敗する。現在は `buildFHSUserEnv` を使い、Bubblewrap 依存を外す方針で調整中。

---

## 7. 今後のアクション（段階ゴール & コミット粒度）

| 段階    | ゴール                                         | チェック内容 / 成果物                                                                                                            | 推奨コミット方針                                    |
| ------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| Stage 1 | Swift FHS ラッパー単体の健全性確認             | `nix develop` → DevShell 内で `swift --version` が通る。`flake.nix` の diff と DevShell 設定のみを含む。                         | `git commit -m "stage1: verify swift fhs devshell"` |
| Stage 2 | Swift FHS パッケージ単体ビルド確認             | `nix build .#swiftFHS` などで Swift ランタイムと依存が Nix ストア内に収まる。ログ/メモを `docs/` に残す。                        | `git commit -m "stage2: build swift fhs package"`   |
| Stage 3 | `hazkey-server` Swift ターゲット単独ビルド成功 | CMake で Swift 部分のみをビルドし、RPATH / `libswiftCore.so` を解決。必要なら `patchelf` スクリプトを `nix/package.nix` に追加。 | `git commit -m "stage3: hazkey server swift build"` |
| Stage 4 | フル `nix build .#fcitx5-hazkey -L` 成功       | ストア内のみで完結するビルド。CI 連携と `docs/development-plan.md` の更新。                                                      | `git commit -m "stage4: full reproducible build"`   |

> 各 Stage は「完了条件を満たしたら即コミット」を徹底し、キャッシュ再生成やログ調整など細部は同じステージ内で追随コミットを作成する。Stage 間の依存が崩れた場合は直近のステージのコミットに戻って原因を切り分ける。

1. Stage 1 に取り組み、DevShell で Swift が起動するところまでを最優先で固める。
2. Stage 2 では Swift FHS パッケージのみをビルド対象にして、C++/Qt ビルドから切り離したまま依存解決を完了させる。
3. Stage 3 で Swift ターゲットを CMake から呼び出した際の RPATH・ランタイム問題を潰す。
4. Stage 4 として `nix build .#fcitx5-hazkey -L` が通ることを確認し、CI へ適用。成功後に暫定手順を削除してドキュメントを更新する。

---

## 8. 作業メモ（2025-11-08）

- Stage 1 / Stage 2 コミットをクリーンツリーで再検証済み（`git stash push` → 各コミット checkout → `nix develop … swift --version` / `nix build .#swiftFHS` → `git stash pop`）。
- Stage 3 着手中。`nix develop` 内で `cmake -S hazkey-server -B build-hazkey` → `cmake --build build-hazkey` を実行すると Swift パッケージ解決までは成功したが、`swift build` が C コンパイラに `-target`/`-fblocks` を渡す際に GCC が対応せず失敗。
- Swift FHS 側に `gitMinimal` / `clang` / `gnustep.libobjc` / `glibc.dev` を追加済み。`hazkey-server/build_swift.cmake` では `CC=clang CXX=clang++` を `cmake -E env` で注入する形に修正したところで終了。
- 再開時は `build-hazkey/` を一度削除してから `nix develop path:. -c bash -lc 'cmake -S hazkey-server -B build-hazkey -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build-hazkey'` を実行し、`swift build` が clang 経由で完走するかを確認。必要なら `SWIFT_COMMAND` に `-Xcc -fblocks` 等を明示する。
- 以降も Stage 完了前の検証は **stash → clean checkout → コマンド実行 → stash pop** のフローを必ず踏む。
- Stage 4 試行（2025-11-08 夜）：`fcitx5-hazkey/src` / `hazkey-settings` の proto 出力を `generated/` に固定して `nix build .#fcitx5-hazkey -L` を再実行。C++/Qt ビルドは通るが、Swift 側が引き続き FHS ユーザ空間（bubblewrap）に依存しており、Nix サンドボックス内では `bwrap: setting up uid map: Permission denied` → `swift build` が実行不能。根本解としては FHS を経由せず、公式 Swift ツールチェーン tarball を `patchelf --set-interpreter ... --set-rpath ...` あるいは `makeWrapper` で `LD_LIBRARY_PATH` を注入する形で直接起動できる derivation を用意すること（bubblewrap 非依存の Swift ランタイムを `hazkeySwiftToolchain` として使う）を優先する。

### TODO（2025-11-08 追記）

- [x] `flake.nix` に Swift 用 sysroot (`swiftSdk`) を追加し、`swiftc` ラッパーで `LD_LIBRARY_PATH` / `LIBRARY_PATH` を固定。
- [x] `nix/package.nix`・`hazkey-server/CMakeLists.txt`・`build_swift.cmake` を更新して `SWIFT_SDK_PATH` / `LIBRARY_PATH` を正しく受け渡し。
- [ ] SwiftPM 依存（AzooKeyKanaKanjiConverter / swift-protobuf など 8 件）を `fetchgit` / `fetchFromGitHub` で Nix ストアに取り込み、`mirrors.json` を自動生成してネットワーク不要化。
- [ ] `nix build .#fcitx5-hazkey -L` を再実行し、Swift ビルド完走と `.build/.../hazkey-server` の取得を確認。
- [ ] 成功ログと手順を本ドキュメントに反映し、Stage 4 コミットを作成。
