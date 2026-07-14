# gw2-bottleneck-lab

**Measured CPU-vs-GPU bottleneck data for Guild Wars 2 — with controls.**

Almost every Guild Wars 2 performance guide on the internet traces back to one of two things: a single 2019-era benchmark (Ryzen 9 3950X + GTX 1080, 1080p, standing still), or pure anecdote. Nobody publishes per-frame CPU/GPU-busy data. Nobody runs control captures. So the advice is stale, contradictory, and — critically — **written for a bottleneck you might not have.**

This repo is an attempt to fix that: raw [PresentMon](https://github.com/GameTechDev/PresentMon) captures, the scripts to reproduce them, and findings that are honest about what the data does and does not support.

---

## The headline finding

> **Guild Wars 2 becomes CPU-bound the moment other players exist.**

Not "sometimes CPU-bound, sometimes GPU-bound." On the test system, the game was GPU-bound **only in genuinely empty scenes**. As soon as the map populated — even in ordinary open world, with no meta event running — it flipped to CPU-bound on its own, with no settings changed.

We caught this by accident. A control run in the open world, taken 3 minutes after the previous capture with **identical settings**, showed CPU busy rising from 6.46 ms to 7.39 ms and the verdict flipping from `GPU-BOUND` to `CPU-BOUND`. Players had simply shown up.

This has a direct consequence:

**The single most valuable setting is `Character Model Limit`, and it should be at `Lowest` — always, in one profile, for all content.** It costs nothing when the map is quiet (there are no models to clamp), and it is by far the biggest lever the instant it isn't.

---

## Results

Test system: **Ryzen 7 5800X3D + Radeon RX 6600 (8 GB) @ 2560×1440**, Windows 11 25H2, Adrenalin 26.6.2. See [HARDWARE.md](HARDWARE.md).

This is a deliberately lopsided rig: arguably the best consumer CPU for GW2 (96 MB V-Cache) paired with a 1080p-class GPU pushed to 1440p. That makes it a useful probe — it can hit *either* wall depending on content.

### Crowded scene (Lion's Arch, busy plaza)

| | baseline | tuned | gain |
|---|---|---|---|
| Average FPS | 49.3 | **62.0** | **+26%** |
| CPU busy / frame | 19.9 ms | **15.8 ms** | **−20%** |
| 1% low | 30.2 | **42.7** | **+41%** |
| Bottleneck | CPU 98% | CPU 98% | *still CPU-bound* |

Baseline is the **mean of two captures** (before and after the tuning runs) to correct for map-population drift. See [METHODOLOGY.md](METHODOLOGY.md#controls).

### Setting-by-setting, in a CPU-bound scene

Measured as CPU busy time per frame — the thing that actually sets your FPS ceiling when CPU-bound:

| Change | Δ CPU busy | Verdict |
|---|---|---|
| **Character Model Limit** `Low → Lowest` | **−3.00 ms** | **The lever.** Bigger than everything else combined. |
| **Character Model Quality** `Highest → Medium` | **−1.16 ms** | Real. Also cuts GPU (−0.68 ms), so it pays in both regimes. |
| **LOD Distance** `Ultra → Medium` | −0.19 ms | ~1%. Effectively nothing. Common guides overrate this. |

### Empty scene (quiet open world) — GPU-bound

| | baseline | GPU diet | gain |
|---|---|---|---|
| Average FPS | 119.0 | **136.0** | **+14%** |
| GPU busy / frame | 8.05 ms | **6.54 ms** | **−19%** |
| Bottleneck | GPU 96% | GPU 89% / CPU 88% | *converged* |

"GPU diet" = Shaders `High→Medium`, Environment `High→Medium`, Character Model Quality `Highest→Medium`, Depth Blur off.

Note the convergence: after the diet, CPU busy (6.46 ms) and GPU busy (6.54 ms) are essentially equal. **Further GPU cuts would have gained nothing** — the CPU was already the next wall. Knowing where to *stop* cutting is as useful as knowing what to cut.

### Frame pacing

| | uncapped, VSync off | 144 cap + VSync on |
|---|---|---|
| Average FPS | 127.4 | 123.5 (−3%) |
| Frametime stddev | 1.90 ms | **1.64 ms** |
| Consistency (CV) | 24.3% | **20.3% (−16%)** |

3% of average FPS bought 16% tighter frametimes. On a VRR display this is the correct trade — see [METHODOLOGY.md](METHODOLOGY.md#vrr).

---

## The resulting config

One profile, all content. 2560×1440, 165 Hz FreeSync, RX 6600.

```
Frame Limiter ........... 144          (engine-level; inside the VRR window)
Vertical Sync ........... ON           (tear backstop; never engages as classic VSync when capped)
Character Model Limit ... Lowest       <- the lever
Character Model Quality . Medium
Level of Detail ......... Medium
Shaders ................. Medium
Environment ............. Medium
Reflections ............. None
Shadows ................. Medium
Postprocessing .......... Custom (Depth Blur off, Ambient Occlusion off)
Sampling ................ Native
Texture Detail .......... High
Screen Mode ............. Windowed Fullscreen
Effect LOD .............. On
```

Scale the GPU-side settings (Shaders / Environment / Shadows / Reflections) to your own GPU. The **CPU-side** conclusions — Character Model Limit and Quality — should generalize to any rig, because GW2's game thread is the wall regardless of what silicon you have.

---

## Things that are widely repeated and are wrong

Verified against primary sources (ArenaNet dev blogs, the GW2 wiki, AMD documentation) — not against other guides.

| Claim | Reality |
|---|---|
| "Add `-dx11` to your launch options" | **Deprecated 2023-07-18.** DX11 is the only renderer. The flag does nothing. |
| "Use exclusive Fullscreen for more FPS" | **GW2's DX11 client has no exclusive fullscreen.** ArenaNet has said they don't plan to add it. The dropdown option runs borderless anyway. |
| "Disable Fullscreen Optimizations" | Backwards. It can knock GW2 off the flip-model path and **cost you VRR**. |
| "Set Tessellation override to x2" | GW2 uses **zero tessellation.** Its DX11 backend is BGFX, which has no tessellation stages ([bgfx#332](https://github.com/bkaradzic/bgfx/issues/332), open since 2015). |
| "Pin GW2 to specific CPU cores" | Actively harmful. GW2 spawns worker threads scaled to core count; pinning removes them. |
| "`-fps 144` caps your framerate" | Documented bug — it only affects **loading screens**. |
| "Enable Radeon Boost / Anti-Lag 2" | Neither supports GW2. It's not on AMD's whitelist for either. |
| "Turn VSync off with FreeSync" | Wrong when capped below refresh. VSync ON costs ~1–2 ms; running uncapped past the VRR ceiling costs **~21 ms**. |
| "Clear your shader cache to fix stutter" | Makes it worse. GW2 has genuine shader-compile stutter; the cache is what fixes it. |

---

## Reproduce this on your own hardware

```powershell
# 1. Get PresentMon (Intel, signed, passive ETW consumer - no anti-cheat concern)
#    https://github.com/GameTechDev/PresentMon/releases

# 2. Capture 60s while you play (needs admin for ETW)
.\tools\capture.ps1 -Label "myrig_lionsarch_baseline"

# 3. Analyze
.\tools\analyze.ps1 -Csv .\data\myrig_lionsarch_baseline.csv
```

`analyze.ps1` reports average FPS, 1%/0.1% lows, frametime stddev, **CPU busy vs GPU busy** (which tells you your actual bottleneck), and **present mode** (which tells you whether VRR can engage at all).

**Please run controls.** Re-capture your baseline *after* your test runs. Map population drifts, shader caches warm, and both will happily fabricate a result for you. Ours did — twice. See [METHODOLOGY.md](METHODOLOGY.md#controls).

PRs with results from other hardware are very welcome — especially non-X3D CPUs and stronger GPUs, which would test whether the "CPU-bound whenever players exist" finding generalizes.

---

## Contents

- [`RESULTS.md`](RESULTS.md) — every capture, full numbers
- [`METHODOLOGY.md`](METHODOLOGY.md) — protocol, controls, and what we got wrong
- [`HARDWARE.md`](HARDWARE.md) — test system, and the OS/driver settings that matter
- [`tools/`](tools/) — capture + analysis scripts
- [`data/`](data/) — 10 raw PresentMon CSVs

## Caveats

Read [METHODOLOGY.md](METHODOLOGY.md) before citing any of this. In short: n=1 machine, Lion's Arch population is uncontrolled (we corrected for it, imperfectly), and the "baseline" already had Reflections and Shadows lowered before capture began — so the gains versus a true stock config are **larger than reported here, but unmeasured**.

## License

MIT. Data and findings free to use; attribution appreciated.
