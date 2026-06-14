param(
    [string]$ManifestPath = "Resources/art/map/frontier_tiles/frontier_routes_atlas_manifest.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path ".").Path
$manifestFullPath = Join-Path $repoRoot $ManifestPath
$manifest = Get-Content -LiteralPath $manifestFullPath -Raw | ConvertFrom-Json
$tileSize = [int]$manifest.tile_size
$columns = [int]$manifest.columns
$tiles = @($manifest.tiles)
$rows = [Math]::Ceiling($tiles.Count / [double]$columns)
$width = $columns * $tileSize
$height = [int]$rows * $tileSize
$outputPath = Join-Path $repoRoot ([string]$manifest.output)

function Get-SvgInnerContent {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($raw, '(?s)<svg\b[^>]*>(.*)</svg>\s*$')
    if (-not $match.Success) {
        throw "Cannot find SVG body in $Path"
    }
    return $match.Groups[1].Value.Trim()
}

$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine("<svg xmlns=""http://www.w3.org/2000/svg"" width=""$width"" height=""$height"" viewBox=""0 0 $width $height"">")
[void]$builder.AppendLine("  <defs>")
[void]$builder.AppendLine("    <clipPath id=""tile_clip""><rect x=""0"" y=""0"" width=""$tileSize"" height=""$tileSize""/></clipPath>")
[void]$builder.AppendLine("  </defs>")

for ($index = 0; $index -lt $tiles.Count; $index++) {
    $tile = $tiles[$index]
    $sourcePath = Join-Path $repoRoot ([string]$tile.path)
    $inner = Get-SvgInnerContent -Path $sourcePath
    $x = ($index % $columns) * $tileSize
    $y = [Math]::Floor($index / $columns) * $tileSize
    $tileId = [string]$tile.id
    [void]$builder.AppendLine("  <g id=""$tileId"" transform=""translate($x $y)"" clip-path=""url(#tile_clip)"">")
    [void]$builder.AppendLine($inner)
    [void]$builder.AppendLine("  </g>")
}

[void]$builder.AppendLine("</svg>")
Set-Content -LiteralPath $outputPath -Value $builder.ToString() -Encoding UTF8
Write-Output "Wrote $outputPath ($($tiles.Count) tiles, ${columns}x${rows}, ${width}x${height})"
