# Results — every capture

Test system: Ryzen 7 5800X3D + RX 6600 8 GB @ 2560×1440. Full spec in [HARDWARE.md](HARDWARE.md).
Raw CSVs in [`data/`](data/). 60 s each.

**Read the GPU column, not the FPS column, when evaluating a GPU setting.** Because the machine is CPU-bound, map population moves FPS more than the setting under test does. `GPUBusy` is the clean signal.

---

## ⭐ The T-series — isolated per-setting GPU costs

**The cleanest data in this repo.** Stationary, slow camera pan, one setting changed at a time, uncapped, VSync off, same spot, back-to-back.

| Capture | Setting changed | FPS | CPU busy | GPU busy | **Δ GPU** | Verdict |
|---|---|---|---|---|---|---|
| **T1** | *baseline* | 117.0 | 8.33 ms | 6.43 ms | — | CPU-bound (97%) |
| **T2** | Shadows `Med → High` | 125.2 | 7.73 ms | 6.53 ms | **+0.10 ms** | CPU-bound (97%) |
| **T3** | + Reflections `None → Terrain & Sky` | 122.1 | 7.89 ms | 7.02 ms | **+0.50 ms** | CPU-bound (96%) |
| **T4** | + Shaders `Med → High` | 108.7 | 8.04 ms | 8.18 ms | **+1.15 ms** | **GPU-BOUND (89%)** ← |

### The headline

**Shaders is GW2's most expensive GPU setting — more than Shadows and Reflections combined.**

Every guide on the internet names Shadows and Reflections as the hogs and barely mentions Shaders. Measured on a modern GPU, one setting at a time:

```
  Shaders     Med -> High   +1.15 ms   ####################
  Reflections None-> T&S    +0.50 ms   #########
  LOD         Med -> Ultra  +0.39 ms   #######
  Environment Med -> High   ~+0.2 ms   ####
  Shadows     Med -> High   +0.10 ms   ##
```

Note the FPS column is *useless* here — T2 shows FPS **rising** when we made a setting more expensive, because CPU busy happened to drop 0.60 ms (map got quieter) and the machine is CPU-bound. Anyone benchmarking GW2 by watching an FPS counter will draw the wrong conclusion.

### Where to stop

At T3, GPU busy (7.02 ms) is still below CPU busy (7.89 ms) → CPU-bound → the visual upgrades are **free**.
At T4, GPU busy (8.18 ms) overshoots CPU busy (8.04 ms) → GPU-bound → **you now pay for every frame.**

> **Tuning rule: raise GPU settings until GPU busy approaches CPU busy. Stop there.**

---

## Scenario B — Lion's Arch, busy plaza (CPU-bound)

| Capture | Setting changed | FPS | 1% low | 0.1% low | CPU busy | GPU busy |
|---|---|---|---|---|---|---|
| **B1** | *baseline* | 48.3 | 27.6 | 14.7 | **20.19 ms (98%)** | 16.91 ms |
| **B2** | + LOD `Ultra → Medium` | 49.1 | 33.7 | 17.4 | **20.00 ms (98%)** | 16.52 ms |
| **B3** | + CharModelQuality `Highest → Medium` | 52.1 | 35.5 | 21.8 | **18.84 ms (98%)** | 15.84 ms |
| **B4** | + CharModelLimit `Low → Lowest` | **62.0** | **42.7** | **34.1** | **15.84 ms (98%)** | 14.51 ms |
| **B5** | *control: revert all to B1* | 50.2 | 32.8 | 27.1 | **19.63 ms (98%)** | 16.68 ms |

**Every capture is CPU-bound at 98%.** Even fully tuned. Even on a 5800X3D — the best consumer CPU available for this game. This is the engine wall.

### Isolated CPU costs

| Setting change | Δ CPU busy | Δ GPU busy |
|---|---|---|
| **Character Model Limit** `Low → Lowest` | **−3.00 ms** | −1.33 ms |
| **Character Model Quality** `Highest → Medium` | **−1.16 ms** | −0.68 ms |
| **LOD Distance** `Ultra → Medium` | −0.19 ms | −0.39 ms |

### Drift-corrected gains (baseline = mean of B1, B5)

| | baseline | tuned (B4) | real gain |
|---|---|---|---|
| Average FPS | 49.3 | **62.0** | **+26%** ✅ |
| CPU busy | 19.91 ms | **15.84 ms** | **−20%** ✅ |
| 1% low | 30.2 | **42.7** | **+41%** ✅ |
| 0.1% low | 20.9 | 34.1 | +63% ⚠️ noisy |

### The control that caught an inflated claim

B1 vs B5 — **same settings**, 15 minutes apart:

| | B1 | B5 | drift |
|---|---|---|---|
| Average FPS | 48.3 | 50.2 | +3.9% |
| CPU busy | 20.19 ms | 19.63 ms | −2.8% |
| **0.1% low** | **14.7** | **27.1** | **+84%** ← |
| **Stutter frames** | **22** | **2** | **−91%** ← |

Average FPS was stable, so the **+26% tuning gain is real.** But the 0.1% low drifted **+84% with no settings changed** — that is the **shader cache warming**, not tuning. Our first headline ("0.1% low +132%") was mostly cold-cache artifact.

**Your first capture in any GW2 zone will lie to you.**

---

## Scenario A — open world (the regime-flip discovery)

| Capture | Settings | FPS | CPU busy | GPU busy | Verdict |
|---|---|---|---|---|---|
| **A** | baseline | 119.0 | 5.79 ms (69%) | **8.05 ms (96%)** | **GPU-BOUND** |
| **A2** | + GPU diet (bundle) | **136.0** | 6.46 ms (88%) | 6.54 ms (89%) | balanced |
| **A3** | + CML `Lowest` | 127.1 | 7.37 ms (94%) | 6.77 ms | CPU-BOUND ⚠️ |
| **A3b** | *control:* CML back to `Low` | 127.4 | 7.39 ms (94%) | 6.67 ms | CPU-BOUND |
| **A4** | 144 cap + VSync on | 123.5 | 7.52 ms (93%) | 7.05 ms | CPU-BOUND |
| **A5** | + SAM/ReBAR enabled | 126.1 | 7.58 ms (96%) | **6.70 ms** | CPU-BOUND |

### A3 vs A3b — the control that produced the repo's main finding

A3 appeared to show Character Model Limit `Lowest` making things **worse** (136 → 127 FPS, CPU busy **up** 14%). Physically impossible — the setting strictly *reduces* character models submitted.

The control (A3b) reverted only that setting: **127.4 FPS, CPU busy 7.39 ms.** Identical to A3.

So `Low` vs `Lowest` is **neutral in open world** (nothing to clamp), and the 136 → 127 drop was **the map filling with players** between A2 and A3.

**That drift is the finding:** the same spot, same settings, flipped from `GPU-BOUND (89%)` to `CPU-BOUND (94%)` purely because players arrived.

### Resizable BAR / SAM (A4 → A5)

| | SAM off | SAM on | Δ |
|---|---|---|---|
| GPU busy | 7.05 ms | **6.70 ms** | **−5.0%** |
| CPU busy | 7.52 ms | 7.58 ms | +0.8% |
| Average FPS | 123.5 | 126.1 | **+2.1%** |

Textbook SAM signature: GPU side improves, CPU side untouched. **And it bought 2% FPS, because the GPU wasn't the bottleneck.**

**GPU-side hardware improvements barely move GW2.** A much faster GPU would mostly produce idle GPU time.

---

## ⚠️ A6–A8 — corrupted by movement. Do not cite.

These captures were taken while **walking the character around** instead of standing still. Preserved for transparency; **the numbers are not usable.**

| Capture | FPS | CPU busy | GPU busy | stddev | Stutter |
|---|---|---|---|---|---|
| A6 (visuals restored) | 95.7 | 7.94 ms | 9.57 ms | 3.02 ms | 52 |
| A7 (−AO, −SSS) | 93.2 | **9.97 ms** | 9.09 ms | 3.64 ms | 67 |
| A8 (reverted to lean) | 104.8 | 9.10 ms | 7.07 ms | **3.85 ms** | **93** |

**The tell:** A7 turned *off* two GPU settings, yet CPU busy **rose 26%**. Impossible from a GPU-side change.

Movement triggers **asset streaming** — entity load/unload plus shader compilation on newly-seen assets. Compare the same config stationary vs moving:

| | A8 (moving) | T1 (stationary) |
|---|---|---|
| Frametime stddev | **3.85 ms** | **2.12 ms** (−45%) |
| Stutter frames | **93 (1.5%)** | **23 (0.3%)** (−75%) |

We initially blamed that frametime chaos on map population. It was the walking.

**These runs also produced a wrong conclusion we later reversed.** A6 measured the High-settings bundle at **+2.87 ms GPU**, which led us to declare High-tier settings unaffordable and revert everything to a lean config. The clean stationary T-series showed the real cost of Shadows + Reflections + Environment + LOD is **~1.0 ms** — comfortably affordable. **A6 inflated the GPU cost because streaming work was being counted as setting cost.**

---

## Summary

1. **GW2 is CPU-bound whenever other players are present** — even in ordinary open world, even on the best CPU for the game.
2. **Character Model Limit is the lever** (−3.0 ms CPU). `Lowest` costs nothing when the map is quiet. One profile, all content.
3. **Character Model Quality is the sleeper** (−1.16 ms CPU **and** −0.68 ms GPU). Guides fixate on Limit and ignore Quality.
4. **Shaders is the most expensive GPU setting** (+1.15 ms) — not Shadows (+0.10 ms) or Reflections (+0.50 ms). This inverts the consensus.
5. **LOD Distance is nearly free** and barely affects performance either way. Guides disagree wildly about it; it just doesn't matter much.
6. **Know where to stop.** Raise GPU settings until GPU busy ≈ CPU busy, then stop.
7. **SAM/ReBAR works** (−5% GPU busy) **and barely helps** (+2% FPS), because the GPU isn't the wall.
8. **Cap below refresh, leave VSync on.** 3% of FPS for 16% smoother frametimes.
9. **Stand still while benchmarking.** Movement corrupted 4 of our captures and produced a conclusion we had to reverse.
10. **Run controls.** Ours changed the conclusion three times.
