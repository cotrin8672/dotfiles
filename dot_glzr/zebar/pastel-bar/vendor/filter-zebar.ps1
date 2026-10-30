$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$sha = [Security.Cryptography.SHA256]::Create()
$buffer = New-Object IO.MemoryStream
[Console]::OpenStandardInput().CopyTo($buffer)
$bytes = $buffer.ToArray()
$buffer.Dispose()
if ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() -ne 'db9a9d1ae9603c81e272bb35656954ef0c20bde4bef0c959017c8cb11a8ab05e') {
    throw 'Unexpected unpatched zebar@3.0.0 SHA256'
}
$text = $utf8.GetString($bytes)
$text = $text.Replace('shell_write",{processId:', 'shell_write",{pid:')
$text = $text.Replace('shell_kill",{processId:', 'shell_kill",{pid:')
$bytes = $utf8.GetBytes($text)
if ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() -ne '1835153e6329f40a2b5af685e45a1ca790e3417f95bf9c919a2beae6c67a6cdb') {
    throw 'Unexpected patched zebar@3.0.0 SHA256'
}
$sha.Dispose()
[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)
