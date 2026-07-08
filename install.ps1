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

if (Test-Path $target) {
    $backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Backing up existing $target -> $backup"
    Move-Item $target $backup
}
New-Item -ItemType Directory -Force -Path $target | Out-Null

$items = @(
    'mpv.conf', '.env.example', 'input.conf', 'profiles.conf', 'hdr-toys.conf',
    'fonts', 'script-modules', 'script-opts', 'scripts', 'cuda-crop-py', 'shaders'
)
foreach ($it in $items) {
    $p = Join-Path $src.FullName $it
    if (Test-Path $p) { Copy-Item -Path $p -Destination $target -Recurse -Force }
}

if (Test-Path (Join-Path $target 'cuda-crop-py')) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        Write-Host 'Installing cuda-crop-py dependencies'
        Push-Location (Join-Path $target 'cuda-crop-py')
        try { uv sync } finally { Pop-Location }
    } else {
        Write-Host 'uv is not installed; install it, then run: cd "%APPDATA%\mpv\cuda-crop-py"; uv sync'
    }
}

Remove-Item $zip -Force -ErrorAction SilentlyContinue
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "Installed mpv config to $target"
Write-Host 'Copy .env.example to .env and fill in your API keys (SubDL / TMDB / TVDB).'
