$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex code search ' + [guid]::NewGuid())
$global:codeSearchSetupTest = @{ Calls = [Collections.Generic.List[object]]::new(); FailureTool = ''; AstRoot = '' }

function Assert-Setup($condition, $message) {
    if (-not $condition) { throw $message }
}

function rtk {
    $global:codeSearchSetupTest.Calls.Add(@($args))
    $global:LASTEXITCODE = 0
    if ($args[1] -eq $global:codeSearchSetupTest.FailureTool) { $global:LASTEXITCODE = 27; return }
    if ($args[1] -eq 'ghq' -and $args[2] -eq 'list') { return $global:codeSearchSetupTest.AstRoot }
}

try {
    $codexRoot = Join-Path $testRoot '.codex'
    $global:codeSearchSetupTest.AstRoot = Join-Path $testRoot 'ghq checkout'
    $manifest = Join-Path $global:codeSearchSetupTest.AstRoot 'plugin/.codex-plugin/plugin.json'
    New-Item -ItemType Directory -Path $codexRoot, (Split-Path $manifest), (Join-Path $global:codeSearchSetupTest.AstRoot '.agents/plugins'), (Join-Path $global:codeSearchSetupTest.AstRoot 'plugin/skills/ast-index'), (Join-Path $global:codeSearchSetupTest.AstRoot 'plugin/hooks') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.AstRoot '.agents/plugins/marketplace.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.AstRoot 'plugin/skills/ast-index/SKILL.md') -Value 'upstream skill'
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.AstRoot 'plugin/hooks/hooks.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.AstRoot 'LICENSE') -Value 'upstream license'
    Set-Content -LiteralPath $manifest -Value '{"version":"3.56.0"}'
    $installer = Join-Path $codexRoot 'install-code-search.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../dot_codex/install-code-search.ps1') -Destination $installer

    & $installer | Out-Null
    $registrations = @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' })
    Assert-Setup ($registrations.Count -eq 4) 'Both marketplaces and plugins must be registered.'
    Assert-Setup ($registrations[0][5] -eq (Join-Path $codexRoot 'plugin-sources/codixing-local')) 'Codixing must use its deployed path, including spaces.'
    $astDeployed = Join-Path $codexRoot 'plugin-sources/ast-index-plugins'
    Assert-Setup ($registrations[2][5] -eq $astDeployed) 'ast-index must use its deployed path, including spaces.'
    Assert-Setup (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/skills/ast-index/SKILL.md')) 'The upstream skill must be copied.'
    Assert-Setup (-not (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/hooks'))) 'Claude hooks must not be included.'
    & $installer | Out-Null
    Assert-Setup (-not (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/skills/ast-index/ast-index'))) 'Repeated setup must not nest skill directories.'

    $global:codeSearchSetupTest.Calls.Clear()
    $global:codeSearchSetupTest.FailureTool = 'mise'
    $failed = $false
    try { & $installer | Out-Null } catch { $failed = $_.Exception.Message -match 'exit 27' }
    Assert-Setup $failed 'A failed native installer must stop setup.'
    Assert-Setup (-not @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' -or $_[1] -eq 'ghq' }).Count) 'Failed installation must not register plugins.'

    $global:codeSearchSetupTest.Calls.Clear()
    $global:codeSearchSetupTest.FailureTool = ''
    Set-Content -LiteralPath $manifest -Value '{"version":"99.0.0"}'
    $failed = $false
    try { & $installer | Out-Null } catch { $failed = $_.Exception.Message -match 'not v3.56.0' }
    Assert-Setup $failed 'A different shared checkout must be rejected without changing it.'
    Assert-Setup (-not @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' }).Count) 'A mismatched plugin must not be registered.'
    Write-Output 'PASS: paths with spaces, repeat setup, Codex-only package, native failure, and version guard'
} finally {
    Remove-Item Function:rtk -ErrorAction SilentlyContinue
    Remove-Variable codeSearchSetupTest -Scope Global
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolvedTestRoot -Leaf).StartsWith('codex code search ')) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
