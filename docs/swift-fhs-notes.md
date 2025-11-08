# Swift FHS ビルドログ（Stage 2）

- 実行日時: 2025-11-08 01:10 JST
- コマンド: `nix build .#swiftFHS -L -o swiftFHS-result`
- 結果: 成功（警告はローカルツリーが dirty である旨のみ）。出力シンボリックリンク `swiftFHS-result` を `swift-6.1.3-fhs` に向けて生成。

DevShell 同様 FHS ランタイム単体を Nix ストアに閉じ込められることを確認。今後 Stage 3 で `hazkey-server` から呼び出す際はこの derivation を `hazkeySwiftToolchain` として参照する。
