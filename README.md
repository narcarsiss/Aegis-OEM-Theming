# Aegis-OEM-Theming

Standalone, post-creation branding and theming injection engine for Windows 11 automated deployments. 

`Aegis-OEM-Theming` operates as an independent companion package for the `Aegis-Win11` deployment toolkit. It allows administrators to stage custom 4K wallpapers and downsample master user profile avatars directly into an installation USB drive without altering core deployment code or polluting the primary git repository with large binary graphic assets.

---

## Architecture Overview

Windows 11 pulls default desktop backgrounds and account avatars from specific physical paths on the local drive:

* **Desktop Wallpapers:** Standard out-of-the-box backgrounds originate from `%SystemRoot%\Web\Wallpaper\Windows\img0.jpg`. On 4K monitors, the Desktop Window Manager checks `%SystemRoot%\Web\4K\Wallpaper\Windows\img0_*.jpg` prior to falling back to 1080p.
* **User Account Pictures:** Avatars for all local users, the built-in Administrator, and the sign-in screen are retrieved from `%ProgramData%\Microsoft\User Account Pictures\`. Forcing Windows to apply these custom images globally requires setting `UseDefaultTile = 1` under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`.

`Install-AegisTheme.ps1` processes master input assets and writes them to the `$OEM$\$1\` distribution share on the installer USB media. Windows Setup automatically copies all files from `sources\$OEM$\$1\` directly to `C:\` during the early offline file-copy phase.

---

## Directory Staging Topology

When injected onto the installer USB, the following filesystem structure is staged:

```
USB_DRIVE:\
├── autounattend.xml
└── sources\
    └── $OEM$\
        └── $1\
            ├── ProgramData\
            │   └── Microsoft\
            │       └── User Account Pictures\
            │           ├── guest.bmp        (448x448 24-bit BMP)
            │           ├── guest.png        (448x448 32-bit RGBA)
            │           ├── user-32.png      (32x32 32-bit RGBA)
            │           ├── user-40.png      (40x40 32-bit RGBA)
            │           ├── user-48.png      (48x48 32-bit RGBA)
            │           ├── user-192.png     (192x192 32-bit RGBA)
            │           ├── user.bmp         (448x448 24-bit BMP)
            │           └── user.png         (448x448 32-bit RGBA)
            └── Windows\
                └── Web\
                    ├── 4K\
                    │   └── Wallpaper\
                    │       └── Windows\
                    │           ├── img0_1920x1200.jpg
                    │           ├── img0_2560x1600.jpg
                    │           └── img0_3840x2160.jpg
                    └── Wallpaper\
                        ├── Custom\
                        │   ├── Wallpaper1.jpg (Primary Wallpaper)
                        │   ├── Wallpaper2.jpg
                        │   ├── Wallpaper3.jpg
                        │   ├── Wallpaper4.jpg
                        │   └── Wallpaper5.jpg
                        └── Windows\
                            └── img0.jpg       (Standard Bloom Fallback)
```

---

## Usage Instructions

### Prerequisites
* Windows PowerShell 5.1 or PowerShell 7 running elevated.
* A bootable Windows 11 USB installer prepared with `Aegis-Win11`.
* A high-resolution 16:9 master wallpaper (`Master_Wallpaper.png`).
* A high-resolution 1:1 square master avatar (`Master_Avatar.png`).

### Execution
Run the injection script targeting the mounted USB drive:

```powershell
.\scripts\Install-AegisTheme.ps1 `
    -UsbDrive "E:" `
    -MasterWallpaperPath ".\assets\raw\Master_Wallpaper.png" `
    -MasterAvatarPath ".\assets\raw\Master_Avatar.png" `
    -AllowTheming $true
```

### Parameter Reference

* `-UsbDrive`: Drive letter of the target installation USB volume.
* `-MasterWallpaperPath`: Full path to the source wallpaper graphic.
* `-MasterAvatarPath`: Full path to the source avatar graphic.
* `-AllowTheming`: Boolean switch (default `$true`). Setting to `$false` aborts injection without modifying the target media.

---

## License

Released by Moosehead Studio under the MIT License.
```
