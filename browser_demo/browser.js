const hostNotes = document.getElementById("host-notes");
const consoleNode = document.getElementById("console");
const statusNode = document.getElementById("status");
const stepButton = document.getElementById("step");
const runToggleButton = document.getElementById("run-toggle");
const resetButton = document.getElementById("reset");
const loadSmokeButton = document.getElementById("load-smoke");
const loadLinuxButton = document.getElementById("load-linux");
const serialInput = document.getElementById("serial-input");
const sendInputButton = document.getElementById("send-input");
const artifactStatusNode = document.getElementById("artifact-status");

let runtime;
const textEncoder = new TextEncoder();

const schedulerPolicy = {
  intervalMs: 16,
  smokeStepsPerTick: 4096,
  linuxStepsPerTick: 262144,
  syncEveryTicks: 32,
  hotPcSamples: 0,
};

const hotPcSampler = {
  counts: new Map(),
  samples: 0,
};

const schedulerStats = {
  runTicks: 0,
  syncs: 0,
  markerSteps: new Map(),
  linuxInputSentStep: null,
  linuxInputExpectedStep: null,
};

const linuxBootMarkers = [
  ["OpenSBI", "OpenSBI v"],
  ["Linux version", "Linux version"],
  ["earlycon", "earlycon:"],
  ["kernel command line", "Kernel command line:"],
  ["ttyS0 console", "ttyS0"],
];

function makeWasmImports(module) {
  const stringConstants = {};
  for (const imported of WebAssembly.Module.imports(module)) {
    if (imported.module === "_" && imported.kind === "global") {
      stringConstants[imported.name] = imported.name;
    }
  }
  return {
    "_": stringConstants,
    "wasm:js-string": {
      length: (value) => value.length,
      charCodeAt: (value, index) => value.charCodeAt(index),
      equals: (left, right) => left === right,
      concat: (left, right) => left + right,
      fromCharCodeArray: () => "",
    },
  };
}

function setText(node, text) {
  if (node) {
    node.textContent = text;
  }
}

function positiveQueryInt(query, name) {
  const value = query.get(name);
  if (!value) {
    return null;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function applySchedulerQuery(query) {
  schedulerPolicy.linuxStepsPerTick =
    positiveQueryInt(query, "linuxStepsPerTick") ?? schedulerPolicy.linuxStepsPerTick;
  schedulerPolicy.syncEveryTicks =
    positiveQueryInt(query, "syncEveryTicks") ?? schedulerPolicy.syncEveryTicks;
  schedulerPolicy.hotPcSamples =
    positiveQueryInt(query, "hotPcSamples") ?? schedulerPolicy.hotPcSamples;
}

function resetHotPcSamples() {
  hotPcSampler.counts.clear();
  hotPcSampler.samples = 0;
}

function resetSchedulerStats() {
  schedulerStats.runTicks = 0;
  schedulerStats.syncs = 0;
  schedulerStats.markerSteps.clear();
  schedulerStats.linuxInputSentStep = null;
  schedulerStats.linuxInputExpectedStep = null;
}

function formatGuestHex(value) {
  if (typeof value === "bigint") {
    return `0x${BigInt.asUintN(64, value).toString(16)}`;
  }
  const numeric = Number(value);
  const normalized = numeric < 0 ? numeric >>> 0 : numeric;
  return `0x${normalized.toString(16)}`;
}

function sampleHotPc(wasm) {
  if (
    schedulerPolicy.hotPcSamples <= 0 ||
    hotPcSampler.samples >= schedulerPolicy.hotPcSamples ||
    wasm.browser_guest_kind() !== 1
  ) {
    return;
  }
  const pc = wasm.browser_pc();
  const key = formatGuestHex(pc);
  hotPcSampler.counts.set(key, (hotPcSampler.counts.get(key) ?? 0) + 1);
  hotPcSampler.samples += 1;
}

function hotPcText() {
  if (schedulerPolicy.hotPcSamples <= 0) {
    return [];
  }
  const top = Array.from(hotPcSampler.counts.entries())
    .sort((left, right) => right[1] - left[1])
    .slice(0, 8)
    .map(([pc, count]) => `${pc}:${count}`)
    .join(" ");
  return [`hot pc samples: ${hotPcSampler.samples}/${schedulerPolicy.hotPcSamples}`, `hot pc top: ${top}`];
}

function syncUi() {
  schedulerStats.syncs += 1;
  const consoleText = runtime.consoleText();
  setText(consoleNode, consoleText);
  setText(statusNode, runtime.statusText());
  setText(artifactStatusNode, runtime.artifactStatusText(consoleText));
  setText(runToggleButton, runtime.isRunning() ? "Pause" : "Run");
}

function readRuntimeText(wasm, prefix) {
  const length = wasm[`${prefix}_length`]();
  let text = "";
  for (let index = 0; index < length; index += 1) {
    text += String.fromCodePoint(wasm[`${prefix}_code_at`](index));
  }
  return text;
}

function makeBrowserRuntime(wasm) {
  const privilegeName = (value) => ({
    0: "User",
    1: "Supervisor",
    3: "Machine",
  })[value] ?? "Unknown";

  const statusText = () => {
    const mode = wasm.browser_is_running() ? "running" : "paused";
    const totalSteps = wasm.browser_total_steps();
    return [
      `mode: ${mode}`,
      `pc: ${formatGuestHex(wasm.browser_pc())}`,
      `privilege: ${privilegeName(wasm.browser_privilege())}`,
      `x1: ${formatGuestHex(wasm.browser_reg(1))}`,
      `x2: ${formatGuestHex(wasm.browser_reg(2))}`,
      `x3: ${formatGuestHex(wasm.browser_reg(3))}`,
      `x4: ${formatGuestHex(wasm.browser_reg(4))}`,
      `scheduler ticks: ${schedulerStats.runTicks}`,
      `ui syncs: ${schedulerStats.syncs}`,
      `executed: ${totalSteps} steps`,
      `linux input sent step: ${schedulerStats.linuxInputSentStep ?? "none"}`,
      `linux input expected step: ${schedulerStats.linuxInputExpectedStep ?? "none"}`,
      `decode cache: ${wasm.browser_decode_cache_hits()} hits / ${wasm.browser_decode_cache_misses()} misses`,
      `translate cache: ${wasm.browser_translate_cache_hits()} hits / ${wasm.browser_translate_cache_misses()} misses`,
      ...hotPcText(),
    ].join("\n");
  };

  return {
    init: () => wasm.browser_init(),
    step: () => wasm.browser_step(),
    runTick: () => wasm.browser_run_for(stepBudgetForGuest(wasm.browser_guest_kind())),
    toggleRun: () => wasm.browser_toggle_run(),
    reset: () => wasm.browser_reset(),
    sendInputByte: (value) => wasm.browser_send_input_byte(value),
    flushInput: () => wasm.browser_flush_input(),
    beginArtifact: (kind) => wasm.browser_begin_artifact(kind),
    pushArtifactByte: (value) => wasm.browser_push_artifact_byte(value),
    pushArtifactWords4: (word0, word1, word2, word3, count) => {
      wasm.browser_push_artifact_words4(word0, word1, word2, word3, count);
    },
    finishArtifact: () => wasm.browser_finish_artifact(),
    loadLinuxFromArtifacts: () => wasm.browser_load_linux_from_artifacts(),
    artifactMask: () => wasm.browser_artifact_loaded_mask(),
    artifactSize: (kind) => wasm.browser_artifact_size(kind),
    guestKind: () => wasm.browser_guest_kind(),
    totalSteps: () => wasm.browser_total_steps(),
    consoleText: () => readRuntimeText(wasm, "browser_console"),
    statusText,
    artifactStatusText: (consoleText) => artifactStatusText(wasm, consoleText),
    isRunning: () => wasm.browser_is_running(),
  };
}

function stepBudgetForGuest(guestKind) {
  return guestKind === 1 ?
    schedulerPolicy.linuxStepsPerTick :
    schedulerPolicy.smokeStepsPerTick;
}

function linuxBootProgressText(consoleText) {
  if (consoleText.includes("[trap]")) {
    return "boot: trap reported";
  }
  const reached = [];
  for (const [label, marker] of linuxBootMarkers) {
    if (consoleText.includes(marker)) {
      reached.push(label);
    }
  }
  return reached.length > 0 ?
    `boot: ${reached.join(" -> ")}` :
    "boot: waiting for firmware output";
}

function linuxBootMarkerStepText(wasm, consoleText) {
  for (const [label, marker] of linuxBootMarkers) {
    if (consoleText.includes(marker) && !schedulerStats.markerSteps.has(label)) {
      schedulerStats.markerSteps.set(label, wasm.browser_total_steps());
    }
  }
  if (schedulerStats.markerSteps.size === 0) {
    return "marker steps: none";
  }
  const reached = Array.from(schedulerStats.markerSteps.entries())
    .map(([label, steps]) => `${label}=${steps}`);
  return `marker steps: ${reached.join(" / ")}`;
}

function artifactStatusText(wasm, consoleText) {
  const mask = wasm.browser_artifact_loaded_mask();
  const guestKind = wasm.browser_guest_kind();
  const loaded = [
    mask & 1 ? `OpenSBI ${wasm.browser_artifact_size(1)} bytes` : "OpenSBI: missing",
    mask & 2 ? `DTB ${wasm.browser_artifact_size(2)} bytes` : "DTB: missing",
    mask & 4 ? `kernel ${wasm.browser_artifact_size(3)} bytes` : "kernel: missing",
    mask & 8 ? `initrd ${wasm.browser_artifact_size(4)} bytes` : "initrd: optional",
  ].join(" / ");
  const guest = guestKind === 1 ? "linux artifacts loaded" : "smoke guest";
  return [
    `guest: ${guest}`,
    `artifacts: ${loaded}`,
    `scheduler: ${stepBudgetForGuest(guestKind)} steps every ${schedulerPolicy.intervalMs}ms`,
    linuxBootProgressText(consoleText),
    linuxBootMarkerStepText(wasm, consoleText),
    `executed: ${wasm.browser_total_steps()} steps`,
  ].join("\n");
}

function submitInput() {
  const value = serialInput.value;
  serialInput.value = "";
  sendInputText(value);
  syncUi();
}

function sendInputText(text) {
  const bytes = textEncoder.encode(`${text}\r\n`);
  for (const byte of bytes) {
    runtime.sendInputByte(byte);
  }
  runtime.flushInput();
}

async function loadArtifact(kind, url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url}: HTTP ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  runtime.beginArtifact(kind);
  for (let offset = 0; offset < bytes.length; offset += 16) {
    const remaining = Math.min(16, bytes.length - offset);
    runtime.pushArtifactWords4(
      packWord(bytes, offset),
      packWord(bytes, offset + 4),
      packWord(bytes, offset + 8),
      packWord(bytes, offset + 12),
      remaining,
    );
  }
  return runtime.finishArtifact();
}

function packWord(bytes, offset) {
  return (
    (bytes[offset] ?? 0) |
    ((bytes[offset + 1] ?? 0) << 8) |
    ((bytes[offset + 2] ?? 0) << 16) |
    ((bytes[offset + 3] ?? 0) << 24)
  );
}

async function loadLinuxArtifacts(manifestUrl = "linux-artifacts/manifest.json") {
  resetHotPcSamples();
  resetSchedulerStats();
  setText(artifactStatusNode, "loading linux artifact manifest...");
  const manifestResponse = await fetch(manifestUrl);
  if (!manifestResponse.ok) {
    throw new Error(`${manifestUrl}: HTTP ${manifestResponse.status}`);
  }
  const manifest = await manifestResponse.json();
  await loadArtifact(1, new URL(manifest.opensbi, manifestResponse.url));
  syncUi();
  await loadArtifact(2, new URL(manifest.dtb, manifestResponse.url));
  syncUi();
  await loadArtifact(3, new URL(manifest.kernel, manifestResponse.url));
  syncUi();
  if (manifest.initrd) {
    await loadArtifact(4, new URL(manifest.initrd, manifestResponse.url));
    syncUi();
  }
  if (!runtime.loadLinuxFromArtifacts()) {
    throw new Error("linux artifacts are incomplete");
  }
  syncUi();
}

function startRunning() {
  if (!runtime.isRunning()) {
    runtime.toggleRun();
  }
  syncUi();
}

async function bootHost() {
  const query = new URLSearchParams(window.location.search);
  applySchedulerQuery(query);
  const module = await WebAssembly.compileStreaming(fetch("browser.wasm"));
  const instance = await WebAssembly.instantiate(module, makeWasmImports(module));
  runtime = makeBrowserRuntime(instance.exports);
  const linuxInputAfterMarker = query.get("linuxInputAfterMarker");
  const linuxInput = query.get("linuxInput");
  const linuxInputExpect = query.get("linuxInputExpect");
  let linuxInputSent = false;
  let ticksSinceSync = 0;

  runtime.init();
  setText(
    hostNotes,
    "Shared core Wasm host. Input is pushed into the emulated UART RX queue and echoed by the guest.",
  );

  stepButton.addEventListener("click", () => {
    if (!runtime.isRunning()) {
      runtime.step();
      syncUi();
    }
  });
  runToggleButton.addEventListener("click", () => {
    runtime.toggleRun();
    syncUi();
  });
  resetButton.addEventListener("click", () => {
    runtime.reset();
    resetHotPcSamples();
    resetSchedulerStats();
    syncUi();
  });
  loadSmokeButton.addEventListener("click", () => {
    runtime.reset();
    resetHotPcSamples();
    resetSchedulerStats();
    syncUi();
  });
  loadLinuxButton.addEventListener("click", () => {
    loadLinuxArtifacts().then(() => {
      if (new URLSearchParams(window.location.search).get("autoRun") === "1") {
        startRunning();
      }
    }).catch((error) => {
      console.error(error);
      setText(artifactStatusNode, `linux artifact load failed: ${error.message}`);
    });
  });
  sendInputButton.addEventListener("click", submitInput);
  serialInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      submitInput();
    }
  });
  setInterval(() => {
    if (runtime.isRunning()) {
      runtime.runTick();
      schedulerStats.runTicks += 1;
      sampleHotPc(instance.exports);
      ticksSinceSync += 1;
      const shouldSync = ticksSinceSync >= schedulerPolicy.syncEveryTicks;
      if (shouldSync) {
        ticksSinceSync = 0;
        syncUi();
        if (
          !linuxInputSent &&
          linuxInputAfterMarker &&
          linuxInput &&
          runtime.consoleText().includes(linuxInputAfterMarker)
        ) {
          linuxInputSent = true;
          schedulerStats.linuxInputSentStep = runtime.totalSteps();
          sendInputText(linuxInput);
          syncUi();
        }
        if (
          schedulerStats.linuxInputExpectedStep === null &&
          linuxInputExpect &&
          runtime.consoleText().includes(linuxInputExpect)
        ) {
          schedulerStats.linuxInputExpectedStep = runtime.totalSteps();
          syncUi();
        }
      }
    }
  }, schedulerPolicy.intervalMs);
  syncUi();
  const smokeInput = query.get("smokeInput");
  if (smokeInput) {
    sendInputText(smokeInput);
    syncUi();
  }
  if (query.get("guest") === "linux") {
    loadLinuxArtifacts().then(() => {
      if (query.get("autoRun") === "1") {
        startRunning();
      }
    }).catch((error) => {
      console.error(error);
      setText(artifactStatusNode, `linux artifact load failed: ${error.message}`);
    });
  }
  serialInput.focus();
}

bootHost().catch((error) => {
  console.error(error);
  setText(hostNotes, `Failed to start Wasm host: ${error}`);
});
