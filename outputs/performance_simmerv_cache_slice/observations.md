# Simmerv-Inspired Cache Slice Observations

- Reference implementation inspected: `/home/gaato/ghq/github.com/tommythorn/simmerv`
- Relevant reference files: `src/uop_cache.rs`, `src/tlb.rs`, `src/mmu.rs`
- Implemented in `riscv-mbt`: decode cache and Sv39 translation cache
- Deferred: full basic-block/uop executor and common-instruction fast executor split

## Native Linux Boot

- Command: `/usr/bin/time -f 'elapsed_seconds=%e' moon test -F '*Linux kernel boot via OpenSBI*'`
- Result: passed
- Wall time: 29.30 seconds
- Steps: 19,000,000
- Decode cache: 18,941,994 hits / 58,005 misses
- Translation cache: 16,991,713 hits / 1,677,284 misses

## Browser Linux Boot

- Command: `/usr/bin/time -f 'elapsed_seconds=%e' python3 outputs/webwright_browser_linux_boot/final_runs/run_1/final_script.py`
- Result: passed
- Wall time after cache slice: 349.33 seconds
- Previous plain-Wasm proof before cache slice: 609.38 seconds
- Browser executed steps reported in DOM: 737,148,928
- Browser decode cache: 624,005,546 hits / 113,116,343 misses
- Browser translation cache: 826,051,582 hits / 46,300,763 misses

## Browser Smoke

- Command: `python3 outputs/webwright_wasm_smoke/final_runs/run_1/final_script.py`
- Result: passed
- DOM cache observation: 4,317 decode hits / 35 decode misses; no Sv39 translation activity on the smoke guest
