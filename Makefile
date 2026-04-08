DEFAULT_GOAL := help

.PHONY: help check test demo riscv-tests riscv-tests-podman rv32ui-qemu c-sample-build c-sample-run c-sample smoke ci-local

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make smoke             # quick local confidence path' \
	  '  make ci-local          # local approximation of CI' \
	  '  make rv32ui-qemu       # cross-check official rv32ui gating subset in qemu-system-riscv32' \
	  '  make c-sample          # build and run the freestanding RV32I C sample' \
	  '' \
	  'Core targets:' \
	  '  make check             # run moon check' \
	  '  make test              # run moon test (expects official ELF artifacts to exist)' \
	  '  make demo              # run the MoonBit bootstrap demo' \
	  '' \
	  'Artifact targets:' \
	  '  make riscv-tests       # build the official riscv-tests subset from the manifest' \
	  '  make riscv-tests-podman # build the official riscv-tests subset in podman' \
	  '  make c-sample-build    # build the freestanding RV32I C sample ELF' \
	  '  make c-sample-run      # build and run the freestanding RV32I C sample'

check:
	moon check

test:
	moon test

demo:
	moon run cmd/main

riscv-tests:
	./scripts/build-riscv-tests-official.sh

riscv-tests-podman:
	./scripts/build-riscv-tests-official-in-podman.sh

rv32ui-qemu:
	./scripts/cross-check-official-rv32ui-with-qemu.pl

c-sample-build:
	./scripts/build-rv32i-c-sample.sh

c-sample-run:
	./scripts/run-rv32i-c-sample.sh

c-sample: c-sample-run

smoke: check test c-sample-run

ci-local: riscv-tests check test
