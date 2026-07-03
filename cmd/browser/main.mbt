///|
let browser_runtime : Ref[BrowserRuntime] = { val: BrowserRuntime::new_smoke() }

///|
pub fn browser_init() -> Unit {
  browser_runtime.val = BrowserRuntime::new_smoke()
}

///|
pub fn browser_step() -> Unit {
  browser_runtime.val.step_when_paused()
}

///|
pub fn browser_run_tick() -> Unit {
  browser_runtime.val.run_tick()
}

///|
pub fn browser_run_for(step_budget : Int) -> Unit {
  browser_runtime.val.run_for(step_budget)
}

///|
pub fn browser_toggle_run() -> Unit {
  browser_runtime.val.toggle_run()
}

///|
pub fn browser_reset() -> Unit {
  browser_init()
}

///|
pub fn browser_send_input(text : String) -> Unit {
  browser_runtime.val.send_input(text)
}

///|
pub fn browser_send_input_byte(value : Int) -> Unit {
  browser_runtime.val.send_input_byte(value)
}

///|
pub fn browser_flush_input() -> Unit {
  browser_runtime.val.flush_input_when_paused()
}

///|
pub fn browser_begin_artifact(kind : Int) -> Unit {
  browser_runtime.val.begin_artifact(kind)
}

///|
pub fn browser_push_artifact_byte(value : Int) -> Unit {
  browser_runtime.val.push_artifact_byte(value)
}

///|
pub fn browser_push_artifact_words4(
  word0 : Int,
  word1 : Int,
  word2 : Int,
  word3 : Int,
  count : Int,
) -> Unit {
  browser_runtime.val.push_artifact_words4(word0, word1, word2, word3, count)
}

///|
pub fn browser_finish_artifact() -> Bool {
  browser_runtime.val.finish_artifact()
}

///|
pub fn browser_artifact_loaded_mask() -> Int {
  browser_runtime.val.artifact_loaded_mask()
}

///|
pub fn browser_artifact_size(kind : Int) -> Int {
  browser_runtime.val.artifact_size(kind)
}

///|
pub fn browser_guest_kind() -> Int {
  browser_runtime.val.guest()
}

///|
pub fn browser_total_steps() -> UInt64 {
  browser_runtime.val.steps()
}

///|
pub fn browser_decode_cache_hits() -> UInt64 {
  browser_runtime.val.decode_cache_hits()
}

///|
pub fn browser_decode_cache_misses() -> UInt64 {
  browser_runtime.val.decode_cache_misses()
}

///|
pub fn browser_translate_cache_hits() -> UInt64 {
  browser_runtime.val.translate_cache_hits()
}

///|
pub fn browser_translate_cache_misses() -> UInt64 {
  browser_runtime.val.translate_cache_misses()
}

///|
pub fn browser_console_length() -> Int {
  browser_runtime.val.console_length()
}

///|
pub fn browser_console_code_at(index : Int) -> Int {
  browser_runtime.val.console_code_at(index)
}

///|
pub fn browser_pc() -> UInt64 {
  browser_runtime.val.pc()
}

///|
pub fn browser_privilege() -> Int {
  browser_runtime.val.privilege()
}

///|
pub fn browser_reg(index : Int) -> UInt64 {
  browser_runtime.val.reg(index)
}

///|
pub fn browser_is_running() -> Bool {
  browser_runtime.val.is_running()
}
