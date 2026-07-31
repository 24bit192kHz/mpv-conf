# mpv-conf Windows installer.
# Run as a one-liner:
#   irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1 | iex
# Or to customize repo/branch/target:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1)))
$ErrorActionPreference = 'Stop'

$repo   = $env:MPV_CONF_REPO   ; if (-not $repo)   { $repo   = '24bit192kHz/mpv-conf' }
$branch = $env:MPV_CONF_BRANCH ; if (-not $branch) { $branch = 'master' }
if (-not $env:MPV_CONF_TARGET) { $target = Join-Path $env:APPDATA 'mpv' } else { $target = $env:MPV_CONF_TARGET }

$zip     = Join-Path $env:TEMP "mpv-conf-$branch.zip"
$extract = Join-Path $env:TEMP "mpv-conf-extract"
$url     = "https://github.com/$repo/archive/refs/heads/$branch.zip"

Write-Host "Downloading $repo@$branch"
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
} catch {
    throw "Download failed: $($_.Exception.Message)"
}

if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $extract -Force
$src = Get-ChildItem -Directory $extract | Select-Object -First 1
if (-not $src) { throw 'Could not unpack config archive' }

$backup = $null
if (Test-Path $target) {
    $backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Backing up existing $target -> $backup"
    Move-Item $target $backup
}
New-Item -ItemType Directory -Force -Path $target | Out-Null

$items = @(
    'mpv.conf', '.env.example', 'input.conf', 'profiles.conf',
    'fonts', 'script-modules', 'script-opts', 'scripts', 'cuda-crop-cpp'
)
foreach ($it in $items) {
    $p = Join-Path $src.FullName $it
    if (Test-Path $p) { Copy-Item -Path $p -Destination $target -Recurse -Force }
}

# Reinstalls keep the user's own settings: .env and every script-opts conf
# from the backup win over the freshly copied repo versions.
if ($backup -and (Test-Path $backup)) {
    $bo = Join-Path $backup 'script-opts'
    if (Test-Path $bo) {
        Copy-Item -Path "$bo\*" -Destination (Join-Path $target 'script-opts') -Recurse -Force
    }
    $benv = Join-Path $backup '.env'
    if (Test-Path $benv) { Copy-Item $benv (Join-Path $target '.env') -Force }
}

# Per-device screenshot directory: the repo conf hardcodes the maintainer's
# Linux path; point it at this user's Desktop\mpv-screenshots (~~desktop is
# expanded by mpv itself).
$mpvConf = Join-Path $target 'mpv.conf'
if (Test-Path $mpvConf) {
    (Get-Content $mpvConf -Raw) -replace [regex]::Escape('/home/btw/Pictures/mpv'), '~~desktop/mpv-screenshots' |
        Set-Content $mpvConf -NoNewline
}

# cuda-crop-cpp: native C++ sidecar (ffprobe + ffmpeg cropdetect). Needs CMake,
# a C++ toolchain, and nlohmann_json (e.g. via vcpkg). Try to build; else print steps.
$cropDir = Join-Path $target 'cuda-crop-cpp'
if (Test-Path $cropDir) {
    $cmake = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmake) {
        Write-Host 'Building cuda-crop-cpp'
        Push-Location $cropDir
        try {
            cmake -B build
            cmake --build build --config Release
        } catch {
            Write-Host 'Build failed. Install a C++ toolchain (Visual Studio) + nlohmann_json (vcpkg), then re-run cmake -B build; cmake --build build --config Release'
        } finally { Pop-Location }
    } else {
        Write-Host 'cmake not found; dynamic crop needs cuda-crop-cpp built: install CMake + Visual Studio (C++), then cmake -B build; cmake --build build --config Release'
    }
}

Remove-Item $zip -Force -ErrorAction SilentlyContinue
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }

# Ready-to-use conf from the example (the old target was backed up above, so
# a fresh install has no ar_subs.conf to clobber).
$confExample = Join-Path $target 'script-opts\ar_subs.conf.example'
$confReal    = Join-Path $target 'script-opts\ar_subs.conf'
if ((Test-Path $confExample) -and -not (Test-Path $confReal)) {
    Copy-Item $confExample $confReal
}

Write-Host "Installed mpv config to $target"
Write-Host 'API keys: edit script-opts\ar_subs.conf (subsource_api_key first, subdl_api_key fallback)'
Write-Host '          or copy .env.example to .env and fill it in (TMDB / TVDB optional).'
