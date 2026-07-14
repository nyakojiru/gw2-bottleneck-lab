# Methodology

## Tooling

[**Intel PresentMon 2.5.1**](https://github.com/GameTechDev/PresentMon) (CLI), `--v2_metrics`. It is a passive ETW consumer — it does not inject into the game process, so there is no anti-cheat concern with GW2 (which in any case has no kernel anti-cheat, and whose community routinely runs ArcDPS and ReShade, both of which *do* inject).

The metrics that matter:

| Column | Meaning |
|---|---|
| `FrameTime` | Total time for the frame (ms). `1000 / FrameTime` = FPS. |
| `CPUBusy` | Time the **CPU** spent working on the frame. |
| `GPUBusy` | Time the **GPU** spent working on the frame. |
| `PresentMode` | Presentation path — determines whether VRR can engage. |

**Bottleneck determination** is the ratio of `CPUBusy` / `GPUBusy` to `FrameTime`. If GPU busy occupies 96% of the frame, the GPU is the wall. If CPU busy occupies 98%, the CPU is. This is *direct measurement*, not inference from a utilization percentage in an overlay — and it's why this data can say things that FPS-counter-based guides cannot.

The other side's busy-time tells you the **headroom**: if you're GPU-bound at 8.05 ms with CPU busy at 5.79 ms, your CPU could sustain `1000/5.79` ≈ 173 FPS if the GPU could feed it.

## Capture protocol

For each data point:

1. Park at a **fixed spot**. Same spot for every run in that scenario.
2. Perform the **same slow 360° camera pan** for the full 60 seconds.
3. Frame Limiter set to **Unlimited** and VSync **off** during measurement runs.
   A frame cap is poison for bottleneck analysis — both CPU and GPU appear idle because they're waiting on the limiter, and every run reports "neither saturated."
4. `--delay 8 --timed 60` — 8 seconds to alt-tab back, then 60 seconds recorded.
5. Change **one setting**. Repeat.

## Controls

**This is the part most guides skip, and it's the part that matters.**

We ran controls twice, and **both times they changed the conclusion.**

### Control 1 — Lion's Arch (caught inflated 0.1% lows)

Captures B1 → B4 showed average FPS climbing 48.3 → 49.1 → 52.1 → 62.0 as we tuned. Encouraging. But that trend is *also* exactly what a city slowly emptying out looks like.

So B5 reverted **every setting to the B1 baseline** and re-captured:

| | B1 (first) | B5 (control, ~15 min later) | drift |
|---|---|---|---|
| Average FPS | 48.3 | 50.2 | **+3.9%** |
| CPU busy | 20.19 ms | 19.63 ms | −2.8% |
| **0.1% low** | **14.7** | **27.1** | **+84%** |
| **Stutter frames** | **22** | **2** | **−91%** |

Average FPS drifted only ~4% — small enough that the +26% tuning gain survives comfortably. **But the 0.1% low drifted +84%.**

That is not population. That is the **shader cache warming up.** B1 was the first time the client rendered that scene in the session, so it was compiling shaders on the render thread — GW2's well-documented shader-compile stutter.

**Consequence:** the "0.1% low went from 14.7 to 34.1 (+132%)" figure we initially computed was mostly cold-cache artifact. Corrected against the drift-adjusted baseline, the real gain is ~+63%, and even that is noisy. Reported honestly in [RESULTS.md](RESULTS.md).

**If you benchmark GW2, warm up in the zone for several minutes before your first capture, or your first run will lie to you.**

### Control 2 — open world (caught a physically impossible result)

Capture A3 lowered Character Model Limit `Low → Lowest` and reported average FPS *dropping* 136.0 → 127.1, with **CPU busy rising 6.46 → 7.37 ms.**

Lowering Character Model Limit cannot increase CPU work — it strictly reduces the number of character models submitted. And GPU busy rose too. When both sides get heavier at once, the *scene* got heavier, not the settings.

Control A3b reverted only that setting and re-captured the same spot:

| | A3 (`Lowest`) | A3b (control, `Low`) | Δ |
|---|---|---|---|
| Average FPS | 127.1 | 127.4 | 0.2% |
| CPU busy | 7.37 ms | 7.39 ms | 0.3% |
| GPU busy | 6.77 ms | 6.67 ms | 1.5% |

Statistically identical. **Character Model Limit `Low` vs `Lowest` makes no measurable difference in open world** — there aren't enough characters present to clamp.

The A2 → A3b drop (136 → 127) was the map filling with players over ~3 minutes.

**And this accidental control produced the repo's central finding**: the same scene, same settings, flipped from `GPU-BOUND (89%)` to `CPU-BOUND (94%)` purely because players arrived.

## VRR

The frame-pacing configuration follows the [Blur Busters G-SYNC 101](https://blurbusters.com/gsync/gsync101-input-lag-tests-and-settings/) doctrine, which is measured and applies to FreeSync (the author states this explicitly):

> **VRR on + VSync on + FPS capped below max refresh + in-game VSync handled once.**

Measured latency at 144 Hz (Blur Busters, Overwatch):

| Config | Avg latency |
|---|---|
| VRR + VSync, **uncapped** | **44 ms** |
| VRR + VSync, capped *at* refresh (144) | 40 ms |
| VRR + VSync, capped **below** refresh (142) | **23 ms** |
| VRR, VSync **off**, capped (142) | 22 ms |

Capping below refresh removes **~21 ms**. VSync ON costs **~1 ms**. This is why "turn VSync off with FreeSync" is bad advice *when you are capped* — you give up guaranteed tear-free frametime-variance compensation to save a millisecond.

**GW2 specifics:**
- The in-game Frame Limiter offers only `Unlimited / 144 / 120 / 60 / 30`. There is no 160 or custom value. "Unlimited" is **hard-capped at 250 FPS** by the engine.
- On a 165 Hz display, **144** is the correct choice: it is engine-level (lowest-latency class of limiter, ~5 ms better than RTSS) and sits safely inside the VRR window.
- An external cap at 158–162 via RTSS would gain ~16 FPS of smoothness but cost ~5 ms of latency. Roughly a wash. Not worth the extra software.

**Verifying VRR is actually live:** check `PresentMode` in the capture.

| PresentMode | Meaning |
|---|---|
| `Hardware: Independent Flip` | Flip model engaged. VRR works, even in borderless. |
| `Hardware Composed: Independent Flip` | Flip model, DWM composited. VRR still works. |
| `Composed: Copy` / blt | **Legacy path. VRR cannot engage.** |

On Windows 11 22H2+, **Settings → System → Display → Graphics → "Optimizations for windowed games"** is what converts a DX11 game from the legacy blt path to flip model. Without it, VRR silently does nothing in borderless — and nothing warns you.

## Known limitations

Be skeptical of this data. We are.

1. **n = 1 machine.** A 5800X3D + RX 6600 is a deliberately lopsided pairing. The CPU-side findings should generalize (GW2's game thread is the wall on any CPU); the GPU-side numbers will not.
2. **Lion's Arch population is uncontrolled.** We corrected with a before/after control, but it is not a clean-room A/B. Gains of <5% in that scenario should not be trusted.
3. **The "baseline" was not stock.** Reflections had already been set to `None` and Shadows to `Medium` before the first capture. So the reported gains **understate** the improvement versus a genuine max-settings config — but we didn't measure that, so we don't claim a number for it.
4. **Single 60-second capture per data point.** No repeat trials, no error bars. Deltas under ~5% are within noise.
5. **Shader-cache state varies across runs.** The first capture in any zone is always worse. We only discovered this because of a control.

## What would make this better

- Repeat trials with error bars.
- A genuinely fixed-population scenario (an empty instanced map, or a guild hall with a known number of characters).
- Captures from other hardware — especially **non-X3D CPUs** and **stronger GPUs**, to test whether "CPU-bound whenever players exist" is a property of the engine or an artifact of this particular rig.
- A true stock-settings baseline.

PRs welcome.
