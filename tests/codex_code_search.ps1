$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex code search ' + [guid]::NewGuid())
$originalLocalAppData = $env:LOCALAPPDATA
$global:codeSearchSetupTest = @{ Calls = [Collections.Generic.List[object]]::new(); FailureTool = ''; AstRoot = ''; LanguageRoot = '' }

function Assert-Setup($condition, $message) {
    if (-not $condition) { throw $message }
}

function rtk {
    $global:codeSearchSetupTest.Calls.Add(@($args))
    $global:LASTEXITCODE = 0
    if ($args[1] -eq $global:codeSearchSetupTest.FailureTool) { $global:LASTEXITCODE = 27; return }
    if ($args[1] -eq 'ghq' -and $args[2] -eq 'list') {
        if ($args[-1] -match 'isaacphi') { return $global:codeSearchSetupTest.LanguageRoot }
        return $global:codeSearchSetupTest.AstRoot
    }
    if ($args[1] -eq 'git' -and $args[4] -eq 'archive') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory($global:codeSearchSetupTest.LanguageRoot, $args[6].Substring('--output='.Length))
    }
    if ($args[1] -eq 'mise' -and $args -contains 'build') {
        $outputIndex = [array]::IndexOf($args, '-o') + 1
        Set-Content -LiteralPath $args[$outputIndex] -Value 'compiled binary'
    }
}

try {
    $codexRoot = Join-Path $testRoot '.codex'
    $env:LOCALAPPDATA = Join-Path $testRoot 'AppData/Local'
    $mason = Join-Path $env:LOCALAPPDATA 'nvim-data/mason/packages'
    foreach ($server in @('rust-analyzer/rust-analyzer.exe', 'typescript-language-server/node_modules/typescript-language-server/lib/cli.mjs')) {
        $serverPath = Join-Path $mason $server
        New-Item -ItemType Directory -Path (Split-Path $serverPath) -Force | Out-Null
        Set-Content -LiteralPath $serverPath -Value 'Mason server'
    }
    $global:codeSearchSetupTest.LanguageRoot = Join-Path $testRoot 'language server checkout'
    New-Item -ItemType Directory -Path $global:codeSearchSetupTest.LanguageRoot, (Join-Path $codexRoot 'language-server') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.LanguageRoot 'LICENSE') -Value 'license'
    Set-Content -LiteralPath (Join-Path $global:codeSearchSetupTest.LanguageRoot 'ATTRIBUTION') -Value 'attribution'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../dot_codex/language-server/windows.patch') -Destination (Join-Path $codexRoot 'language-server/windows.patch')
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
    foreach ($call in @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'mise' -and $_[2] -eq 'exec' })) {
        Assert-Setup ($call -contains '--') 'PowerShell must preserve the mise command separator.'
    }
    $registrations = @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' })
    Assert-Setup ($registrations.Count -eq 5) 'Both marketplaces and all three plugins must be registered.'
    Assert-Setup ($registrations[0][5] -eq (Join-Path $codexRoot 'plugin-sources/codixing-local')) 'Codixing must use its deployed path, including spaces.'
    $astDeployed = Join-Path $codexRoot 'plugin-sources/ast-index-plugins'
    Assert-Setup ($registrations[3][5] -eq $astDeployed) 'ast-index must use its deployed path, including spaces.'
    Assert-Setup ($registrations[2][4] -eq 'mcp-language-server@codixing-local') 'MCP Language Server must be installed.'
    Assert-Setup (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/skills/ast-index/SKILL.md')) 'The upstream skill must be copied.'
    Assert-Setup (-not (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/hooks'))) 'Claude hooks must not be included.'
    $global:codeSearchSetupTest.Calls.Clear()
    & $installer | Out-Null
    Assert-Setup (-not (Test-Path -LiteralPath (Join-Path $astDeployed 'plugin/skills/ast-index/ast-index'))) 'Repeated setup must not nest skill directories.'
    Assert-Setup (-not @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'git' -and $_[4] -eq 'archive' }).Count) 'Repeated setup must reuse the binary for the same patch.'

    $global:codeSearchSetupTest.Calls.Clear()
    Remove-Item -LiteralPath $serverPath -Force
    $failed = $false
    try { & $installer | Out-Null } catch { $failed = $_.Exception.Message -match 'Mason language server not found' }
    Assert-Setup $failed 'A missing Mason server must stop setup with a clear error.'
    Assert-Setup (-not @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' }).Count) 'A missing language server must not register plugins.'
    Set-Content -LiteralPath $serverPath -Value 'Mason server'

    $global:codeSearchSetupTest.Calls.Clear()
    $global:codeSearchSetupTest.FailureTool = 'git'
    Add-Content -LiteralPath (Join-Path $codexRoot 'language-server/windows.patch') -Value '# changed patch'
    $failed = $false
    try { & $installer | Out-Null } catch { $failed = $_.Exception.Message -match 'exit 27' }
    Assert-Setup $failed 'A failed language server build must stop setup.'
    Assert-Setup (-not @($global:codeSearchSetupTest.Calls | Where-Object { $_[1] -eq 'codex' }).Count) 'A failed build must not register plugins.'

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
    Write-Output 'PASS: paths with spaces, repeat setup, Codex-only package, pinned language server build, native failure, and version guard'
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Item Function:rtk -ErrorAction SilentlyContinue
    Remove-Variable codeSearchSetupTest -Scope Global
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolvedTestRoot -Leaf).StartsWith('codex code search ')) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
