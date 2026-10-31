$ErrorActionPreference = 'Stop'
$fixtureId = [Guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('zebar-quota-test-' + $fixtureId)
[void][IO.Directory]::CreateDirectory($fixtureRoot)
$client = $null
$quotaMutex = $null
$ownsMutex = $false

function Assert-Quota([bool]$Condition, [string]$Message) { if (!$Condition) { throw $Message } }
function New-FixtureTask([int]$Status = 200, [bool]$Fault = $false) {
    $response = [Net.Http.HttpResponseMessage]::new([Enum]::ToObject([Net.HttpStatusCode], $Status))
    $response.Content = New-Object Net.Http.StringContent('{"five_hour":{"utilization":20,"resets_at":"2099-01-01T00:00:00Z"},"seven_day":{"utilization":30,"resets_at":"2099-01-07T00:00:00Z"}}')
    if ($Status -eq 429) { $response.Headers.RetryAfter = New-Object Net.Http.Headers.RetryConditionHeaderValue([TimeSpan]::FromHours(1)) }
    $task = [pscustomobject]@{ IsCompleted = $true; Response = $response; Fault = $Fault }
    $task | Add-Member ScriptMethod GetAwaiter { return $this }
    $task | Add-Member ScriptMethod GetResult { if ($this.Fault) { $this.Response.Dispose(); throw 'Fixture network failure' }; return $this.Response }
    return $task
}
function Reset-Fixture([bool]$AuthFailed = $true, [string]$StoredAccess = 'fixture-old') {
    $script:FixtureAccess = 'fixture-new'
    foreach ($request in $script:FixtureRequests) { if ($request) { $request.Dispose() } }
    $script:FixtureRequests = New-Object 'Collections.Generic.List[object]'
    $script:QuotaState = @{}
    $script:CacheStamps = @{}
    $script:LastQuotaJson = $null
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $script:QuotaState.claude = @{
        view = @{ status = 'stale'; plan = 'max'; windows = @(@{id='5h';label='5h';usedPercent=90;resetsAt='2099-01-01T00:00:00Z'}); updatedAt = '2000-01-01T00:00:00Z'; message = 'Usage refresh returned HTTP 401' }
        at = $now - 3600000; next = $now + 1800000; failures = 3; authFailed = $AuthFailed
        key = 'fixture-account'; identity = @{ access=$StoredAccess;key='fixture-account';account='fixture-account';plan='max';endpoint='https://example.invalid/usage' }
        identityCheck = 0L; task = $null
    }
}

try {
    $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\dot_glzr\zebar\pastel-bar\quota.ps1.tmpl'))
    $source = $source.Replace('Local\ZebarPastelQuota-v1', ('Local\ZebarQuotaTest-' + $fixtureId))
    $fixtureScript = Join-Path $fixtureRoot 'quota.ps1'
    [IO.File]::WriteAllText($fixtureScript, $source)
    . $fixtureScript
    $quotaMutex = $script:QuotaMutex
    $ownsMutex = $script:QuotaLeader
    Assert-Quota $ownsMutex 'Isolated test must own its mutex'
    $script:UsageHttp.Dispose()
    $script:ProxyHome = Join-Path $fixtureRoot 'proxy'
    $script:QuotaFile = Join-Path $fixtureRoot 'data\ai-cache.json'
    function Read-UsageIdentity([string]$Provider) {
        if ($Provider -eq 'codex') { return $null }
        return @{ access=$script:FixtureAccess;key='fixture-account';account='fixture-account';plan='max';endpoint='https://example.invalid/usage' }
    }
    $client = New-Object PSObject
    $client | Add-Member ScriptMethod SendAsync {
        param($Request)
        $script:FixtureRequests.Add($Request)
        return (New-FixtureTask)
    }
    $script:UsageHttp = $client

    Reset-Fixture -AuthFailed $false
    $script:FixtureAccess = 'fixture-old'
    $script:QuotaState.claude.task = New-FixtureTask -Status 401
    $script:QuotaState.claude.requestKey = 'fixture-account'
    $script:QuotaState.claude.requestAccess = 'fixture-old'
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:QuotaState.claude.authFailed -and $script:QuotaState.claude.failures -eq 4) 'A current-token 401 must record an authentication failure'
    $script:FixtureAccess = 'fixture-new'
    $script:QuotaState.claude.identityCheck = 0L
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 1) 'New credentials must bypass prior 401 backoff'
    Assert-Quota ($script:FixtureRequests[0].Headers.Authorization.Parameter -ceq 'fixture-new') 'Retry must use current credentials'
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:QuotaState.claude.view.status -eq 'ok') 'Successful retry must restore normal display'
    Assert-Quota ($script:QuotaState.claude.failures -eq 0) 'Successful retry must clear failures'
    Assert-Quota (!$script:QuotaState.claude.task) 'Successful response must be consumed'
    Assert-Quota (![IO.File]::ReadAllText($script:QuotaFile).Contains('fixture-new')) 'Credentials must never reach display cache'
    Write-Output 'PASS new credential recovers from 401 without login or credential writes'

    Reset-Fixture -StoredAccess 'fixture-new'
    $originalNext = $script:QuotaState.claude.next
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 0 -and $script:QuotaState.claude.next -eq $originalNext) 'Unchanged rejected credentials must retain backoff'
    Write-Output 'PASS unchanged credentials do not cause repeated requests'

    Reset-Fixture -AuthFailed $false
    $originalNext = $script:QuotaState.claude.next
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 0 -and $script:QuotaState.claude.next -eq $originalNext) 'Token renewal must not bypass existing rate-limit backoff'
    Write-Output 'PASS rate-limit backoff survives credential rotation'

    foreach ($fault in @($false, $true)) {
        Reset-Fixture -AuthFailed $false
        $script:QuotaState.claude.task = New-FixtureTask -Status 401 -Fault $fault
        $script:QuotaState.claude.requestKey = 'fixture-account'
        $script:QuotaState.claude.requestAccess = 'fixture-old'
        [void](Get-UsageSnapshot)
        Assert-Quota ($script:FixtureRequests.Count -eq 1) 'Old in-flight auth/network failures must retry current credentials immediately'
        Assert-Quota ($script:QuotaState.claude.failures -eq 0) 'Old in-flight failures must not restore backoff'
        [void](Get-UsageSnapshot)
        Assert-Quota ($script:QuotaState.claude.view.status -eq 'ok') 'Current response must recover after old in-flight failure'
    }
    Write-Output 'PASS old in-flight auth and network failures cannot poison renewed credentials'

    Reset-Fixture -AuthFailed $false
    $script:QuotaState.claude.task = New-FixtureTask -Status 429
    $script:QuotaState.claude.requestKey = 'fixture-account'
    $script:QuotaState.claude.requestAccess = 'fixture-old'
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 0) 'Same-account in-flight 429 must not be retried immediately'
    Assert-Quota ($script:QuotaState.claude.next -ge [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 3500000) 'Retry-After must be respected after token renewal'
    Write-Output 'PASS in-flight 429 retains Retry-After'
} finally {
    foreach ($request in $script:FixtureRequests) { if ($request) { $request.Dispose() } }
    if ($ownsMutex -and $quotaMutex) { $quotaMutex.ReleaseMutex() }
    if ($quotaMutex) { $quotaMutex.Dispose() }
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -ne ('zebar-quota-test-' + $fixtureId)) { throw 'Refusing to remove an unexpected test directory' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
