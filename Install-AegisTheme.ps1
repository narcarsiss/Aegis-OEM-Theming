<#
.SYNOPSIS
    Automated OEM theming and user account picture injection engine.
.DESCRIPTION
    Injects physical 4K wallpaper fallback trees, custom wallpaper selections,
    and multi-DPI user account picture tiles into an Aegis Win11 USB installation media.
    Dynamically injects <Themes> and UseDefaultTile registry policies into autounattend.xml.
.PARAMETER UsbDrive
    The drive letter of the target mounted installation USB (e.g., 'E:' or 'E').
.PARAMETER MasterWallpaperPath
    Path to the master 16:9 wallpaper. Defaults to .\assets\Master_Wallpaper.png.
.PARAMETER MasterAvatarPath
    Path to the master 1:1 avatar. Defaults to .\assets\Master_Avatar.png.
.PARAMETER AllowTheming
    Enables or disables the theming injection pipeline. Defaults to $true.
.EXAMPLE
    .\Install-AegisTheme.ps1 -UsbDrive "E:"
.EXAMPLE
    .\Install-AegisTheme.ps1 -UsbDrive "E:" -MasterWallpaperPath "C:\Custom\Wall.png" -MasterAvatarPath "C:\Custom\Avatar.png"
.NOTES
    Author: Damien John O'Brien / Moosehead Studio
    Repository: Aegis-OEM-Theming
    Version: 1.0.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [string]$UsbDrive,

    [Parameter(Mandatory = $false)]
    [string]$MasterWallpaperPath = (Join-Path $PSScriptRoot "assets\Master_Wallpaper.png"),

    [Parameter(Mandatory = $false)]
    [string]$MasterAvatarPath = (Join-Path $PSScriptRoot "assets\Master_Avatar.png"),

    [Parameter(Mandatory = $false)]
    [bool]$AllowTheming = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $AllowTheming) {
    Write-Host "[INFO] Theming injection skipped: -AllowTheming is `$false." -ForegroundColor Yellow
    exit 0
}

# Resolve USB Volume
$CleanDrive = ($UsbDrive.TrimEnd('\').TrimEnd(':') + ":")
if (-not (Test-Path "$CleanDrive\")) {
    throw "[FATAL] Specified drive '$CleanDrive' is not mounted or accessible."
}

# Verify Source Images
if (-not (Test-Path $MasterWallpaperPath -PathType Leaf)) {
    throw "[FATAL] Master wallpaper not found at '$MasterWallpaperPath'. Place an image in assets\ or supply -MasterWallpaperPath."
}
if (-not (Test-Path $MasterAvatarPath -PathType Leaf)) {
    throw "[FATAL] Master avatar not found at '$MasterAvatarPath'. Place an image in assets\ or supply -MasterAvatarPath."
}

$UnattendPath     = "$CleanDrive\autounattend.xml"
$DistributionRoot = "$CleanDrive\sources\`$OEM$\$1"

Write-Host "[INFO] Target USB: $CleanDrive" -ForegroundColor Cyan
Write-Host "[INFO] Distribution Share: $DistributionRoot" -ForegroundColor Cyan

# 1. Directory Tree Construction
$wallpaperCustomDir = Join-Path $DistributionRoot "Windows\Web\Wallpaper\Custom"
$wallpaperWinDir    = Join-Path $DistributionRoot "Windows\Web\Wallpaper\Windows"
$wallpaper4KDir     = Join-Path $DistributionRoot "Windows\Web\4K\Wallpaper\Windows"
$avatarDir          = Join-Path $DistributionRoot "ProgramData\Microsoft\User Account Pictures"

$allDirs = @($wallpaperCustomDir, $wallpaperWinDir, $wallpaper4KDir, $avatarDir)
foreach ($dir in $allDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# 2. Stage Wallpaper Assets & 4K Fallback Suite
Write-Host "[INFO] Processing and deploying wallpaper distribution suite..." -ForegroundColor Cyan
Copy-Item -Path $MasterWallpaperPath -Destination (Join-Path $wallpaperCustomDir "Wallpaper1.jpg") -Force
Copy-Item -Path $MasterWallpaperPath -Destination (Join-Path $wallpaperWinDir "img0.jpg") -Force

# Stage 4K multi-resolution overrides to defeat Windows default Bloom replacement
$resolutions = @("1920x1200", "2560x1600", "3840x2160")
foreach ($res in $resolutions) {
    Copy-Item -Path $MasterWallpaperPath -Destination (Join-Path $wallpaper4KDir "img0_$res.jpg") -Force
}

# Populate slots 2 through 5 with master asset as placeholders
for ($i = 2; $i -le 5; $i++) {
    $slotPath = Join-Path $wallpaperCustomDir "Wallpaper$i.jpg"
    if (-not (Test-Path $slotPath)) {
        Copy-Item -Path $MasterWallpaperPath -Destination $slotPath -Force
    }
}

# 3. GDI+ Avatar Resampling Pipeline
Write-Host "[INFO] Generating multi-DPI user account picture tiles..." -ForegroundColor Cyan
Add-Type -AssemblyName System.Drawing

$avatarSizes = @(32, 40, 48, 192, 448)
$srcImage = [System.Drawing.Image]::FromFile((Convert-Path $MasterAvatarPath))

try {
    foreach ($dim in $avatarSizes) {
        $destBitmap = New-Object System.Drawing.Bitmap($dim, $dim, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graph = [System.Drawing.Graphics]::FromImage($destBitmap)
        $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graph.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graph.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graph.DrawImage($srcImage, 0, 0, $dim, $dim)

        $fileName = if ($dim -eq 448) { "user.png" } else { "user-$dim.png" }
        $destBitmap.Save((Join-Path $avatarDir $fileName), [System.Drawing.Imaging.ImageFormat]::Png)

        if ($dim -eq 448) {
            $destBitmap.Save((Join-Path $avatarDir "guest.png"), [System.Drawing.Imaging.ImageFormat]::Png)
            $destBitmap.Save((Join-Path $avatarDir "user.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
            $destBitmap.Save((Join-Path $avatarDir "guest.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
        }

        $graph.Dispose()
        $destBitmap.Dispose()
    }
}
finally {
    $srcImage.Dispose()
}

# 4. XML DOM Policy Injection (autounattend.xml)
if (Test-Path $UnattendPath) {
    Write-Host "[INFO] Modifying autounattend.xml to register theme and global avatar tile policy..." -ForegroundColor Cyan
    
    [xml]$xmlDoc = Get-Content -Path $UnattendPath -Encoding utf8
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
    $nsMgr.AddNamespace("u", "urn:schemas-microsoft-com:unattend")
    $nsMgr.AddNamespace("wcm", "http://schemas.microsoft.com/WMIConfig/2002/State")

    # Invalidate existing Themes block if present
    $existingThemes = $xmlDoc.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']/u:Themes", $nsMgr)
    if ($null -ne $existingThemes) {
        $existingThemes.ParentNode.RemoveChild($existingThemes) | Out-Null
    }

    # Inject Themes configuration into oobeSystem pass
    $oobeShell = $xmlDoc.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $nsMgr)
    if ($null -ne $oobeShell) {
        $themesNode = $xmlDoc.CreateElement("Themes", "urn:schemas-microsoft-com:unattend")
        
        $themeNameNode = $xmlDoc.CreateElement("ThemeName", "urn:schemas-microsoft-com:unattend")
        $themeNameNode.InnerText = "AegisEnterprise"
        [void]$themesNode.AppendChild($themeNameNode)

        $bgNode = $xmlDoc.CreateElement("DesktopBackground", "urn:schemas-microsoft-com:unattend")
        $bgNode.InnerText = "%WINDIR%\Web\Wallpaper\Custom\Wallpaper1.jpg"
        [void]$themesNode.AppendChild($bgNode)

        [void]$oobeShell.AppendChild($themesNode)
    }

    # Inject UseDefaultTile registry command into specialize pass
    $specializeDeployment = $xmlDoc.SelectSingleNode("//u:settings[@pass='specialize']/u:component[@name='Microsoft-Windows-Deployment']/u:RunSynchronous", $nsMgr)
    if ($null -eq $specializeDeployment) {
        $specializePass = $xmlDoc.SelectSingleNode("//u:settings[@pass='specialize']", $nsMgr)
        if ($null -ne $specializePass) {
            $depComp = $xmlDoc.CreateElement("component", "urn:schemas-microsoft-com:unattend")
            $depComp.SetAttribute("name", "Microsoft-Windows-Deployment")
            $depComp.SetAttribute("processorArchitecture", "amd64")
            $depComp.SetAttribute("publicKeyToken", "31bf3856ad364e35")
            $depComp.SetAttribute("language", "neutral")
            $depComp.SetAttribute("versionScope", "nonSxS")
            
            $runSync = $xmlDoc.CreateElement("RunSynchronous", "urn:schemas-microsoft-com:unattend")
            [void]$depComp.AppendChild($runSync)
            [void]$specializePass.AppendChild($depComp)
            $specializeDeployment = $runSync
        }
    }

    if ($null -ne $specializeDeployment) {
        $cmdNode = $xmlDoc.CreateElement("RunSynchronousCommand", "urn:schemas-microsoft-com:unattend")
        $cmdNode.SetAttribute("action", "http://schemas.microsoft.com/WMIConfig/2002/State", "add")
        
        $orderNode = $xmlDoc.CreateElement("Order", "urn:schemas-microsoft-com:unattend")
        $orderNode.InnerText = "99"
        [void]$cmdNode.AppendChild($orderNode)

        $descNode = $xmlDoc.CreateElement("Description", "urn:schemas-microsoft-com:unattend")
        $descNode.InnerText = "Enforce Global Default User Account Picture"
        [void]$cmdNode.AppendChild($descNode)

        $pathNode = $xmlDoc.CreateElement("Path", "urn:schemas-microsoft-com:unattend")
        $pathNode.InnerText = 'reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v UseDefaultTile /t REG_DWORD /d 1 /f'
        [void]$cmdNode.AppendChild($pathNode)

        [void]$specializeDeployment.AppendChild($cmdNode)
    }

    $xmlDoc.Save($UnattendPath)
    Write-Host "[SUCCESS] autounattend.xml updated with theme and avatar enforcement." -ForegroundColor Green
} else {
    Write-Host "[WARNING] autounattend.xml not detected on root of $CleanDrive. XML modification skipped." -ForegroundColor Yellow
}

Write-Host "[SUCCESS] Aegis OEM Theming deployment package successfully built on $CleanDrive." -ForegroundColor Green
