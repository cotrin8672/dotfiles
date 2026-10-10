$ErrorActionPreference = 'Stop'

function Invoke-CodeSearchSetup {
    & rtk proxy @args
    if ($LASTEXITCODE -ne 0) { throw "Code search setup failed: $($args[0]) $($args[1]) (exit $LASTEXITCODE)" }
}

# Resolve the managed files before registering their stable home-directory path.
$marketplace = Join-Path $PSScriptRoot 'plugin-sources/codixing-local'
$languageFiles = Join-Path $PSScriptRoot 'language-server'
Invoke-CodeSearchSetup chezmoi apply --parent-dirs (Join-Path $HOME '.config/mise/config.toml') $marketplace $languageFiles
Invoke-CodeSearchSetup mise install codixing codixing-mcp ast-index
Invoke-CodeSearchSetup mise which codixing
Invoke-CodeSearchSetup mise which codixing-mcp
Invoke-CodeSearchSetup mise which ast-index
Invoke-CodeSearchSetup mise reshim

# ghq preserves an existing checkout; a new checkout starts at the tested release.
Invoke-CodeSearchSetup ghq get --branch v3.56.0 defendend/Claude-ast-index-search
$astRepository = Invoke-CodeSearchSetup ghq list --full-path --exact github.com/defendend/Claude-ast-index-search
if (-not $astRepository -or -not (Test-Path -LiteralPath (Join-Path $astRepository '.agents/plugins/marketplace.json'))) {
    throw 'The ast-index marketplace was not found in the ghq checkout.'
}
$astManifest = Get-Content -LiteralPath (Join-Path $astRepository 'plugin/.codex-plugin/plugin.json') -Raw | ConvertFrom-Json
if ($astManifest.version -ne '3.56.0') {
    throw 'The ghq ast-index plugin is not v3.56.0. Review its checkout and the mise version before installing.'
}

# Codex auto-discovers Claude's bash hooks and commands unless they are omitted.
$astMarketplace = Join-Path $PSScriptRoot 'plugin-sources/ast-index-plugins'
$astPlugin = Join-Path $astMarketplace 'plugin'
New-Item -ItemType Directory -Path (Join-Path $astMarketplace '.agents/plugins'), (Join-Path $astPlugin '.codex-plugin'), (Join-Path $astPlugin 'skills') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $astRepository '.agents/plugins/marketplace.json') -Destination (Join-Path $astMarketplace '.agents/plugins/marketplace.json') -Force
Copy-Item -LiteralPath (Join-Path $astRepository 'plugin/.codex-plugin/plugin.json') -Destination (Join-Path $astPlugin '.codex-plugin/plugin.json') -Force
Copy-Item -LiteralPath (Join-Path $astRepository 'plugin/skills/ast-index') -Destination (Join-Path $astPlugin 'skills') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $astRepository 'LICENSE') -Destination (Join-Path $astPlugin 'LICENSE') -Force

# Reuse Mason's servers; do not install a second copy or change Neovim settings.
$mason = Join-Path $env:LOCALAPPDATA 'nvim-data/mason/packages'
foreach ($server in @('rust-analyzer/rust-analyzer.exe', 'typescript-language-server/node_modules/typescript-language-server/lib/cli.mjs')) {
    if (-not (Test-Path -LiteralPath (Join-Path $mason $server))) {
        throw "Mason language server not found: $server. Install rust-analyzer and typescript-language-server in Neovim first."
    }
}
Invoke-CodeSearchSetup mise install go@1.27.1 npm:typescript@5.9.2
Invoke-CodeSearchSetup mise exec rust '--' rustup component add rust-src
Invoke-CodeSearchSetup ghq get --branch v0.1.1 isaacphi/mcp-language-server
$languageRepository = Invoke-CodeSearchSetup ghq list --full-path --exact github.com/isaacphi/mcp-language-server
if (-not $languageRepository) { throw 'The mcp-language-server ghq checkout was not found.' }

# Build from an immutable archive, leaving the shared ghq checkout untouched.
$languageInstall = Join-Path (Split-Path $PSScriptRoot -Parent) '.local/share/codex-language-server/0.1.1-codex.1'
$languageBinary = Join-Path $languageInstall 'mcp-language-server.exe'
$patch = Join-Path $languageFiles 'windows.patch'
$patchHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($patch)))
$stamp = Join-Path $languageInstall 'windows-patch.sha256'
if (-not (Test-Path -LiteralPath $languageBinary) -or -not (Test-Path -LiteralPath $stamp) -or (Get-Content -LiteralPath $stamp -Raw).Trim() -ne $patchHash) {
    $buildRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex lsp build ' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
    try {
        $archive = Join-Path $buildRoot 'source.zip'
        $buildSource = Join-Path $buildRoot 'source'
        Invoke-CodeSearchSetup git -C $languageRepository archive --format=zip "--output=$archive" 46e2950b7969334780675e7797e13f140d2d42ac
        Expand-Archive -LiteralPath $archive -DestinationPath $buildSource
        Invoke-CodeSearchSetup git -C $buildSource apply $patch
        Invoke-CodeSearchSetup mise exec go@1.27.1 '--' go -C $buildSource test ./internal/...
        Invoke-CodeSearchSetup mise exec go@1.27.1 '--' go -C $buildSource build -trimpath -o (Join-Path $buildRoot 'mcp-language-server.exe') .
        New-Item -ItemType Directory -Path $languageInstall -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $buildRoot 'mcp-language-server.exe'), (Join-Path $buildSource 'LICENSE'), (Join-Path $buildSource 'ATTRIBUTION') -Destination $languageInstall -Force
        Set-Content -LiteralPath $stamp -Value $patchHash -Encoding ASCII
    } finally {
        $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if ($resolvedBuildRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolvedBuildRoot -Leaf).StartsWith('codex lsp build ') -and -not ((Get-Item -LiteralPath $resolvedBuildRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
        }
    }
}

Invoke-CodeSearchSetup codex plugin marketplace add $marketplace --json
Invoke-CodeSearchSetup codex plugin add codixing@codixing-local --json
Invoke-CodeSearchSetup codex plugin add mcp-language-server@codixing-local --json
Invoke-CodeSearchSetup codex plugin marketplace add $astMarketplace --json
Invoke-CodeSearchSetup codex plugin add ast-index@ast-index-plugins --json
Write-Output 'Codixing, ast-index, and MCP Language Server are installed for this user. Restart Codex to load the plugins.'
