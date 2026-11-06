$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('chezmoi-codex-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'source'
$destination = Join-Path $fixture 'home'
$configFile = Join-Path $fixture 'chezmoi.toml'
$target = Join-Path $destination '.codex/config.toml'
$legacySource = Join-Path $source 'dot_codex/config.toml'

function Invoke-FixtureGit {
    & git -C $source -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.autocrlf=false @args
    if ($LASTEXITCODE -ne 0) { throw 'Fixture git command failed' }
}

function Apply-CodexConfig {
    & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply $target
    if ($LASTEXITCODE -ne 0) { throw 'Codex config apply failed' }
}

try {
    New-Item -ItemType Directory -Path (Split-Path $legacySource), (Split-Path $target) -Force | Out-Null
    Set-Content -LiteralPath $configFile -Value 'mode = "symlink"' -Encoding utf8
    Set-Content -LiteralPath $legacySource -Value 'local_setting = "preserve-me"' -Encoding utf8
    Invoke-FixtureGit init --quiet
    Invoke-FixtureGit add dot_codex/config.toml
    Invoke-FixtureGit commit --quiet -m 'Legacy linked Codex config'
    New-Item -ItemType SymbolicLink -Path $target -Value $legacySource | Out-Null

    # Reproduce another PC pulling the commit that removes the old source file.
    Invoke-FixtureGit rm --quiet dot_codex/config.toml
    New-Item -ItemType Directory -Path (Join-Path $source 'dot_codex') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'dot_codex/modify_config.toml') -Destination (Join-Path $source 'dot_codex/modify_config.toml')
    Invoke-FixtureGit add dot_codex/modify_config.toml
    Invoke-FixtureGit commit --quiet -m 'Use the portable config modifier'

    Apply-CodexConfig
    if ((Get-Item -LiteralPath $target).LinkType) { throw 'Legacy link was not replaced with a local file' }
    $content = Get-Content -Raw -LiteralPath $target
    if ($content -notmatch 'local_setting\s*=\s*"preserve-me"') { throw 'Legacy machine-local settings were lost after pull' }
    Apply-CodexConfig
    if ((Get-Content -Raw -LiteralPath $target) -ne $content) { throw 'Repeated apply changed an already migrated config' }

    $destination = Join-Path $fixture 'fresh-home'
    $target = Join-Path $destination '.codex/config.toml'
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    Apply-CodexConfig
    $freshContent = Get-Content -Raw -LiteralPath $target
    if ($freshContent -match 'local_setting') { throw 'Fresh PCs inherited another machine''s settings' }
    if ($freshContent -notmatch 'model_catalog_json\s*=') { throw 'Fresh config has no OpenCodex catalog binding' }

    New-Item -ItemType Directory -Path (Join-Path $source 'dot_opencodex'), (Join-Path $destination '.opencodex') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'dot_opencodex/private_config.json') -Destination (Join-Path $source 'dot_opencodex/private_config.json')
    $modelTarget = Join-Path $destination '.opencodex/config.json'
    & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply $modelTarget
    if ($LASTEXITCODE -ne 0) { throw 'Fresh PC model config apply failed' }
    $models = Get-Content -Raw -LiteralPath $modelTarget | ConvertFrom-Json
    if ('claude-opus-5-5' -notin $models.providers.'claude-cli'.selectedModels -or 'claude-cli/claude-opus-5-5' -in $models.disabledModels) {
        throw 'Applying the tracked models would hide Claude Opus 5.5'
    }
    Write-Output 'CHEZMOI_CODEX_PORTABILITY_OK'
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolvedFixture -Leaf) -notlike 'chezmoi-codex-*') {
        throw 'Refusing to remove an unexpected fixture directory'
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
