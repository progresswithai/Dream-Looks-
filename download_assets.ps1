# download_assets.ps1
# This script downloads all external assets (images, stylesheets, scripts, and fonts) from apsarabeautycare.com
# and saves them locally in the current folder, then updates all HTML, CSS, and JS files to use relative local paths.

$baseUrl = "https://www.apsarabeautycare.com"
$baseDir = $PSScriptRoot

if ([string]::IsNullOrEmpty($baseDir)) {
    $baseDir = Get-Location
}

# Function to calculate relative path between two files
function Get-RelativePath {
    param (
        [string]$fromDir,
        [string]$toFile
    )
    if (-not $fromDir.EndsWith("\") -and -not $fromDir.EndsWith("/")) {
        $fromDir += "/"
    }
    $fromUri = New-Object System.Uri $fromDir
    $toUri = New-Object System.Uri $toFile
    $relativeUri = $fromUri.MakeRelativeUri($toUri)
    $relPath = $relativeUri.OriginalString
    
    # URL decode any encoded characters
    $decodedPath = [System.Web.HttpUtility]::UrlDecode($relPath)
    if ($decodedPath) {
        return $decodedPath
    }
    return $relPath
}

Write-Host "=========================================================" -ForegroundColor Yellow
Write-Host "         Apsara Beauty Care Asset Localizer" -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor Yellow
Write-Host "Target directory: $baseDir"
Write-Host "Target base URL: $baseUrl"

$downloadCount = 0
$updateCount = 0

# List of critical assets to download upfront (stylesheets, scripts, images, and fonts)
$essentialAssets = @(
    # CSS Stylesheets
    "css/bootstrap.min.css",
    "css/fontawesome/css/font-awesome.min.css",
    "css/owl.carousel.min.css",
    "css/bootstrap-select.min.css",
    "css/magnific-popup.min.css",
    "css/loader.min.css",
    "css/style.css",
    "css/flaticon.min.css",
    "css/service.css",
    "plugins/revolution/revolution/css/settings.css",
    "plugins/revolution/revolution/css/navigation.css",
    
    # JS Scripts
    "js/jquery-2.2.0.min.js",
    "js/popper.min.js",
    "js/bootstrap.min.js",
    "js/bootstrap-select.min.js",
    "js/magnific-popup.min.js",
    "js/waypoints.min.js",
    "js/counterup.min.js",
    "js/waypoints-sticky.min.js",
    "js/isotope.pkgd.min.js",
    "js/owl.carousel.min.js",
    "js/stellar.min.js",
    "js/theia-sticky-sidebar.js",
    "js/custom.js",
    "plugins/revolution/revolution/js/jquery.themepunch.tools.min.js",
    "plugins/revolution/revolution/js/jquery.themepunch.revolution.min.js",
    "plugins/revolution/revolution/js/extensions/revolution-plugin.js",
    "js/rev-script-2.js",
    
    # Fonts
    "css/fontawesome/fonts/fontawesome-webfont.woff2",
    "css/fontawesome/fonts/fontawesome-webfont.woff",
    "css/fontawesome/fonts/fontawesome-webfont.ttf",
    "css/fontawesome/fonts/fontawesome-webfont.svg",
    "css/fontawesome/fonts/fontawesome-webfont.eot",
    "fonts/flaticon.woff",
    "fonts/flaticon.ttf",
    "fonts/flaticon.svg",
    "fonts/flaticon.eot",
    
    # Images (Favicon & Branding)
    "images/home/main logo_page-0001.jpg",
    "images/favicon.png",
    "images/sep-leaf-left.png",
    "images/sep-leaf-right.png",
    
    # Homepage Slider Images
    "images/banner/hairtreatment.jpg",
    "images/colarge/bridalbanner.jpg",
    "images/banner/massagebanner (2).jpg",
    
    # Homepage About Grid Images
    "images/colarge/haircut.jpg",
    "images/banner/groom.jpg",
    "images/banner/click1.jpg",
    
    # Homepage Services & Backgrounds
    "images/background/bubble-bg.png",
    "images/banner/click.jpg",
    "images/colarge/nail.jpg",
    "images/colarge/facewax.jpg",
    "images/colarge/eyebrow.jpg",
    "images/colarge/bridal.jpg",
    "images/colarge/massage.jpg",
    "images/background/add-bg.png"
)

Write-Host "`nStep 1: Pre-downloading $($essentialAssets.Count) essential stylesheets, scripts, images & fonts..." -ForegroundColor Cyan

$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

foreach ($asset in $essentialAssets) {
    $fullUrl = "$baseUrl/$asset"
    $localPath = Join-Path $baseDir $asset
    $localFolder = Split-Path $localPath -Parent
    
    if (-not (Test-Path $localFolder)) {
        New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
    }
    
    if (-not (Test-Path $localPath)) {
        Write-Host "Downloading: $asset"
        try {
            $webClient.DownloadFile($fullUrl, $localPath)
            $downloadCount++
            Start-Sleep -Milliseconds 150
        } catch {
            Write-Warning "Failed to download essential asset: $fullUrl. Error: $_"
        }
    } else {
        Write-Host "Already local: $asset" -ForegroundColor DarkGreen
    }
}

Write-Host "`nStep 2: Crawling local code files to find and localize all absolute asset references..." -ForegroundColor Cyan

# Find all HTML, CSS, and JS files recursively
$targetFiles = Get-ChildItem -Path $baseDir -Include *.html, *.css, *.js -Recurse -File

# Regular expression to find absolute URLs
$regexPattern = 'https?://(?:www\.)?apsarabeautycare\.com/([^"''\)\s;<>#]+?\.(css|js|webp|png|jpg|jpeg|gif|svg|eot|woff|woff2|ttf|otf))'

foreach ($file in $targetFiles) {
    if ($file.Name -eq "download_assets.ps1") { continue }
    
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    if ([string]::IsNullOrEmpty($content)) {
        continue
    }
    
    $originalContent = $content
    $matches = [regex]::Matches($content, $regexPattern)
    
    if ($matches.Count -gt 0) {
        Write-Host "Found $($matches.Count) reference(s) in: $($file.FullName.Replace($baseDir, ''))" -ForegroundColor Yellow
        
        $replacements = @{}
        
        foreach ($match in $matches) {
            $fullUrl = $match.Value
            
            if ($replacements.ContainsKey($fullUrl)) {
                continue
            }
            
            $relativePath = $match.Groups[1].Value
            $relativePath = $relativePath.Trim("'", '"')
            
            $localSavePath = Join-Path $baseDir $relativePath
            $localDir = Split-Path $localSavePath -Parent
            
            if (-not (Test-Path $localDir)) {
                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
            }
            
            # Download if not already downloaded
            if (-not (Test-Path $localSavePath)) {
                Write-Host " -> Dynamic Download: $relativePath"
                try {
                    $webClient.DownloadFile($fullUrl, $localSavePath)
                    $downloadCount++
                    Start-Sleep -Milliseconds 150
                } catch {
                    Write-Warning "    Failed to download: $fullUrl"
                    continue
                }
            }
            
            # Calculate the relative path from this file's folder to the downloaded asset
            $fileDir = Split-Path $file.FullName -Parent
            $relativePathFromFile = Get-RelativePath -fromDir $fileDir -toFile $localSavePath
            
            # Normalize to forward slashes for web links
            $relativePathFromFile = $relativePathFromFile.Replace('\', '/')
            if ($relativePathFromFile.StartsWith("./")) {
                $relativePathFromFile = $relativePathFromFile.Substring(2)
            }
            
            $replacements[$fullUrl] = $relativePathFromFile
        }
        
        # Apply all replacements
        foreach ($key in $replacements.Keys) {
            $val = $replacements[$key]
            $content = $content.Replace($key, $val)
        }
        
        # Save file if updated
        if ($content -cne $originalContent) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
            $updateCount++
            Write-Host " -> Updated file successfully!" -ForegroundColor Green
        }
    }
}

Write-Host "`n=========================================================" -ForegroundColor Yellow
Write-Host "Localization finished!" -ForegroundColor Yellow
Write-Host "Downloaded: $downloadCount assets"
Write-Host "Updated: $updateCount files"
Write-Host "=========================================================" -ForegroundColor Yellow
Write-Host "You are all set! All assets are local and loading offline."
Write-Host "=========================================================" -ForegroundColor Yellow
