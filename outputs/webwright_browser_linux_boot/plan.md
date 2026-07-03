# Critical Points

- [x] CP1: The browser demo artifact directory contains real OpenSBI, generated DTB, and a non-trivial Linux kernel artifact.
- [x] CP2: The browser demo loads the real Linux artifact guest through the manifest without overwriting artifacts.
- [x] CP3: The Wasm runtime auto-runs the loaded guest and serial output reaches the OpenSBI banner.
- [x] CP4: The Wasm runtime continues far enough for early Linux serial output, ideally including `Linux version`.
- [x] CP5: The status panel reports the Linux artifact guest, explicit scheduler policy, and non-zero executed steps.
