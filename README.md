# riscv-mbt

MoonBit で育てる汎用 RISC-V エミュレータです。Linux ブートとブラウザ実行は大きな到達点ですが、開発の節目は `RV32I` から始まる ISA とシステム統合のマイルストーンで管理します。

## Current Checkpoint

- AI 向けの運用基盤を repo 内 Markdown で整備済み
- MoonBit プロジェクトを初期化済み
- `RV32I` の base integer core を実装済み
  - branch 全種
  - `OP-IMM` / `OP` の主要整数演算
  - byte / halfword / word load-store
  - `JAL` / `JALR`
  - 代表的な decode / execute / integration tests
- upstream `riscv-tests` の official build path を `scripts/build-riscv-tests-official.sh` で維持
- `podman` 経由で official build toolchain を固定する経路も用意済み
- linked-address ELF loader を追加済みで、official binary の配置自体は受けられる
- minimal `env/p` substrate も追加済みで、official `rv32ui-p-*` gating subset が green
- `moon test` は build 済み official ELF を直接読んで official subset を実行する
- `qemu-system-riscv32` でも同じ official `rv32ui-p-*` gating subset を cross-check 可能
- GitHub Actions でも official `riscv-tests` subset を build して `moon test` を回す
- freestanding な `RV32I` C サンプルも build/run できる

## Next Milestone

- `RV32I` コアと official `riscv-tests` 実行経路は一区切りついたので、次は [RV32IM](docs/tasks/0005-rv32im.md) に進む
- その次は `RV32IMC`、`RV32IMC + Zicsr + Zifencei` を通して「実用的な最初の完成形」まで進める
- `Linux boot` は ISA 拡張の延長ではなく、privileged + MMU + SBI + device model を束ねたシステム統合の関門として扱う

## Read Next

- [Current State](docs/current.md)
- [Roadmap](docs/roadmap.md)
- [Implementation Notes](docs/guides/implementation-notes.md)
- [RV32I Milestone](docs/milestones/01-rv32i.md)
- [Agent Guide](AGENTS.md)

## Commands

```bash
moon check
moon test
moon run cmd/main
./scripts/build-riscv-tests-official.sh
./scripts/build-riscv-tests-official-in-podman.sh
./scripts/cross-check-official-rv32ui-with-qemu.sh
./scripts/build-rv32i-c-sample.sh
./scripts/run-rv32i-c-sample.sh
moon run cmd/c_sample
```
