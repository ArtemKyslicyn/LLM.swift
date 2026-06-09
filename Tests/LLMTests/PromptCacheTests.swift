import Testing
import Foundation
@testable import LLM

/// Correctness of prompt-cache (prefix-KV reuse): a cached run must produce output
/// IDENTICAL to a clean from-scratch prefill of the same prompt. Greedy (topK=1)
/// → deterministic. Uses a local Qwen3-0.6B GGUF; skips if absent.
@Suite(.serialized)
struct PromptCacheTests {

    static let modelPath = NSHomeDirectory() + "/Documents/Qwen3-0.6B-Q4_K_M.gguf"
    // Two prompts sharing a long prefix, differing only at the end.
    static let p1 = "System: you are a terse assistant.\nUser: name one color.\nAssistant:"
    static let p2 = "System: you are a terse assistant.\nUser: name one animal.\nAssistant:"

    private func greedyBot() -> LLM? {
        LLM(from: URL(fileURLWithPath: Self.modelPath),
            seed: 1234, topK: 1, topP: 1.0, temp: 0.0, maxTokenCount: 256)
    }

    @Test("prompt-cache output == clean from-scratch prefill (greedy)")
    func cachedMatchesClean() async throws {
        guard FileManager.default.fileExists(atPath: Self.modelPath) else {
            print("⚠️ Qwen3-0.6B not at \(Self.modelPath) — skipping prompt-cache correctness test")
            return
        }
        // Ground truth: a FRESH bot per prompt = clean context (no reset race).
        guard let g1 = greedyBot(), let g2 = greedyBot() else { return }
        let truth1 = await g1.getCompletion(from: Self.p1)
        let truth2 = await g2.getCompletion(from: Self.p2)

        // Cached: one bot, prompt-cache ON, two sequential completions sharing a prefix.
        guard let c = greedyBot() else { return }
        await c.setPromptCacheEnabled(true)
        let cached1 = await c.getCompletion(from: Self.p1)   // empty cache → full prefill
        let cached2 = await c.getCompletion(from: Self.p2)   // reuses the shared prefix

        #expect(!truth1.isEmpty)
        #expect(cached1 == truth1, "cached p1 must equal clean p1")
        #expect(cached2 == truth2, "cached p2 (prefix-reused) must equal clean p2")
    }

    @Test("default path (cache off) is unchanged: fresh bots agree with a cache-off reuse start")
    func defaultPathUnaffected() async throws {
        guard FileManager.default.fileExists(atPath: Self.modelPath) else { return }
        guard let g = greedyBot(), let c = greedyBot() else { return }
        let truth1 = await g.getCompletion(from: Self.p1)
        // cache OFF (default): first completion on a fresh bot must equal ground truth.
        let out1 = await c.getCompletion(from: Self.p1)
        #expect(out1 == truth1)
    }
}
