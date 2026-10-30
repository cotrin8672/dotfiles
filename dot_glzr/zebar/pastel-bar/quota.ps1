# Local proxy observations are preferred; a quiet or stopped proxy is supplemented by a
# read-only usage GET at most every five minutes. Never send a model prompt or refresh OAuth.
$script:ProxyHome = if ($env:OPENCODEX_HOME) { $env:OPENCODEX_HOME } else { Join-Path $env:USERPROFILE '.opencodex' }
$script:QuotaState = @{}
$script:CacheStamps = @{}
$script:QuotaFile = Join-Path $PSScriptRoot 'data\ai-cache.json'
$script:QuotaMutex = New-Object Threading.Mutex($false, 'Local\ZebarPastelQuota-v1')
try { $script:QuotaLeader = $script:QuotaMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $script:QuotaLeader = $true }
Add-Type -AssemblyName System.Net.Http
$handler = New-Object Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false
$script:UsageHttp = New-Object Net.Http.HttpClient($handler)
$script:UsageHttp.Timeout = [TimeSpan]::FromSeconds(12)

function Read-LocalJson([string]$Path) {
    try {
        $file = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($file.Length -gt 4MB) { return $null }
        return [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
    } catch { return $null }
}

function To-IsoTime($Value) {
    if ($null -eq $Value) { return $null }
    try {
        if ($Value -is [string] -and $Value.Contains('T')) { return ([DateTimeOffset]::Parse($Value)).ToUniversalTime().ToString('o') }
        $number = [double]$Value
        if ($number -lt 100000000000) { $number *= 1000 }
        return [DateTimeOffset]::FromUnixTimeMilliseconds([long]$number).ToString('o')
    } catch { return $null }
}

function New-QuotaWindow([string]$Id, [string]$Label, $Percent, $Reset, $DurationSeconds = $null) {
    if ($null -eq $Percent -or $Percent -is [string] -or $Percent -is [bool]) { return }
    $value = [double]$Percent
    if ([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 0 -or $value -gt 100) { return }
    $window = @{ id = $Id; label = $Label; usedPercent = $value; resetsAt = To-IsoTime $Reset }
    if ($null -ne $DurationSeconds -and $DurationSeconds -isnot [string] -and $DurationSeconds -isnot [bool]) {
        $duration = [double]$DurationSeconds
        if ($duration -gt 0 -and ![double]::IsNaN($duration) -and ![double]::IsInfinity($duration)) { $window.durationSeconds = $duration }
    }
    return $window
}

function Read-UsageIdentity([string]$Provider) {
    if ($Provider -eq 'codex') {
        $dir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
        $auth = Read-LocalJson (Join-Path $dir 'auth.json')
        $token = $auth.tokens.access_token
        $identity = $auth.tokens.account_id
        $plan = $null
        try {
            $part = $auth.tokens.id_token.Split('.')[1].Replace('-', '+').Replace('_', '/')
            $part = $part.PadRight($part.Length + (4 - $part.Length % 4) % 4, '=')
            $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
            $plan = $claims.'https://api.openai.com/auth'.chatgpt_plan_type
            if (!$identity) { $identity = $claims.sub }
        } catch { }
        $endpoint = 'https://chatgpt.com/backend-api/wham/usage'
    } else {
        $dir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
        $auth = Read-LocalJson (Join-Path $dir '.credentials.json')
        $token = $auth.claudeAiOauth.accessToken
        $plan = $auth.claudeAiOauth.subscriptionType
        $accountPath = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $dir '.claude.json' } else { Join-Path $env:USERPROFILE '.claude.json' }
        $identity = (Read-LocalJson $accountPath).oauthAccount.accountUuid
        if (!$identity) { $identity = $auth.claudeAiOauth.refreshToken }
        $endpoint = 'https://api.anthropic.com/api/oauth/usage'
    }
    if (!$token -or !$identity) { return $null }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    return @{ access = $token; account = $identity; key = $key; plan = $plan; endpoint = $endpoint }
}

function Convert-ProxyQuota([string]$Provider, $Quota) {
    if (!$Quota) { return @() }
    $windows = @()
    if ($Provider -eq 'codex') {
        $short = New-QuotaWindow '5h' '5h' $Quota.shortPercent $Quota.shortResetAt $Quota.shortWindowSeconds
        if ($short -and $Quota.shortWindowSeconds -and $Quota.shortWindowSeconds -ne 18000) {
            $short.label = '{0}h' -f ($Quota.shortWindowSeconds / 3600)
        }
    } else { $short = New-QuotaWindow '5h' '5h' $Quota.fiveHourPercent $Quota.fiveHourResetAt 18000 }
    if ($short) { $windows += $short }
    $week = New-QuotaWindow '1w' '1w' $Quota.weeklyPercent $Quota.weeklyResetAt 604800
    if ($week) { $windows += $week }
    if (!$week) {
        $month = New-QuotaWindow '1mo' '1mo' $Quota.monthlyPercent $Quota.monthlyResetAt
        if ($month) { $windows += $month }
    }
    return $windows
}

function Convert-RemoteQuota([string]$Provider, $Body) {
    if ($Provider -eq 'claude') {
        return @(New-QuotaWindow '5h' '5h' $Body.five_hour.utilization $Body.five_hour.resets_at 18000
                 New-QuotaWindow '1w' '1w' $Body.seven_day.utilization $Body.seven_day.resets_at 604800)
    }
    $rows = @($Body.rate_limit.primary_window, $Body.rate_limit.secondary_window, $Body.rate_limit.tertiary_window)
    $windows = @()
    foreach ($row in $rows) {
        if (!$row -or !$row.limit_window_seconds) { continue }
        $seconds = [double]$row.limit_window_seconds
        $label = if ($seconds -eq 18000) { '5h' } elseif ($seconds -eq 604800) { '1w' } elseif ($seconds -ge 2419200) { '1mo' } else { '{0}h' -f ($seconds / 3600) }
        $w = New-QuotaWindow $label $label $row.used_percent $row.reset_at $seconds
        if ($w) { $windows += $w }
    }
    return $windows
}

function Get-UsageSnapshot {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    if (!$script:QuotaLeader) {
        $shared = Read-LocalJson $script:QuotaFile
        if ($shared) { return $shared }
        return @{}
    }
    foreach ($provider in @('codex', 'claude')) {
        if (!$script:QuotaState.ContainsKey($provider)) {
            $script:QuotaState[$provider] = @{ view = @{ status='loading'; plan=$null; windows=@(); updatedAt=$null; message='Waiting for usage data' }; at=0L; next=0L; failures=0; key=$null; task=$null; identityCheck=0L }
        }
        $state = $script:QuotaState[$provider]
        if ($now -ge $state.identityCheck) {
            $identity = Read-UsageIdentity $provider
            $state.identityCheck = $now + 30000
            if ($state.key -and (!$identity -or $identity.key -ne $state.key)) {
                $state.view = @{ status='loading'; plan=$null; windows=@(); updatedAt=$null; message='Account changed; waiting for fresh usage' }
                $state.at = 0L; $state.next = 0L
                $state.switchedAt = $now
            }
            $state.identity = $identity; $state.key = $identity.key
            $state.view.plan = $identity.plan
        }
        $filename = if ($provider -eq 'codex') { 'codex-quota-cache.json' } else { 'claude-usage-admission.json' }
        $path = Join-Path $script:ProxyHome $filename
        try {
            $stamp = (Get-Item -LiteralPath $path -ErrorAction Stop).LastWriteTimeUtc.Ticks
            if ($script:CacheStamps[$provider] -ne $stamp) {
                $disk = Read-LocalJson $path
                if ($disk) {
                    $script:CacheStamps[$provider] = $stamp
                    $quota = if ($provider -eq 'codex') { $disk.quotas.__main__ } else { $disk.quota }
                    # Only the current main account is used, never a pooled account chosen for a turn.
                    $at = if ($quota.updatedAt) { [long]$quota.updatedAt } else { 0L }
                    $windows = @(Convert-ProxyQuota $provider $quota)
                    if ($windows.Count -and $at -gt $state.at -and $at -ge $state.switchedAt) {
                        $state.at = $at
                        $state.view.windows = $windows; $state.view.updatedAt = To-IsoTime $at
                        $state.view.message = 'Usage from OpenCodex local cache'
                    }
                }
            }
        } catch { } # An atomic cache replacement may briefly make the file unavailable.
        if ($state.task -and $state.task.IsCompleted) {
            $response = $null
            try {
                $response = $state.task.GetAwaiter().GetResult()
                if (!$response.IsSuccessStatusCode) {
                    $retry = $response.Headers.RetryAfter
                    if ($retry -and $retry.Delta) { $state.next = [Math]::Max($state.next, $now + $retry.Delta.TotalMilliseconds) }
                    if ($retry -and $retry.Date) { $state.next = [Math]::Max($state.next, $retry.Date.ToUnixTimeMilliseconds()) }
                    $state.view.message = 'Usage refresh returned HTTP ' + [int]$response.StatusCode
                    throw 'Usage request was not successful'
                }
                $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                $windows = @(Convert-RemoteQuota $provider $body)
                if (!$windows.Count) { throw 'No measurable subscription windows' }
                if ($state.requestKey -eq $state.key) {
                    $state.view.windows = $windows; $state.at = $now
                    $state.view.updatedAt = To-IsoTime $now
                    $state.view.message = 'Usage refreshed directly'
                    if ($body.plan_type) { $state.view.plan = $body.plan_type }
                }
                $state.failures = 0; $state.next = $now + 300000
            } catch {
                $state.failures++
                $state.next = [Math]::Max($state.next, $now + [Math]::Min(1800000, 300000 * [Math]::Pow(2, $state.failures - 1)))
                if ($state.view.message -notlike '*HTTP*') { $state.view.message = 'Usage refresh unavailable; retaining last observation' }
            } finally {
                if ($response) { $response.Dispose() }
                $state.task = $null
            }
        }
        $expired = @($state.view.windows | Where-Object { $_.resetsAt -and [DateTimeOffset]::Parse($_.resetsAt).ToUnixTimeMilliseconds() -le $now }).Count -gt 0
        if (!$state.task -and $state.identity -and $now -ge $state.next -and ($now - $state.at -ge 300000 -or $expired)) {
            $request = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Get, $state.identity.endpoint)
            $request.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $state.identity.access)
            $request.Headers.Accept.ParseAdd('application/json')
            if ($provider -eq 'claude') {
                [void]$request.Headers.TryAddWithoutValidation('anthropic-beta', 'oauth-2025-04-20')
                [void]$request.Headers.TryAddWithoutValidation('User-Agent', 'claude-code/2.1.90')
            } else { [void]$request.Headers.TryAddWithoutValidation('ChatGPT-Account-Id', $state.identity.account) }
            $state.requestKey = $state.key
            $state.task = $script:UsageHttp.SendAsync($request)
            $state.next = $now + 300000
        }
        # Window presence determines layout; Pro's absent 5h window is never invented as 0%.
        if ($provider -eq 'codex' -and $state.view.plan -match '^pro') {
            $state.view.windows = @($state.view.windows | Where-Object { $_.id -ne '5h' })
        }
        if ($state.view.windows.Count) {
            $state.view.status = if ($expired -or $now - $state.at -gt 600000) { 'stale' } else { 'ok' }
        } elseif (!$state.identity) {
            $state.view.status='unavailable'; $state.view.message='Subscription login not available'
        } elseif ($state.failures) { $state.view.status='error' }
    }
    $result = @{ codex = $script:QuotaState.codex.view; claude = $script:QuotaState.claude.view }
    $json = $result | ConvertTo-Json -Depth 10 -Compress
    if ($json -ne $script:LastQuotaJson) {
        [void][IO.Directory]::CreateDirectory((Split-Path $script:QuotaFile))
        $temp = $script:QuotaFile + '.tmp'
        [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temp -Destination $script:QuotaFile -Force
        $script:LastQuotaJson = $json
    }
    return $result
}
