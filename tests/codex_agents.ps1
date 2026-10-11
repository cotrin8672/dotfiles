$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex agents ' + [guid]::NewGuid())
$sourceRoot = Join-Path $testRoot 'source'
$destination = Join-Path $testRoot 'home'
$configPath = Join-Path $destination '.codex/config.toml'
$testConfig = Join-Path $testRoot 'chezmoi.toml'
$utf8 = New-Object Text.UTF8Encoding($false)
try {
    New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'dot_codex'), (Split-Path $configPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../dot_codex/modify_config.toml') -Destination (Join-Path $sourceRoot 'dot_codex/modify_config.toml')
    [IO.File]::WriteAllText($testConfig, 'mode = "symlink"', $utf8)
    $arguments = @('--config', $testConfig, '--source', $sourceRoot, '--destination', $destination, '--persistent-state', (Join-Path $testRoot 'state.boltdb'), '--no-tty', '--force', 'apply', $configPath)
    $fixtures = @($null, "model = 'keep-me'`n", "[agents]`nmax_threads = 2`ndefault_subagent_model = 'keep-me'`n", "[agents]`nmax_concurrent_threads_per_session = 9`ndefault_subagent_model = 'keep-me'`n")
    foreach ($fixture in $fixtures) {
        if ($null -ne $fixture) { [IO.File]::WriteAllText($configPath, $fixture, $utf8) }
        & rtk proxy chezmoi @arguments
        if ($LASTEXITCODE -ne 0) { throw 'chezmoi apply failed.' }
        $result = [IO.File]::ReadAllText($configPath)
        if ($result -notmatch '(?m)^\s*max_concurrent_threads_per_session\s*=\s*5\s*$' -or $result -match '(?m)^\s*max_threads\s*=') { throw 'The subagent limit was not set to five.' }
        if ($fixture -and $fixture.Contains('keep-me') -and -not $result.Contains('keep-me')) { throw 'An unrelated setting was lost.' }
        & rtk proxy chezmoi @arguments
        if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($configPath) -cne $result) { throw 'Repeated apply must leave the config unchanged.' }
    }
    Write-Output 'PASS: new config, existing settings, legacy limit, current limit, and repeated apply'
} finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolvedTestRoot -Leaf).StartsWith('codex agents ')) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
