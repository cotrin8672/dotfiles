$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('chezmoi-codex-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'source'
$destination = Join-Path $fixture 'home'
$configFile = Join-Path $fixture 'chezmoi.toml'
$target = Join-Path $destination '.codex/config.toml'
$legacySource = Join-Path $source 'dot_codex/config.toml'
$originalPath = $env:PATH
$mistralModels = [ordered]@{
    'codestral-latest' = @{ Context = 256000; Modalities = 'text' }
    'mistral-large-4' = @{ Context = 1048576; Modalities = 'text,image' }
    'deepseek-v4-1-flash-1017' = @{ Context = 1048576; Modalities = 'text,image' }
    'zai-glm-5-3' = @{ Context = 1048576; Modalities = 'text' }
}
$mistralIds = @($mistralModels.Keys | ForEach-Object { "mistral/$_" })

function Invoke-FixtureGit {
    & git -C $source -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.autocrlf=false @args
    if ($LASTEXITCODE -ne 0) { throw 'Fixture git command failed' }
}

function Apply-CodexConfig {
    & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply $target
    if ($LASTEXITCODE -ne 0) { throw 'Codex config apply failed' }
}

function Test-OpenCodexConfig {
    # Every case must produce a local file and be byte-for-byte stable on reapply.
    $content = $null
    foreach ($pass in 1..2) {
        & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply $modelTarget
        if ($LASTEXITCODE -ne 0) { throw 'OpenCodex config apply failed' }
        if ((Get-Item -LiteralPath $modelTarget).LinkType) { throw 'OpenCodex config is still a symlink' }
        $applied = Get-Content -Raw -LiteralPath $modelTarget
        if ($pass -eq 2 -and $applied -cne $content) { throw 'Repeated apply changed the OpenCodex config' }
        $content = $applied
    }
    $config = $content | ConvertFrom-Json
    $provider = $config.providers.mistral
    if ($provider.adapter -cne 'openai-chat' -or $provider.baseUrl -cne 'https://api.mistral.ai/v1' -or $provider.authMode -cne 'key' -or $provider.defaultModel -cne 'codestral-latest') {
        throw 'Mistral connection settings were not managed'
    }
    $expectedModels = $mistralModels.Keys -join ','
    if (($provider.models -join ',') -cne $expectedModels -or ($provider.selectedModels -join ',') -cne $expectedModels) {
        throw 'Mistral must expose and select exactly the four managed models'
    }
    if ($provider.liveModels -isnot [bool] -or $provider.liveModels) { throw 'Mistral live model discovery must be disabled' }
    if ('initialModelSelection' -in $provider.PSObject.Properties.Name) { throw 'Mistral retained an invalid initial model selection marker' }
    if ('reasoningEfforts' -notin $provider.PSObject.Properties.Name -or @($provider.reasoningEfforts).Count -ne 0) { throw 'Mistral reasoning efforts must be explicitly empty' }
    foreach ($model in $mistralModels.Keys) {
        if ($provider.modelContextWindows.$model -ne $mistralModels[$model].Context -or ($provider.modelInputModalities.$model -join ',') -cne $mistralModels[$model].Modalities) {
            throw "Incorrect Mistral context or input modalities for $model"
        }
        $id = "mistral/$model"
        if ($id -in $config.disabledModels -or @($config.modelPickerOrder | Where-Object { $_ -ceq $id }).Count -ne 1) {
            throw "Managed model must be enabled and appear once in the picker: $id"
        }
    }
    return $config
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

    New-Item -ItemType Directory -Path (Join-Path $source 'dot_opencodex'), (Join-Path $source '.chezmoitemplates'), (Join-Path $destination '.opencodex') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository '.chezmoitemplates/opencodex-config.json') -Destination (Join-Path $source '.chezmoitemplates/opencodex-config.json')
    Copy-Item -LiteralPath (Join-Path $repository 'dot_opencodex/modify_private_config.json') -Destination (Join-Path $source 'dot_opencodex/modify_private_config.json')
    $modelTarget = Join-Path $destination '.opencodex/config.json'
    $models = Test-OpenCodexConfig
    $seed = Get-Content -Raw -LiteralPath (Join-Path $source '.chezmoitemplates/opencodex-config.json') | ConvertFrom-Json
    if (($models.modelPickerOrder -join ',') -cne ((@($seed.modelPickerOrder) + $mistralIds) -join ',')) { throw 'Fresh config changed the seeded picker order' }
    if ((Get-Content -Raw -LiteralPath $modelTarget) -match '"(?:api[_-]?key|key|access[_-]?token|refresh[_-]?token|token|password|secret)"\s*:\s*"[^"]+"') {
        throw 'Fresh OpenCodex config contains credentials'
    }
    if ('claude-opus-5-5' -notin $models.providers.'claude-cli'.selectedModels -or 'claude-cli/claude-opus-5-5' -in $models.disabledModels) {
        throw 'Applying the tracked models would hide Claude Opus 5.5'
    }

    # Dummy credentials only: never read the user's destination config.
    $localFixture = @'
{
  "port": 18080,
  "localSetting": "placeholder",
  "localState": { "enabled": false, "values": [3, 1, 2] },
  "providers": {
    "mistral": {
      "apiKey": "fixture-placeholder-key",
      "adapter": "stale-adapter", "baseUrl": "https://old.invalid", "authMode": "oauth",
      "defaultModel": "obsolete", "models": ["obsolete"], "selectedModels": ["obsolete"], "liveModels": true,
      "reasoningEfforts": ["max"],
      "initialModelSelection": { "version": 1, "registrationId": "fixture-registration", "status": "pending", "modelCount": 99 },
      "modelContextWindows": { "codestral-latest": 1, "custom-local-model": 123 },
      "modelInputModalities": { "codestral-latest": ["image"], "custom-local-model": ["audio"] },
      "customHeader": "keep-header"
    },
    "local-other": { "adapter": "openai-chat", "apiKey": "fixture-other-key", "baseUrl": "https://other.invalid/v1", "models": ["keep-model"] }
  },
  "disabledModels": ["mistral/codestral-latest", "local-other/codestral-latest", "mistral/mistral-large-4", "local-other/hidden", "mistral/deepseek-v4-1-flash-1017", "mistral/zai-glm-5-3"],
  "modelPickerOrder": ["local-other/keep-model", "mistral/zai-glm-5-3", "local-other/second-model", "mistral/codestral-latest"]
}
'@
    foreach ($case in @('local', 'legacy')) {
        $destination = Join-Path $fixture "$case-home"
        $modelTarget = Join-Path $destination '.opencodex/config.json'
        New-Item -ItemType Directory -Path (Split-Path $modelTarget) -Force | Out-Null
        $inputConfig = $localFixture | ConvertFrom-Json
        $inputConfig.providers.mistral.apiKey = "fixture-$case-vibe-key"
        $inputConfig.localSetting = "keep-$case"
        $inputJson = $inputConfig | ConvertTo-Json -Depth 20
        if ($case -eq 'legacy') {
            $legacyModelSource = Join-Path $source 'dot_opencodex/private_config.json'
            Set-Content -LiteralPath $legacyModelSource -Value $inputJson -Encoding utf8
            Invoke-FixtureGit add dot_opencodex/private_config.json
            Invoke-FixtureGit commit --quiet -m 'Legacy linked OpenCodex config with dummy local state'
            New-Item -ItemType SymbolicLink -Path $modelTarget -Value $legacyModelSource | Out-Null
            Invoke-FixtureGit rm --quiet dot_opencodex/private_config.json
            Invoke-FixtureGit add .chezmoitemplates/opencodex-config.json dot_opencodex/modify_private_config.json
            Invoke-FixtureGit commit --quiet -m 'Use the OpenCodex config modifier'
            if (Test-Path -LiteralPath $legacyModelSource) { throw 'Legacy OpenCodex source was not removed' }
            if ((Get-Item -LiteralPath $modelTarget).LinkType -ne 'SymbolicLink') { throw 'Legacy fixture must start with a dangling source symlink' }
        } else {
            Set-Content -LiteralPath $modelTarget -Value $inputJson -Encoding utf8
        }
        $models = Test-OpenCodexConfig
        if ($models.providers.mistral.apiKey -cne "fixture-$case-vibe-key") { throw "$case config lost its local Vibe key" }
        if ($models.port -ne 18080 -or $models.localSetting -cne "keep-$case" -or $models.localState.enabled -cne $false -or ($models.localState.values -join ',') -cne '3,1,2') {
            throw "$case config lost unrelated local state"
        }
        if ($models.providers.mistral.customHeader -cne 'keep-header' -or $models.providers.mistral.modelContextWindows.'custom-local-model' -ne 123 -or ($models.providers.mistral.modelInputModalities.'custom-local-model' -join ',') -cne 'audio') {
            throw "$case config lost unrelated Mistral settings"
        }
        $other = $models.providers.'local-other'
        if ($other.adapter -cne 'openai-chat' -or $other.apiKey -cne 'fixture-other-key' -or $other.baseUrl -cne 'https://other.invalid/v1' -or ($other.models -join ',') -cne 'keep-model' -or @($models.providers.PSObject.Properties).Count -ne 2) {
            throw "$case config changed other providers or inherited seed providers"
        }
        if (($models.disabledModels -join ',') -cne 'local-other/codestral-latest,local-other/hidden') { throw "$case config changed unrelated disabled models" }
        if (($models.modelPickerOrder -join ',') -cne 'local-other/keep-model,mistral/zai-glm-5-3,local-other/second-model,mistral/codestral-latest,mistral/mistral-large-4,mistral/deepseek-v4-1-flash-1017') {
            throw "$case config reordered existing picker entries or failed to append missing models"
        }
    }

    # Introduce the sync hook only after a fake ocx is first on this test process's PATH.
    $destination = Join-Path $fixture 'sync-home'
    $modelTarget = Join-Path $destination '.opencodex/config.json'
    $fakeBin = Join-Path $fixture 'bin'
    $fakeOcx = Join-Path $fakeBin 'ocx.cmd'
    $syncLog = Join-Path $fakeBin 'ocx-calls.txt'
    New-Item -ItemType Directory -Path $destination, $fakeBin, (Join-Path $source '.chezmoiscripts') -Force | Out-Null
    Set-Content -LiteralPath $fakeOcx -Encoding ascii -Value @'
@echo off
if not exist "%~dp0..\sync-home\.opencodex\config.json" exit /b 41
findstr /c:"codestral-latest" "%~dp0..\sync-home\.opencodex\config.json" >nul || exit /b 42
echo %*>>"%~dp0ocx-calls.txt"
exit /b 0
'@
    $env:PATH = $fakeBin + [IO.Path]::PathSeparator + $originalPath
    if ((Get-Command ocx).Source -ne $fakeOcx) { throw 'Refusing to run sync without the fixture ocx' }
    Copy-Item -LiteralPath (Join-Path $repository '.chezmoiscripts/run_onchange_after_opencodex-sync.ps1.tmpl') -Destination (Join-Path $source '.chezmoiscripts/run_onchange_after_opencodex-sync.ps1.tmpl')
    $expectedCalls = 'provider snapshot --json,provider edit mistral --live-models off,sync'
    foreach ($pass in 1..2) {
        & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply
        if ($LASTEXITCODE -ne 0) { throw 'Fixture apply with the OpenCodex sync hook failed' }
        $calls = @(Get-Content -LiteralPath $syncLog)
        if (($calls -join ',') -cne $expectedCalls) { throw 'Live reload and sync must follow config creation and skip an unchanged repeat apply' }
    }
    # A stopped proxy needs only disk/catalog sync; the next startup reads the config.
    $fakeCommand = Get-Content -Raw -LiteralPath $fakeOcx
    $fakeCommand = $fakeCommand.Replace('exit /b 0', 'if "%1 %2"=="provider snapshot" exit /b 1' + "`r`n" + 'exit /b 0')
    Set-Content -LiteralPath $fakeOcx -Value $fakeCommand -Encoding ascii
    Add-Content -LiteralPath (Join-Path $source '.chezmoiscripts/run_onchange_after_opencodex-sync.ps1.tmpl') -Value '# Changed fixture hook' -Encoding utf8
    & chezmoi --source $source --destination $destination --config $configFile --persistent-state (Join-Path $fixture 'state.boltdb') --force apply
    if ($LASTEXITCODE -ne 0) { throw 'Sync failed when the proxy was stopped' }
    if (((Get-Content -LiteralPath $syncLog) -join ',') -cne ($expectedCalls + ',provider snapshot --json,sync')) { throw 'A stopped proxy must skip live reload and still sync the catalog' }
    Write-Output 'CHEZMOI_CODEX_PORTABILITY_OK'
} finally {
    $env:PATH = $originalPath
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolvedFixture -Leaf) -notlike 'chezmoi-codex-*') {
        throw 'Refusing to remove an unexpected fixture directory'
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
