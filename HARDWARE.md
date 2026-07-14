# Test system

| | |
|---|---|
| **CPU** | AMD Ryzen 7 5800X3D — 8C/16T, **96 MB L3 (V-Cache)** |
| **GPU** | AMD Radeon RX 6600 — 8 GB GDDR6, 128-bit, 32 CU (RDNA2) |
| **RAM** | 16 GB DDR4-3600 C16, dual channel (DOCP enabled) |
| **Display** | 2× Samsung Odyssey G5 (LS27CG51x), 2560×1440 @ 165 Hz, FreeSync |
| **Storage** | NVMe SSD (`Gw2.dat` = 81.7 GB, on NVMe) |
| **Board** | ASUS TUF GAMING B550M-PLUS WIFI II, BIOS 3636 |
| **OS** | Windows 11 Pro 25H2 (build 26200) |
| **Driver** | AMD Adrenalin 26.6.2 |
| **Game** | Guild Wars 2, build 202990, DX11 |

## Why this pairing is a useful probe

It's deliberately lopsided. The 5800X3D is arguably the **best consumer CPU that exists for GW2** — the game is cache-hungry and single-thread-bound, and 96 MB of V-Cache is exactly what it wants. The RX 6600 is a **1080p-class GPU being pushed to 1440p**.

So the machine can hit *either* wall depending on content — which makes it a good instrument for finding out **which wall GW2 actually hits.** (Answer: the CPU one, almost always.)

---

## OS / driver settings that actually matter

Verified against primary sources, not guides.

### Windows

| Setting | Value | Why |
|---|---|---|
| **Optimizations for windowed games** | **ON** | Converts DX11 games from the legacy blt path to the **flip model**. Without it, **VRR silently does nothing in borderless** — and GW2's DX11 client has no exclusive fullscreen, so it is *permanently* dependent on this. Verify via `PresentMode` in a capture. |
| **Variable refresh rate** (Graphics → Advanced) | **ON** | Off by default. Enables VRR for DX11 titles that don't drive it natively. |
| Power plan | High performance | Min processor state 100%. Prevents core-parking frametime spikes. |
| GameDVR / Xbox Game Bar capture | OFF | Overlays can break the flip-model path. |
| Game Mode | leave on | Neutral. No GW2-specific evidence either way. |
| CPU affinity / priority | **don't touch** | GW2 spawns worker threads scaled to core count. Pinning **removes workers**. Realtime priority can starve input/audio. |

### AMD Adrenalin (per-game profile for GW2)

| Setting | Value | Why |
|---|---|---|
| **FreeSync** | **ON** | The whole point. |
| **Enhanced Sync** | **OFF** | Documented black-screen defect history (AMD's own release notes; only "fixed" in 22.9.1, then dropped from the HYPR-RX profile because it still broke configs). Also redundant once you cap below refresh. Users on similar hardware report microstutter from it. |
| **Radeon Chill** | **OFF** | It *deliberately oscillates framerate based on input*. That is precisely the failure mode GW2 already has. |
| **Radeon Boost** | **OFF** | **Does not support GW2** — not on AMD's whitelist. The toggle is a no-op. |
| **Radeon Anti-Lag** | **OFF** | Only helps when GPU-bound. GW2 is CPU-bound. **Anti-Lag 2 doesn't support GW2** either (not on AMD's supported-games list). |
| **Image Sharpening** | **ON, ~35%** | GW2's DX11 renders noticeably soft. Costs ~1% GPU (AMD's own measurement). Cheap quality win. |
| **Radeon Super Resolution** | **OFF** | Upscales the **entire frame including UI** — bad in a text-dense MMO. GW2's own Sampling slider does the same job and leaves the UI native. |
| **Frame Rate Target Control** | **OFF** | AMD documents it as **fullscreen-only** — unreliable in Windowed Fullscreen, which is what GW2 always runs. |
| **Shader Cache** | **AMD optimized** | **Never** set to Off. GW2 has real shader-compile stutter; the cache is the mitigation. |
| **Tessellation** | default | GW2 uses **zero tessellation** — its DX11 backend is BGFX, which has no tessellation stages. "Override to x2" guides are noise. |
| **Texture Filtering Quality** | Standard | Effectively free on RDNA2. The "set to Performance" advice traces to 2012-era GCN threads. |
| **Surface Format Optimization** | default (on) | AMD recommends leaving it on. |
| **HYPR-RX** | **OFF** | One click enables AFMF + RSR + Anti-Lag + Boost — four features that are variously useless, harmful, or non-functional here. |

### BIOS

| Setting | Value | Why |
|---|---|---|
| **Above 4G Decoding** | Enabled | Prerequisite for Resizable BAR. |
| **Re-Size BAR Support** | Enabled | **Smart Access Memory.** Free performance on a bandwidth-starved 128-bit card. Verify in Adrenalin → Settings → System → Hardware. |
| DOCP / EXPO | Enabled | GW2 is latency/cache-sensitive. Running RAM at JEDEC speeds costs real frames. |

---

## Checking your own state

```powershell
# Bottleneck + present mode (the two things that matter)
.\tools\analyze.ps1 -Csv .\data\your_capture.csv

# Is Resizable BAR on?  (0 = off)
$k = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
(Get-ItemProperty $k).KMD_RebarControlMode

# Are the Windows flip-model / VRR toggles set?
(Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences').DirectXUserGlobalSettings
# want: SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;
```

---

## A note on virtual display adapters

The test system originally had a **Parsec Virtual Display Adapter** installed alongside the Radeon. It was removed before the captures.

This matters more for GW2 than for most games. Because GW2's DX11 client **never takes exclusive fullscreen**, it is permanently dependent on DWM composition and the flip model. A virtual display injects an extra DXGI output into exactly that path, and the documented failure mode is **VRR silently disengaging** — with no warning and no indicator.

If you have a virtual display driver (Parsec, Sunshine, VirtualDisplayDriver, etc.) and GW2 feels wrong despite good FPS: **remove it and re-check `PresentMode`.**
