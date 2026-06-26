# Variants & Features

## Variants

| Variant | Source | Root | Extras |
|---------|--------|------|--------|
| Xiaomi-Ksun | LineageOS SM8350 | KernelSU-Next + SUSFS | BBG |
| Xiaomi-SukiSU | LineageOS SM8350 | SukiSU-Ultra + SUSFS | KPM |
| Xiaomi-NoKSU | LineageOS SM8350 | Vanilla | — |

All variants include: **WildKernels optimization patches** · **LZ4 ZRAM** · **Thin LTO** · **Droidspaces support**

---

## Droidspaces Support

This kernel ships with [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support.

Enabled configs: `SYSVIPC` · `IPC_NS` · `PID_NS` · `POSIX_MQUEUE` · `DEVTMPFS` · Netfilter extras

kABI fix applied for GKI < 6.12 to prevent vendor module crashes on boot.

> **SuSFS users:** disable **"HIDE SUS MOUNTS FOR ALL PROCESSES"** in SuSFS4KSU settings, otherwise containers will fail to start.

---

## Build Details

| | Vili (all variants) |
|--|----------------------|
| Source | `Santhanabalan/android_kernel_xiaomi_sm8350` |
| Branch | `main` |
| Config base | `vendor/lahaina-qgki_defconfig` |
| Platform fragment | `vendor/lahaina_GKI.config` (if present) |
| Device fragment | `vendor/ext_config/vili.config` (if present) |
| Toolchain | Clang r563880c |
| LTO | Thin |
