# Results — every capture

Test system: Ryzen 7 5800X3D + RX 6600 8 GB @ 2560×1440. Full spec in [HARDWARE.md](HARDWARE.md).

All captures: 60 s, fixed position, slow 360° pan, Frame Limiter `Unlimited`, VSync `off` (except A4).
Raw CSVs in [`data/`](data/).

---

## Scenario A — quiet open world (GPU-bound regime)

| Capture | Settings changed | Avg FPS | 1% low | 0.1% low | CPU busy | GPU busy | Verdict |
|---|---|---|---|---|---|---|---|
| **A** | *baseline* | 119.0 | 82.7 | 52.1 | 5.79 ms (69%) | **8.05 ms (96%)** | **GPU-BOUND** |
| **A2** | + Shaders→Med, Env→Med, CMQ→Med, DepthBlur off | **136.0** | 80.2 | 57.9 | 6.46 ms (88%) | **6.54 ms (89%)** | balanced |
| **A3** | + CML→Lowest | 127.1 | 75.7 | 60.8 | 7.37 ms (94%) | 6.77 ms (86%) | CPU-BOUND ⚠️ |
| **A3b** | *control:* CML back to Low | 127.4 | 76.5 | 63.4 | 7.39 ms (94%) | 6.67 ms (85%) | CPU-BOUND |
| **A4** | *final:* CML Lowest, 144 cap, VSync ON | 123.5 | 76.8 | 61.6 | 7.52 ms (93%) | 7.05 ms (87%) | CPU-BOUND |

### A → A2: the GPU diet worked

GPU busy **8.05 → 6.54 ms (−19%)**, average FPS **+14%**.

More importantly: CPU busy (6.46 ms) and GPU busy (6.54 ms) **converged**. The machine went from lopsided to balanced. Further GPU cuts would have gained nothing — the CPU was already the next wall at ~155 FPS. **This is where to stop cutting.**

### A3 vs A3b: the control that produced the main finding

A3 appeared to show Character Model Limit `Lowest` making things *worse* (136 → 127 FPS, CPU busy **up** 14%). That is physically impossible — the setting strictly reduces character models submitted.

The control (A3b) reverted only that setting: **127.4 FPS, CPU busy 7.39 ms.** Identical to A3.

So `Low` vs `Lowest` is **neutral in open world** (nothing to clamp), and the 136 → 127 drop was **the map filling with players** between A2 and A3.

That drift is the finding: **the same spot, same settings, flipped from GPU-BOUND (89%) to CPU-BOUND (94%) purely because other players showed up.**

### A4: frame pacing

| | A3b (uncapped, VSync off) | A4 (144 cap, VSync on) | Δ |
|---|---|---|---|
| Average FPS | 127.4 | 123.5 | −3.1% |
| Frametime stddev | 1.90 ms | **1.64 ms** | **−13.7%** |
| Consistency (CV) | 24.3% | **20.3%** | **−16.5%** |
| p50 / p95 / p99 frametime | 7.26 / 11.37 / 13.07 ms | 7.52 / 11.27 / 13.02 ms | — |
| PresentMode | `Hardware: Independent Flip` | `Hardware Composed: Independent Flip` | both VRR-capable |

3% of average FPS bought 16% tighter frametimes.

---

## Scenario B — Lion's Arch, busy plaza (CPU-bound regime)

| Capture | Settings changed | Avg FPS | 1% low | 0.1% low | CPU busy | GPU busy | Stutter |
|---|---|---|---|---|---|---|---|
| **B1** | *baseline* | 48.3 | 27.6 | 14.7 | **20.19 ms (98%)** | 16.91 ms (82%) | 22 |
| **B2** | + LOD Ultra→Medium | 49.1 | 33.7 | 17.4 | **20.00 ms (98%)** | 16.52 ms (81%) | 9 |
| **B3** | + CMQ Highest→Medium | 52.1 | 35.5 | 21.8 | **18.84 ms (98%)** | 15.84 ms (83%) | 8 |
| **B4** | + CML Low→Lowest | **62.0** | **42.7** | **34.1** | **15.84 ms (98%)** | 14.51 ms (90%) | 1 |
| **B5** | *control:* revert all to B1 | 50.2 | 32.8 | 27.1 | **19.63 ms (98%)** | 16.68 ms (84%) | 2 |

**Every single capture is CPU-bound at 98%.** Even fully tuned. Even on a 5800X3D — the best consumer CPU available for this game. This is the engine wall, and it cannot be tuned away, only backed away from.

### Drift-corrected gains

Baseline = mean(B1, B5) to correct for population drift and shader-cache warmup:

| | baseline (mean B1/B5) | tuned (B4) | real gain |
|---|---|---|---|
| Average FPS | 49.3 | **62.0** | **+26%** ✅ |
| CPU busy | 19.91 ms | **15.84 ms** | **−20%** ✅ |
| 1% low | 30.2 | **42.7** | **+41%** ✅ |
| 0.1% low | 20.9 | **34.1** | +63% ⚠️ noisy |

### Per-setting CPU cost (the useful table)

| Setting change | Δ CPU busy | Δ GPU busy | Notes |
|---|---|---|---|
| **Character Model Limit** `Low → Lowest` | **−3.00 ms** | −1.33 ms | **The lever.** More than everything else combined. |
| **Character Model Quality** `Highest → Medium` | **−1.16 ms** | −0.68 ms | Real, and pays in *both* regimes. |
| **LOD Distance** `Ultra → Medium` | −0.19 ms | −0.39 ms | ~1%. Effectively noise. Widely overrated by guides. |

### The control caught an inflated claim

B1 vs B5 — **same settings**, 15 minutes apart:

| | B1 | B5 | drift |
|---|---|---|---|
| Average FPS | 48.3 | 50.2 | +3.9% |
| CPU busy | 20.19 ms | 19.63 ms | −2.8% |
| **0.1% low** | **14.7** | **27.1** | **+84%** ← |
| **Stutter frames** | **22** | **2** | **−91%** ← |

Average FPS was stable (~4% drift), so the **+26% tuning gain is real**.

But the **0.1% low drifted +84%** with no settings changed. That's the **shader cache warming**, not tuning. Our initial "+132% 0.1% low" headline was mostly cold-cache artifact. Corrected above.

**Lesson: your first capture in any GW2 zone will lie to you.** Warm up first.

---

## Summary

1. **GW2 is CPU-bound whenever other players are present** — even in ordinary open world, even on the best CPU for the game.
2. **Character Model Limit is the lever.** `Lowest` costs nothing when the map is quiet and is worth −3 ms of CPU when it isn't. One profile, all content.
3. **Character Model Quality is the sleeper.** It cuts CPU *and* GPU. Almost every guide focuses on Limit and ignores Quality.
4. **LOD Distance barely matters.** Contradicts several popular guides.
5. **Know where to stop.** Once CPU busy ≈ GPU busy, further GPU cuts buy nothing.
6. **Cap below refresh and leave VSync on.** 3% of FPS for 16% smoother frametimes.
7. **Run controls.** Ours changed the conclusion twice.
