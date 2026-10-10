$ErrorActionPreference = 'Stop'

function Invoke-CodeSearchSetup {
    & rtk proxy @args
    if ($LASTEXITCODE -ne 0) { throw "Code search setup failed: $($args[0]) $($args[1]) (exit $LASTEXITCODE)" }
}

# Resolve the managed files before registering their stable home-directory path.
$marketplace = Join-Path $PSScriptRoot 'plugin-sources/codixing-local'
Invoke-CodeSearchSetup chezmoi apply --parent-dirs (Join-Path $HOME '.config/mise/config.toml') $marketplace
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

Invoke-CodeSearchSetup codex plugin marketplace add $marketplace --json
Invoke-CodeSearchSetup codex plugin add codixing@codixing-local --json
Invoke-CodeSearchSetup codex plugin marketplace add $astMarketplace --json
Invoke-CodeSearchSetup codex plugin add ast-index@ast-index-plugins --json
Write-Output 'Codixing and ast-index are installed for this user. Restart Codex to load the plugins and mise shims.'
