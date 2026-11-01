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
    $response.Content = New-Object Net.Http.StringContent($script:FixtureBody)
    if ($Status -eq 429) { $response.Headers.RetryAfter = New-Object Net.Http.Headers.RetryConditionHeaderValue([TimeSpan]::FromHours(1)) }
    $task = [pscustomobject]@{ IsCompleted = $true; Response = $response; Fault = $Fault }
    $task | Add-Member ScriptMethod GetAwaiter { return $this }
    $task | Add-Member ScriptMethod GetResult { if ($this.Fault) { $this.Response.Dispose(); throw 'Fixture network failure' }; return $this.Response }
    return $task
}
function Reset-Fixture([bool]$AuthFailed = $true, [string]$StoredAccess = 'fixture-old') {
    $script:FixtureAccess = 'fixture-new'
    $script:FixtureExpiresAt = $null
    $script:FixtureCanRefresh = $false
    $script:FixtureHasIdentity = $true
    $script:FixtureBody = '{"five_hour":{"utilization":20,"resets_at":"2099-01-01T00:00:00Z"},"seven_day":{"utilization":30,"resets_at":"2099-01-07T00:00:00Z"}}'
    $script:FixtureRefreshStarts = 0
    $script:FixtureRefreshProcess = [pscustomobject]@{ HasExited = $false; KillCount = 0; DisposeCount = 0 }
    $script:FixtureRefreshProcess | Add-Member ScriptMethod Kill { $this.KillCount++; $this.HasExited = $true }
    $script:FixtureRefreshProcess | Add-Member ScriptMethod Dispose { $this.DisposeCount++ }
    foreach ($request in $script:FixtureRequests) { if ($request) { $request.Dispose() } }
    $script:FixtureRequests = New-Object 'Collections.Generic.List[object]'
    $script:QuotaState = @{}
    $script:CacheStamps = @{}
    $script:LastQuotaJson = $null
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $script:QuotaState.claude = @{
        view = @{ status = 'stale'; plan = 'max'; windows = @(@{id='5h';label='5h';usedPercent=90;resetsAt='2099-01-01T00:00:00Z'}); updatedAt = '2000-01-01T00:00:00Z'; message = 'Usage refresh returned HTTP 401' }
        at = $now - 3600000; next = $now + 1800000; failures = 3; authFailed = $AuthFailed
        key = 'fixture-account'; identity = @{ access=$StoredAccess;key='fixture-account';account='fixture-account';plan='max';endpoint='https://example.invalid/usage';expiresAt=$null;canRefresh=$false }
        identityCheck = 0L; task = $null
        refresh = $null; refreshStarted = 0L; refreshNext = 0L
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
        if ($Provider -eq 'codex' -or !$script:FixtureHasIdentity) { return $null }
        return @{ access=$script:FixtureAccess;key='fixture-account';account='fixture-account';plan='max';endpoint='https://example.invalid/usage';expiresAt=$script:FixtureExpiresAt;canRefresh=$script:FixtureCanRefresh }
    }
    function Start-ClaudeCredentialRefresh {
        $script:FixtureRefreshStarts++
        return $script:FixtureRefreshProcess
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

    Reset-Fixture
    $script:FixtureAccess = 'fixture-old'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    $script:FixtureCanRefresh = $true
    $state = $script:QuotaState.claude
    $state.next = 0L
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRefreshStarts -eq 1 -and $state.refresh -eq $script:FixtureRefreshProcess) 'Expired credentials must launch the native owner once'
    for ($tick = 0; $tick -lt 3; $tick++) {
        $state.next = 0L
        [void](Get-UsageSnapshot)
    }
    Assert-Quota ($script:FixtureRefreshStarts -eq 1) 'An active refresh must not launch duplicate owners'
    Assert-Quota ($script:FixtureRequests.Count -eq 0) 'An active refresh must suppress usage requests with the expired token'
    $state.next = [DateTimeOffset]::UtcNow.AddMinutes(30).ToUnixTimeMilliseconds()
    $state.identityCheck = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeMilliseconds()
    $script:FixtureAccess = 'fixture-renewed'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddHours(8).ToString('o')
    $script:FixtureRefreshProcess.HasExited = $true
    [void](Get-UsageSnapshot)
    Assert-Quota (!$state.refresh -and $script:FixtureRefreshProcess.DisposeCount -eq 1 -and $script:FixtureRefreshProcess.KillCount -eq 0) 'A completed owner must be disposed without being killed'
    Assert-Quota ($script:FixtureRequests.Count -eq 1) 'Owner completion must reread canonical credentials and bypass prior 401 backoff'
    Assert-Quota ($script:FixtureRequests[0].Headers.Authorization.Parameter -ceq 'fixture-renewed') 'Usage retry must use the token renewed by the owner'
    [void](Get-UsageSnapshot)
    Assert-Quota ($state.view.status -eq 'ok' -and $state.failures -eq 0 -and !$state.authFailed) 'Owner renewal must restore fresh quota and clear authentication failures'
    Assert-Quota ($script:FixtureRefreshStarts -eq 1 -and $script:FixtureRequests.Count -eq 1 -and !$state.task) 'Successful recovery must settle without repeated owners or requests'
    Assert-Quota (![IO.File]::ReadAllText($script:QuotaFile).Contains('fixture-renewed')) 'Renewed credentials must never reach the display cache'
    Write-Output 'PASS expired credentials renew through one native owner and recover quota'

    Reset-Fixture -StoredAccess 'fixture-old'
    $script:FixtureAccess = 'fixture-old'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    $script:FixtureCanRefresh = $true
    $state = $script:QuotaState.claude
    $startedBefore = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [void](Get-UsageSnapshot)
    Assert-Quota ($state.refresh -and $state.refreshNext -ge $startedBefore + 300000) 'Owner launch must reserve a five-minute retry interval'
    $retryAt = $state.refreshNext
    $state.refreshStarted = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - 30000
    [void](Get-UsageSnapshot)
    Assert-Quota (!$state.refresh -and $script:FixtureRefreshProcess.KillCount -eq 1 -and $script:FixtureRefreshProcess.DisposeCount -eq 1) 'A 30-second timeout must kill and dispose the owner'
    for ($tick = 0; $tick -lt 3; $tick++) { [void](Get-UsageSnapshot) }
    Assert-Quota ($script:FixtureRefreshStarts -eq 1 -and $state.refreshNext -eq $retryAt) 'Timed-out owners must not retry before the five-minute threshold'
    Assert-Quota ($script:FixtureRefreshProcess.KillCount -eq 1 -and $script:FixtureRefreshProcess.DisposeCount -eq 1) 'Later ticks must not kill or dispose a timed-out owner again'
    Write-Output 'PASS owner timeout cleans up once and retains refresh backoff'

    foreach ($scenario in @('current', 'no-refresh', 'no-identity', 'missing-expiry')) {
        Reset-Fixture -StoredAccess 'fixture-new'
        $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
        $script:FixtureCanRefresh = $true
        switch ($scenario) {
            'current' { $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddHours(8).ToString('o') }
            'no-refresh' { $script:FixtureCanRefresh = $false }
            'no-identity' { $script:FixtureHasIdentity = $false }
            'missing-expiry' { $script:FixtureExpiresAt = $null }
        }
        [void](Get-UsageSnapshot)
        Assert-Quota ($script:FixtureRefreshStarts -eq 0 -and !$script:QuotaState.claude.refresh) ($scenario + ' must not launch a credential owner')
    }
    Write-Output 'PASS current or ineligible credentials never launch an owner'

    Reset-Fixture -StoredAccess 'fixture-new'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    $script:FixtureCanRefresh = $true
    $script:FixtureRefreshProcess = $null
    $startedBefore = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [void](Get-UsageSnapshot)
    for ($tick = 0; $tick -lt 3; $tick++) { [void](Get-UsageSnapshot) }
    Assert-Quota ($script:FixtureRefreshStarts -eq 1 -and !$script:QuotaState.claude.refresh) 'A missing native CLI must not cause repeated launch attempts'
    Assert-Quota ($script:QuotaState.claude.refreshNext -ge $startedBefore + 300000) 'Missing-CLI retries must retain the five-minute threshold'
    Write-Output 'PASS missing native CLI retains refresh backoff'

    Reset-Fixture -AuthFailed $false
    $script:FixtureAccess = 'fixture-old'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    $script:FixtureCanRefresh = $true
    $state = $script:QuotaState.claude
    $originalNext = $state.next
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRefreshStarts -eq 1) 'Rate-limit backoff must still permit expired credential renewal'
    $script:FixtureAccess = 'fixture-new'
    $script:FixtureExpiresAt = [DateTimeOffset]::UtcNow.AddHours(8).ToString('o')
    $script:FixtureRefreshProcess.HasExited = $true
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 0 -and $state.next -eq $originalNext) 'Native credential renewal must preserve existing rate-limit backoff'
    Assert-Quota (!$state.refresh -and $script:FixtureRefreshProcess.DisposeCount -eq 1) 'An owner completing during rate-limit backoff must still be disposed'
    Write-Output 'PASS native renewal preserves rate-limit backoff'

    Reset-Fixture -AuthFailed $false -StoredAccess 'fixture-new'
    $script:FixtureBody = '{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":37,"resets_at":"2099-01-07T00:00:00Z"}}'
    $state = $script:QuotaState.claude
    $state.at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $state.view.updatedAt = To-IsoTime $state.at
    $state.view.windows[0].resetsAt = [DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o')
    $state.next = 0L
    [void](Get-UsageSnapshot)
    Assert-Quota ($script:FixtureRequests.Count -eq 1) 'An expired five-hour reset must trigger a usage request even when the last observation is fresh'
    [void](Get-UsageSnapshot)
    $short = @($state.view.windows | Where-Object { $_.id -eq '5h' })
    $week = @($state.view.windows | Where-Object { $_.id -eq '1w' })
    Assert-Quota ($state.view.status -eq 'ok' -and $state.failures -eq 0 -and $state.view.windows.Count -eq 2) 'A successful idle-window response must be fresh and retain both windows'
    Assert-Quota ($short.Count -eq 1 -and $short[0].usedPercent -eq 0 -and $null -eq $short[0].resetsAt) 'Zero utilization with no reset time is a valid five-hour window'
    Assert-Quota ($week.Count -eq 1 -and $week[0].usedPercent -eq 37 -and $week[0].resetsAt) 'The idle five-hour window must preserve weekly usage and reset time'
    for ($tick = 0; $tick -lt 3; $tick++) { [void](Get-UsageSnapshot) }
    Assert-Quota ($script:FixtureRequests.Count -eq 1 -and !$state.task -and $script:FixtureRefreshStarts -eq 0) 'A null reset time must not cause immediate repeated usage requests or owner launches'
    Write-Output 'PASS five-hour reset refreshes fresh observations and accepts zero utilization with null reset'
} finally {
    foreach ($request in $script:FixtureRequests) { if ($request) { $request.Dispose() } }
    if ($ownsMutex -and $quotaMutex) { $quotaMutex.ReleaseMutex() }
    if ($quotaMutex) { $quotaMutex.Dispose() }
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -ne ('zebar-quota-test-' + $fixtureId)) { throw 'Refusing to remove an unexpected test directory' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
