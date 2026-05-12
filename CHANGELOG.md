# Changelog

All notable changes to the `ArtemKyslicyn/LLM.swift` fork (downstream of `haldihealth/LLM.swift`, itself a fork of `eastriverlee/LLM.swift`).

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely. Versioning is by **upstream llama.cpp build tag** (`b<N>`), not semver — the Swift API surface is intentionally stable across bumps.

---

## [b9113] — 2026-05-12

### Changed
- **llama.xcframework** updated to upstream `ggml-org/llama.cpp` release **b9113** (published 2026-05-11). Previous build was a much earlier checkpoint embedded in the prior xcframework drop.
  - Binary delta: each per-architecture `llama` library grew ~8.0 MB → ~9.5 MB.
  - Header delta: 248 net new lines across `llama.h`; 57 files touched across all platform slices (`ios-arm64`, `ios-arm64_x86_64-simulator`, `macos-arm64_x86_64`, `tvos-arm64`, `tvos-arm64_x86_64-simulator`, `xros-arm64`, `xros-arm64_x86_64-simulator`).
- **dSYM bundles + `DebugSymbolsPath`** stripped again. The release archive re-introduces both; the fork's policy is to remove them so the package remains checkout-clean on case-sensitive filesystems and validation-strict Xcode setups. Net xcframework size: ~620 MB → ~51 MB.

### Verified backward-compatible
The Swift API surface is **unchanged**. Every symbol used by `Sources/LLM/LLM.swift` (45 of them — `llama_init_from_model`, `llama_decode`, `llama_model_load_from_file`, `llama_get_logits_ith`, `llama_sampler_chain_init`, `llama_sampler_init_top_k`, `llama_sampler_init_top_p`, `llama_sampler_init_temp`, `llama_sampler_init_dist`, `llama_sampler_init_penalties`, `llama_tokenize`, `llama_token_to_piece`, `llama_vocab_*`, etc.) still exists with the same signature on b9113.

`swift build` is clean against the new xcframework. Downstream consumers do not need to change call sites.

### Available but not yet wrapped in Swift

The new llama.cpp surface added in b9113 contains the following functions that the Swift binding does **not** yet expose. Listed in priority order; contributions / use-case requests welcome. All are optional opt-in additions — wrapping them won't change existing behaviour.

**Sampler additions:**
- `llama_sampler_init_adaptive_p(float target, float decay, uint32_t seed)` — adaptive top-p sampler that self-tunes the probability cutoff. Could be added as an alternative to or in addition to the current top-k + top-p chain in `LLM.recreateSampler()`.
- `llama_set_sampler(struct llama_context *, llama_seq_id, struct llama_sampler *)` — per-sequence sampler binding for batched / parallel inference. Useful when running multiple completions in one context with different sampling configs.

**Sampled state introspection (per-batch-position accessors):**
- `llama_get_sampled_token_ith(ctx, i) -> llama_token`
- `llama_get_sampled_probs_ith(ctx, i) -> float *`
- `llama_get_sampled_probs_count_ith(ctx, i) -> uint32_t`
- `llama_get_sampled_logits_ith(ctx, i) -> float *`
- `llama_get_sampled_logits_count_ith(ctx, i) -> uint32_t`
- `llama_get_sampled_candidates_ith(ctx, i) -> llama_token *`
- `llama_get_sampled_candidates_count_ith(ctx, i) -> uint32_t`

  Together these let callers inspect what the sampler "saw" at any position in the batch — useful for confidence-aware UI, top-k visualisation, debug tooling. Niche but valuable for advanced consumers.

**LoRA adapters (consolidated API):**
- `llama_set_adapters_lora(...)` — replaces the deprecated `llama_set_adapter_lora` / `llama_rm_adapter_lora` / `llama_clear_adapter_lora` trio with a single multi-adapter setter. The fork does not currently bridge LoRA at all; adding it would let downstream apps serve fine-tuned variants of base models at runtime.

**Model loading variants:**
- `llama_model_init_from_user(...)` — initialise a model from in-memory data instead of a file path.
- `llama_model_load_from_file_ptr(...)` — load from a `FILE *` (lower-level file handle).

  Both are useful if a downstream wants to avoid file-system staging (e.g. streaming a model from network or decrypting on-the-fly). Current Swift binding uses path-based loading only.

**Other additions (debug / utility):**
- `llama_max_tensor_buft_overrides(void) -> size_t` — query the cap on buffer-type overrides.
- `llama_model_n_embd_out(model) -> int32_t` — output embedding dimension (distinct from input `n_embd`).
- `llama_log_get(callback_out, user_data_out)` — read the currently installed log callback (parallel to existing `llama_log_set`).
- `llama_set_adapter_cvec(...)` — renamed from `llama_apply_adapter_cvec`. Existing binding does not use it.

### Removed (upstream)
For reference — the following symbols disappeared upstream between the prior xcframework and b9113. **None** were used by this fork's Swift bindings, so the swap is a clean compile:
- `llama_set_adapter_lora` (replaced by `llama_set_adapters_lora` above)
- `llama_rm_adapter_lora` (replaced by `llama_set_adapters_lora`)
- `llama_clear_adapter_lora` (replaced by `llama_set_adapters_lora`)
- `llama_apply_adapter_cvec` (renamed to `llama_set_adapter_cvec`)
- `llama_memory_breakdown_print`

### Signature tweaks (non-breaking for us)
The following had minor signature changes; the fork's Swift bindings do not use any of them, so no patches needed:
- `llama_split_path`, `llama_split_prefix` — `int` → `int32_t` (return + offsets).
- `llama_sampler_init`, `llama_sampler_chain_get` — dropped `const` qualifier on `llama_sampler_i *` / `llama_sampler *` arguments (mutable interface now).

---

## [previous — unbumped] — pre-2026-05-12

Initial xcframework drop inherited from the upstream `haldihealth` fork, plus:
- `12d2315` — removed dSYM debug symbols from xcframework (broke git checkout on macOS due to deeply nested `Relocations/aarch64/` paths).
- `81a618d` — removed `DebugSymbolsPath` from `Info.plist` (Xcode flagged the absent paths as build errors after the strip above).

The strip pattern from these two commits is re-applied automatically on every llama.cpp bump going forward — see the maintenance workflow in [`README.md`](README.md).
