# Publie app-release.apk en GitHub Release et regenerere le QR d'installation (prod).
# Usage:
#   .\scripts\publish-apk-release.ps1
#   .\scripts\publish-apk-release.ps1 -Version "1.0.1" -Tag "v1.0.1"

param(
  [string]$Version = "1.0.0",
  [string]$Tag = "v1.0.0",
  [string]$Repo = "Modou1ngom/CofiPointe",
  [string]$ApkPath = "",
  [string]$GhExe = "gh"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $ApkPath) {
  $ApkPath = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
}

if (-not (Test-Path $ApkPath)) {
  throw "APK introuvable: $ApkPath`nLancez d'abord: flutter build apk --release"
}

$OutDir = Join-Path $Root "build\app\outputs\flutter-apk"
$DownloadUrl = "https://github.com/$Repo/releases/download/$Tag/app-release.apk"
$LatestUrl = "https://github.com/$Repo/releases/latest/download/app-release.apk"
$QrPath = Join-Path $OutDir "cofipointe-install-qr-prod.png"
$HtmlPath = Join-Path $OutDir "installer-prod.html"

Write-Host ">> Upload GitHub Release $Tag ($Version)"
& $GhExe release view $Tag --repo $Repo 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "Release $Tag existe deja — mise a jour de l'asset APK"
  & $GhExe release delete-asset $Tag app-release.apk --repo $Repo --yes 2>$null
  & $GhExe release upload $Tag $ApkPath --repo $Repo --clobber
} else {
  & $GhExe release create $Tag $ApkPath `
    --repo $Repo `
    --title "CofiPointe $Version" `
    --notes "APK release $Version — scanner le QR ou telecharger depuis la page d'installation."
}

Write-Host ">> Generation QR prod"
$QrApi = "https://api.qrserver.com/v1/create-qr-code/?size=480x480&data=" + [uri]::EscapeDataString($LatestUrl)
Invoke-WebRequest -Uri $QrApi -OutFile $QrPath -UseBasicParsing

@"
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>CofiPointe — Installer (production)</title>
  <style>
    :root { --bg:#1a1410; --fg:#f5ebe0; --accent:#c4a574; }
    * { box-sizing: border-box; }
    body {
      margin: 0; min-height: 100vh; display: grid; place-items: center;
      font-family: "Segoe UI", sans-serif;
      background: radial-gradient(ellipse at 30% 20%, #2a2218, var(--bg) 60%);
      color: var(--fg); text-align: center; padding: 2rem;
    }
    h1 { margin: 0 0 0.5rem; font-weight: 600; }
    p { opacity: 0.85; max-width: 28rem; margin: 0 auto 1.5rem; line-height: 1.45; }
    img { width: min(280px, 70vw); background: #fff; padding: 12px; border-radius: 8px; }
    a.btn {
      display: inline-block; margin-top: 1.5rem; padding: 0.85rem 1.4rem;
      background: var(--accent); color: #1a1410; text-decoration: none;
      font-weight: 600; border-radius: 6px;
    }
    .url { font-size: 0.85rem; word-break: break-all; opacity: 0.7; margin-top: 1rem; }
  </style>
</head>
<body>
  <main>
    <h1>CofiPointe</h1>
    <p>Scannez le QR pour telecharger et installer l'application (production).</p>
    <img src="https://api.qrserver.com/v1/create-qr-code/?size=480x480&amp;data=$([uri]::EscapeDataString($LatestUrl))" alt="QR installation CofiPointe" width="480" height="480" />
    <div><a class="btn" href="$LatestUrl">Telecharger l'APK</a></div>
    <p class="url">$LatestUrl</p>
  </main>
</body>
</html>
"@ | Set-Content -Path $HtmlPath -Encoding UTF8

Write-Host ""
Write-Host "OK — Production"
Write-Host "  APK tag     : $DownloadUrl"
Write-Host "  APK latest  : $LatestUrl"
Write-Host "  QR          : $QrPath"
Write-Host "  Page HTML   : $HtmlPath"
Write-Host ""
Write-Host "Astuce: hebergez installer-prod.html (GitHub Pages / n'importe quel hebergement) pour une page propre."
