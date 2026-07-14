# gw2-bottleneck-lab

**Measured CPU-vs-GPU bottleneck data for Guild Wars 2 — with controls, and with the mistakes left in.**

Almost every Guild Wars 2 performance guide traces back to one of two things: a single 2019-era benchmark (Ryzen 9 3950X + GTX 1080, 1080p, standing still), or anecdote. Nobody publishes per-frame CPU/GPU-busy data. Nobody runs control captures. So the advice is stale, contradictory, and — critically — **written for a bottleneck you might not have.**

This repo is raw [PresentMon](https://github.com/GameTechDev/PresentMon) captures, the scripts to reproduce them, and findings that are honest about what the data does and doesn't support. Several conclusions here **overturned** what we believed halfway through. Those reversals are documented, not buried.

---

## Two findings that contradict the consensus

### 1. GW2 is CPU-bound the moment other players exist

Not "sometimes CPU-bound." On the test system the game was GPU-bound **only in genuinely empty scenes**. As soon as the map populated — ordinary open world, no meta event — it flipped to CPU-bound on its own, **with no settings changed.**

We found this by accident. A control run at the same spot, 3 minutes later, identical settings, showed CPU busy rising 6.46 → 7.39 ms and the verdict flipping from `GPU-BOUND` to `CPU-BOUND`. Players had simply arrived.

Across one session, CPU busy drifted **7.58 → 9.97 ms** purely from map population — costing ~17% FPS with zero config changes.

> **In GW2, the number of players around you moves your framerate more than any graphics setting.**

Which is why **Character Model Limit** is the whole ballgame, and why guides that optimize the GPU axis are optimizing the wrong one.

### 2. Shaders is GW2's most expensive GPU setting — not Shadows, not Reflections

Every guide names Shadows and Reflections as the GPU hogs. Measured cleanly, one setting at a time, on a modern GPU:

| Setting | GPU cost/frame | Community says | Reality |
|---|---|---|---|
| **Shaders** Med→High | **+1.15 ms** | rarely mentioned | **the most expensive setting by far** |
| **Reflections** None→Terrain&Sky | +0.50 ms | "the worst offender" | affordable |
| **LOD Distance** Med→Ultra | +0.39 ms | "critical" / "minimal" (guides disagree) | cheap |
| **Environment** Med→High | ~+0.2 ms | — | ~free |
| **Shadows** Med→High | **+0.10 ms** | "the biggest GPU cost" | **essentially free** |

The "shadows are expensive" claim is about **Ultra**, which is a known cliff. **Medium→High is 1.6% of GPU time.**

---

## Results

Test system: **Ryzen 7 5800X3D + Radeon RX 6600 (8 GB) @ 2560×1440**, Windows 11 25H2, Adrenalin 26.6.2. See [HARDWARE.md](HARDWARE.md).

Deliberately lopsided: arguably the best consumer CPU for GW2 (96 MB V-Cache) driving a 1080p-class GPU at 1440p. That makes it a useful probe — it can hit *either* wall depending on content.

### Crowded scene (Lion's Arch) — CPU-bound at 98%

| | baseline | tuned | gain |
|---|---|---|---|
| Average FPS | 49.3 | **62.0** | **+26%** |
| CPU busy | 19.9 ms | **15.8 ms** | **−20%** |
| 1% low | 30.2 | **42.7** | **+41%** |

Baseline = mean of two captures (before *and* after the tuning runs) to correct for population drift.

**Every capture was CPU-bound at 98% — even fully tuned, even on a 5800X3D.** That is the engine wall. It cannot be tuned away, only backed away from.

### CPU-side costs (isolated, in a crowded scene)

| Setting | Δ CPU busy | Verdict |
|---|---|---|
| **Character Model Limit** `Low → Lowest` | **−3.00 ms** | **The lever.** More than everything else combined. |
| **Character Model Quality** `Highest → Medium` | **−1.16 ms** (and −0.68 ms GPU) | Real. Pays in both regimes. Underrated. |
| **LOD Distance** `Ultra → Medium` | −0.19 ms | ~1%. Noise. **Don't bother.** |

**Character Model Limit `Lowest` is free in open world** (control-verified — there aren't enough characters present to clamp) and worth −3.0 ms the instant there are. So it belongs in **one profile, for all content.**

### Resizable BAR / Smart Access Memory

| | SAM off | SAM on | Δ |
|---|---|---|---|
| GPU busy | 7.05 ms | **6.70 ms** | **−5.0%** |
| CPU busy | 7.52 ms | 7.58 ms | +0.8% |
| Average FPS | 123.5 | 126.1 | **+2.1%** |

SAM does exactly what it should — 5% off the GPU side, CPU untouched. **And it buys 2% FPS, because the GPU wasn't the bottleneck.**

That's the clearest statement of GW2's nature in this repo: **GPU-side hardware improvements barely move this game.** A much faster GPU would mostly give you idle GPU time.

### Frame pacing

| | uncapped, VSync off | 144 cap + VSync on |
|---|---|---|
| Average FPS | 127.4 | 123.5 (−3%) |
| Frametime stddev | 1.90 ms | **1.64 ms** |
| Consistency (CV) | 24.3% | **20.3% (−16%)** |

3% of average FPS bought 16% tighter frametimes. On a VRR display that is the correct trade — see [METHODOLOGY.md](METHODOLOGY.md#vrr).

---

## The resulting config

One profile, all content. 2560×1440, 165 Hz FreeSync, RX 6600.

```
Character Model Limit ... Lowest         <- the lever (-3.0 ms CPU)
Character Model Quality . Medium         <- -1.16 ms CPU, -0.68 ms GPU
Shadows ................. High           <- free (+0.10 ms)
Reflections ............. Terrain & Sky  <- affordable (+0.50 ms)
Environment ............. High           <- free
LOD Distance ............ Ultra          <- affordable (+0.39 ms)
Shaders ................. Medium         <- the one you cannot afford (+1.15 ms)
Textures ................ High
Render Sampling ......... Native
Anti-Aliasing ........... SMAA High
Screen Space Shadows .... Off
Postprocessing .......... Custom (Motion Blur off, Bloom low)
Effect LOD .............. On
Frame Limiter ........... 144            <- never Unlimited (engine runs to 250, exits VRR range)
Vertical Sync ........... On             <- tear backstop; costs ~1 ms, uncapped VRR costs ~21 ms
Screen Mode ............. Windowed Fullscreen
```

**The method, not the values, is what generalizes.** Scale the GPU-side settings to your own GPU by measuring where *your* GPU busy meets *your* CPU busy. The **CPU-side** conclusions should hold on any rig — GW2's game thread is the wall regardless of silicon.

**Tuning rule:** raise GPU settings until `GPU busy` approaches `CPU busy`. Stop there. Past that point you're just trading frames for nothing.

---

## Widely repeated, and wrong

Checked against primary sources (ArenaNet dev blogs, GW2 wiki, AMD docs) — not against other guides.

| Claim | Reality |
|---|---|
| "Shadows/Reflections are GW2's biggest GPU cost" | **Shaders is**, by 2×. Shadows Med→High is +0.10 ms. |
| "Add `-dx11` to launch options" | **Deprecated 2023-07-18.** DX11 is the only renderer. The flag does nothing. |
| "Use exclusive Fullscreen for more FPS" | **GW2's DX11 client has no exclusive fullscreen.** ArenaNet has no plans to add it. The dropdown runs borderless anyway. |
| "Disable Fullscreen Optimizations" | Backwards — it can knock GW2 off the flip-model path and **cost you VRR**. |
| "Set Tessellation override to x2" | GW2 uses **zero tessellation.** Its backend is BGFX, which has no tessellation stages ([bgfx#332](https://github.com/bkaradzic/bgfx/issues/332), open since 2015). |
| "Pin GW2 to specific CPU cores" | Actively harmful. GW2 spawns worker threads scaled to core count; pinning removes them. |
| "`-fps 144` caps your framerate" | Documented bug — **loading screens only.** |
| "Enable Radeon Boost / Anti-Lag 2" | **Neither supports GW2.** Not on AMD's whitelist for either. |
| "Turn VSync off with FreeSync" | Wrong when capped below refresh. VSync ON costs ~1–2 ms; running past the VRR ceiling costs **~21 ms**. |
| "Clear your shader cache to fix stutter" | Makes it worse. GW2 has real shader-compile stutter; the cache is the fix. |

---

## Reproduce on your own hardware

```powershell
# 1. PresentMon (Intel, signed, passive ETW consumer - no anti-cheat concern)
#    https://github.com/GameTechDev/PresentMon/releases

# 2. Capture 60s (needs admin for ETW)
.\tools\capture.ps1 -Label "myrig_baseline"

# 3. Analyze
.\tools\analyze.ps1 -Csv .\data\myrig_baseline.csv
```

`analyze.ps1` reports FPS, 1%/0.1% lows, frametime stddev, **CPU busy vs GPU busy** (your actual bottleneck), and **present mode** (whether VRR can engage at all).

**Protocol matters more than you think.** Read [METHODOLOGY.md](METHODOLOGY.md) first. In particular:

- **Stand still and pan the camera. Do not walk.** Movement triggers asset streaming, which inflates stutter and CPU busy. We ran four captures while moving and it corrupted every one of them (frametime stddev 3.85 ms moving vs 2.12 ms stationary — same config).
- **Warm up ~10 minutes first.** The first capture in any zone will lie to you — shader compilation crushes 0.1% lows. Ours reported an 84% improvement that was pure cold cache.
- **Run controls.** Re-capture your baseline *after* your tests. Ours changed the conclusion three separate times.
- **Uncap the framerate while measuring.** A frame cap makes both CPU and GPU look idle and every run reports "neither saturated."

PRs with results from other hardware very welcome — especially **non-X3D CPUs** and **stronger GPUs**, which would test whether "CPU-bound whenever players exist" is a property of the engine or an artifact of this rig.

---

## Contents

- [`RESULTS.md`](RESULTS.md) — every capture, full numbers, isolated per-setting costs
- [`METHODOLOGY.md`](METHODOLOGY.md) — protocol, controls, and the three times we were wrong
- [`HARDWARE.md`](HARDWARE.md) — test system + every OS/driver/BIOS setting that matters
- [`tools/`](tools/) — capture + analysis scripts
- [`data/`](data/) — 17 raw PresentMon CSVs

## Caveats

n=1 machine. Lion's Arch population is uncontrolled (corrected via before/after controls, imperfectly). Single 60 s capture per data point, no error bars — **treat deltas under ~5% as noise.** Full limitations in [METHODOLOGY.md](METHODOLOGY.md#known-limitations).

## License

MIT. Data and findings free to use; attribution appreciated.
