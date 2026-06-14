param(
    [string]$OutputDir = "Resources/art/map/region_frontiers"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path ".").Path
$outFullPath = Join-Path $repoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $outFullPath | Out-Null

$tileSize = 64
$columns = 10
$tileKinds = @("fill", "edge_h", "edge_v", "corner_ne", "corner_nw", "corner_se", "corner_sw", "end_cap", "edge_diag_down", "edge_diag_up")
$regionRows = @(
    @{
        id = "crystal_wasteland"
        label = "Crystal Wasteland"
        prefix = "crystal_frontier"
        base = "#06171c"
        body = "#0b3440"
        stroke = "#73e7ff"
        accent = "#a6f6ff"
        dim = "#2b7180"
        motif = "crystal"
    },
    @{
        id = "wreckage_battlefield"
        label = "Wreckage Battlefield"
        prefix = "wreckage_frontier"
        base = "#17100b"
        body = "#332015"
        stroke = "#f0a058"
        accent = "#ffd08d"
        dim = "#7c4d2b"
        motif = "wreckage"
    },
    @{
        id = "interference_highland"
        label = "Interference Highland"
        prefix = "interference_frontier"
        base = "#07160d"
        body = "#112a19"
        stroke = "#95ff72"
        accent = "#d1ff9a"
        dim = "#497d39"
        motif = "interference"
    },
    @{
        id = "core_perimeter"
        label = "Core Perimeter"
        prefix = "core_frontier"
        base = "#120a18"
        body = "#291431"
        stroke = "#d091ff"
        accent = "#ff9be8"
        dim = "#724287"
        motif = "core"
    }
)

function TileSvg {
    param([hashtable]$R, [string]$Inner)
    return @"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <defs>
    <clipPath id="tile_clip"><rect x="0" y="0" width="64" height="64"/></clipPath>
  </defs>
  <g clip-path="url(#tile_clip)">
    <rect x="0" y="0" width="64" height="64" fill="$($R.base)"/>
$Inner
  </g>
</svg>
"@
}

function CommonField {
    param([hashtable]$R)
    return @"
    <rect x="0" y="0" width="64" height="64" fill="$($R.body)" opacity="0.50"/>
    <path d="M0 32 H64 M32 0 V64" fill="none" stroke="$($R.stroke)" stroke-width="1" opacity="0.08"/>
"@
}

function Motif {
    param([hashtable]$R, [string]$Density)
    switch ($R.motif) {
        "crystal" {
            if ($Density -eq "dense") {
                return @"
    <path d="M13 46 L21 22 L30 46 Z M36 50 L43 30 L51 50 Z" fill="$($R.dim)" opacity="0.36"/>
    <path d="M21 22 L25 44 M43 30 L47 48 M14 42 H30 M37 46 H51" fill="none" stroke="$($R.accent)" stroke-width="1.2" opacity="0.42"/>
"@
            }
            return @"
    <path d="M44 42 L50 28 L56 42 Z" fill="$($R.dim)" opacity="0.30"/>
"@
        }
        "wreckage" {
            if ($Density -eq "dense") {
                return @"
    <path d="M13 19 L49 50 M49 15 L22 41" fill="none" stroke="$($R.dim)" stroke-width="2" stroke-linecap="round" opacity="0.48"/>
    <path d="M19 29 H34 M35 22 H48 M22 50 H38" fill="none" stroke="$($R.accent)" stroke-width="1.3" opacity="0.34"/>
"@
            }
            return @"
    <path d="M42 18 L54 31 M47 45 L56 37" fill="none" stroke="$($R.dim)" stroke-width="1.8" opacity="0.42"/>
"@
        }
        "interference" {
            if ($Density -eq "dense") {
                return @"
    <path d="M10 18 H24 M34 18 H55 M14 32 H36 M44 32 H58 M7 46 H24 M34 46 H50" fill="none" stroke="$($R.dim)" stroke-width="1.8" stroke-linecap="round" opacity="0.52"/>
"@
            }
            return @"
    <path d="M42 20 H54 M37 44 H51" fill="none" stroke="$($R.dim)" stroke-width="1.6" opacity="0.42"/>
"@
        }
        default {
            if ($Density -eq "dense") {
                return @"
    <circle cx="32" cy="32" r="18" fill="none" stroke="$($R.dim)" stroke-width="1.7" opacity="0.46"/>
    <circle cx="32" cy="32" r="7" fill="none" stroke="$($R.accent)" stroke-width="1.2" opacity="0.38"/>
    <path d="M13 32 H23 M41 32 H51 M32 13 V23 M32 41 V51" fill="none" stroke="$($R.dim)" stroke-width="1.4" opacity="0.42"/>
"@
            }
            return @"
    <circle cx="48" cy="32" r="8" fill="none" stroke="$($R.dim)" stroke-width="1.4" opacity="0.42"/>
"@
        }
    }
}

function BoundaryPath {
    param([hashtable]$R, [string]$Kind)
    switch ($Kind) {
        "edge_h" {
            return @"
    <rect x="0" y="21" width="64" height="22" fill="$($R.dim)" opacity="0.22"/>
    <path d="M0 24 H64 M0 40 H64" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" opacity="0.82"/>
    <path d="M0 32 H64" fill="none" stroke="$($R.accent)" stroke-width="1.1" stroke-linecap="square" opacity="0.34"/>
"@
        }
        "edge_v" {
            return @"
    <rect x="21" y="0" width="22" height="64" fill="$($R.dim)" opacity="0.22"/>
    <path d="M24 0 V64 M40 0 V64" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" opacity="0.82"/>
    <path d="M32 0 V64" fill="none" stroke="$($R.accent)" stroke-width="1.1" stroke-linecap="square" opacity="0.34"/>
"@
        }
        "corner_ne" {
            return @"
    <path d="M0 24 H40 V64 M0 40 H24 V64" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" stroke-linejoin="round" opacity="0.82"/>
    <path d="M0 32 H32 V64" fill="none" stroke="$($R.accent)" stroke-width="1.1" opacity="0.34"/>
    <path d="M22 22 H42 V42" fill="none" stroke="$($R.dim)" stroke-width="8" opacity="0.18"/>
"@
        }
        "corner_nw" {
            return @"
    <path d="M64 24 H24 V64 M64 40 H40 V64" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" stroke-linejoin="round" opacity="0.82"/>
    <path d="M64 32 H32 V64" fill="none" stroke="$($R.accent)" stroke-width="1.1" opacity="0.34"/>
    <path d="M42 22 H22 V42" fill="none" stroke="$($R.dim)" stroke-width="8" opacity="0.18"/>
"@
        }
        "corner_se" {
            return @"
    <path d="M0 24 H24 V0 M0 40 H40 V0" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" stroke-linejoin="round" opacity="0.82"/>
    <path d="M0 32 H32 V0" fill="none" stroke="$($R.accent)" stroke-width="1.1" opacity="0.34"/>
    <path d="M22 42 H42 V22" fill="none" stroke="$($R.dim)" stroke-width="8" opacity="0.18"/>
"@
        }
        "corner_sw" {
            return @"
    <path d="M64 24 H40 V0 M64 40 H24 V0" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" stroke-linejoin="round" opacity="0.82"/>
    <path d="M64 32 H32 V0" fill="none" stroke="$($R.accent)" stroke-width="1.1" opacity="0.34"/>
    <path d="M42 42 H22 V22" fill="none" stroke="$($R.dim)" stroke-width="8" opacity="0.18"/>
"@
        }
        "end_cap" {
            return @"
    <rect x="0" y="21" width="36" height="22" fill="$($R.dim)" opacity="0.22"/>
    <path d="M0 24 H34 M0 40 H34" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" opacity="0.82"/>
    <path d="M35 17 V47 M42 22 V42 M49 27 V37" fill="none" stroke="$($R.accent)" stroke-width="2" stroke-linecap="square" opacity="0.70"/>
    <path d="M0 32 H31" fill="none" stroke="$($R.accent)" stroke-width="1.1" opacity="0.34"/>
"@
        }
        "edge_diag_down" {
            return @"
    <path d="M-8 14 L50 72 M14 -8 L72 50" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" opacity="0.84"/>
    <path d="M2 2 L62 62" fill="none" stroke="$($R.accent)" stroke-width="1.2" stroke-linecap="square" opacity="0.38"/>
    <path d="M-5 24 L40 69 M24 -5 L69 40" fill="none" stroke="$($R.dim)" stroke-width="7" opacity="0.16"/>
"@
        }
        "edge_diag_up" {
            return @"
    <path d="M-8 50 L50 -8 M14 72 L72 14" fill="none" stroke="$($R.stroke)" stroke-width="2.2" stroke-linecap="square" opacity="0.84"/>
    <path d="M2 62 L62 2" fill="none" stroke="$($R.accent)" stroke-width="1.2" stroke-linecap="square" opacity="0.38"/>
    <path d="M-5 40 L40 -5 M24 69 L69 24" fill="none" stroke="$($R.dim)" stroke-width="7" opacity="0.16"/>
"@
        }
        default {
            return ""
        }
    }
}

function TileBody {
    param([hashtable]$R, [string]$Kind)
    $grid = CommonField -R $R
    if ($Kind -eq "fill") {
        return @"
$grid
$(Motif -R $R -Density "dense")
"@
    }
    return @"
$grid
$(BoundaryPath -R $R -Kind $Kind)
$(Motif -R $R -Density "light")
"@
}

$manifestTiles = @()
foreach ($region in $regionRows) {
    foreach ($kind in $tileKinds) {
        $tileId = "$($region.prefix)_$kind"
        $fileName = "$tileId.svg"
        $inner = TileBody -R $region -Kind $kind
        $svg = TileSvg -R $region -Inner $inner
        Set-Content -LiteralPath (Join-Path $outFullPath $fileName) -Value $svg -Encoding UTF8
        $manifestTiles += [ordered]@{
            id = $tileId
            region_id = $region.id
            label = $region.label
            kind = $kind
            path = "$OutputDir/$fileName"
        }
    }
}

$atlasWidth = $columns * $tileSize
$atlasHeight = $regionRows.Count * $tileSize
$atlasPath = Join-Path $outFullPath "region_frontier_atlas.svg"
$atlasBuilder = [System.Text.StringBuilder]::new()
[void]$atlasBuilder.AppendLine("<svg xmlns=""http://www.w3.org/2000/svg"" width=""$atlasWidth"" height=""$atlasHeight"" viewBox=""0 0 $atlasWidth $atlasHeight"">")
[void]$atlasBuilder.AppendLine("  <defs><clipPath id=""tile_clip""><rect x=""0"" y=""0"" width=""$tileSize"" height=""$tileSize""/></clipPath></defs>")
for ($i = 0; $i -lt $manifestTiles.Count; $i++) {
    $tile = $manifestTiles[$i]
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $tile.path) -Raw
    $match = [regex]::Match($source, '(?s)<svg\b[^>]*>(.*)</svg>\s*$')
    if (-not $match.Success) {
        throw "Cannot find SVG body in $($tile.path)"
    }
    $x = ($i % $columns) * $tileSize
    $y = [Math]::Floor($i / $columns) * $tileSize
    [void]$atlasBuilder.AppendLine("  <g id=""$($tile.id)"" transform=""translate($x $y)"" clip-path=""url(#tile_clip)"">")
    [void]$atlasBuilder.AppendLine($match.Groups[1].Value.Trim())
    [void]$atlasBuilder.AppendLine("  </g>")
}
[void]$atlasBuilder.AppendLine("</svg>")
Set-Content -LiteralPath $atlasPath -Value $atlasBuilder.ToString() -Encoding UTF8

$manifest = [ordered]@{
    tile_size = $tileSize
    columns = $columns
    rows = $regionRows.Count
    output = "$OutputDir/region_frontier_atlas.svg"
    order = $tileKinds
    rows_meaning = $regionRows | ForEach-Object { [ordered]@{ region_id = $_.id; label = $_.label; prefix = $_.prefix } }
    tiles = $manifestTiles
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outFullPath "region_frontier_atlas_manifest.json") -Encoding UTF8

Write-Output "Wrote $atlasPath ($($manifestTiles.Count) tiles, ${columns}x$($regionRows.Count), ${atlasWidth}x${atlasHeight})"
