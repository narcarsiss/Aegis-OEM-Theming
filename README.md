<p align="center">
  <img src="https://github.com/narcarsiss/Aegis-Win11/raw/main/assets/AgeisLogo.jpeg" alt="Aegis Win11 Logo" width="500" />
</p>

---

# Aegis-OEM-Theming

Standalone, post-creation OEM branding and theming injection utility for Windows 11 automated deployments. 

`Aegis-OEM-Theming` is an independent companion package for the `Aegis-Win11` deployment toolkit. It allows administrators to stage 4K custom wallpapers, fallback theme files, and multi-resolution user profile picture suites directly into a prepared installation USB drive without altering core deployment code or bloating the primary git repository with large image files.

---

## Directory Layout

```
Aegis-OEM-Theming/
├── Install-AegisTheme.ps1            # Master injection script
├── README.md                         # Technical manual
├── LICENSE                           # MIT License
└── assets/                           # Default image assets
    ├── Master_Wallpaper.png          # Default 16:9 master wallpaper
    └── Master_Avatar.png             # Default 1:1 master avatar
```

---

## Technical Functionality

1. **Wallpaper Deployment:** Stages `Wallpaper1.jpg` through `Wallpaper5.jpg` under `%WINDIR%\Web\Wallpaper\Custom\`. Automatically replaces `%WINDIR%\Web\Wallpaper\Windows\img0.jpg` and the high-resolution files under `%WINDIR%\Web\4K\Wallpaper\Windows\img0_*.jpg` to override the default Windows 11 Bloom graphic across all monitor resolutions.
2. **Global Avatar Enforcement:** Resamples the master avatar into the five official PNG sizes (32x32, 40x40, 48x48, 192x192, 448x448) and legacy BMP formats required by the Windows Shell under `%ProgramData%\Microsoft\User Account Pictures\`.
3. **Automated XML DOM Configuration:** Automatically checks for `autounattend.xml` on the target USB root, injecting the `<Themes>` block into `oobeSystem` and the `UseDefaultTile = 1` registry command into `specialize`.

---

## Usage Instructions

>To permanently change the defaults for your organization, replace `Master_Wallpaper.png` and `Master_Avatar.png` inside the `assets/` folder.

### Default Execution (Using Included Assets)
Insert your prepared `Aegis-Win11` installer USB, open an elevated PowerShell prompt, and run:

```powershell
.\Install-AegisTheme.ps1 -UsbDrive "E:"
```

### Custom Execution (Using External Assets)
To inject custom branding without modifying the repository files:

```powershell
.\Install-AegisTheme.ps1 `
    -UsbDrive "E:" `
    -MasterWallpaperPath "C:\Branding\Company_4K_Wall.png" `
    -MasterAvatarPath "C:\Branding\Company_Logo_Square.png"
```

---

## License

Released by Moosehead Studio under the MIT License.
