# UV1200 웹 컨트롤 - 내 PC 전용 간이 웹 서버 (Windows PowerShell 5.1 이상, 설치 필요 없음)
# start-windows.bat 가 실행합니다. 이 PC 안(127.0.0.1)에서만 접속되고, 외부에서는 접속할 수 없습니다.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$root = $env:UV_ROOT
if (-not $root) { $root = (Get-Location).Path }
$root = [IO.Path]::GetFullPath($root).TrimEnd('\','/')
# 포트: tools\port.txt 의 숫자 (사이트마다 다른 번호를 써야 각각 따로 설치됩니다)
$port = 41200
$portFile = [IO.Path]::Combine($root, 'tools', 'port.txt')
if (Test-Path -LiteralPath $portFile) { $n = 0; if ([int]::TryParse(((Get-Content -LiteralPath $portFile -Raw) -replace '[^0-9]', ''), [ref]$n) -and $n -ge 1024 -and $n -le 65535) { $port = $n } }
# 이 사이트의 이름표 (manifest의 id). 같은 포트에 다른 사이트가 떠 있는지 구별할 때 씀
$appId = ''; $appName = 'UV1200'
try { $m = Get-Content -LiteralPath ([IO.Path]::Combine($root, 'manifest.webmanifest')) -Raw -Encoding UTF8 | ConvertFrom-Json; $appId = [string]$m.id; $appName = [string]$m.name } catch {}
$noOpen = $env:UV_NOOPEN -eq '1'
$url = "http://localhost:$port/"

function Open-App {
  if ($noOpen) { return }
  $cands = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { Start-Process -FilePath $c -ArgumentList $url; return } }
  Start-Process $url
}

$mime = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8';
  '.webmanifest'='application/manifest+json'; '.json'='application/json'; '.png'='image/png'; '.svg'='image/svg+xml';
  '.ico'='image/x-icon'; '.txt'='text/plain; charset=utf-8'; '.css'='text/css; charset=utf-8' }

$listener = New-Object System.Net.Sockets.TcpListener ([Net.IPAddress]::Loopback), $port
$listener6 = $null
try { $listener.Start() }
catch {
  # 이미 이 사이트가 켜져 있는지, 다른 사이트(또는 프로그램)가 이 포트를 쓰는지 확인
  $same = $false
  try { $rq = [Net.HttpWebRequest]::Create("http://127.0.0.1:$port/manifest.webmanifest"); $rq.Timeout = 3000; $rq.ReadWriteTimeout = 3000; $rs = $rq.GetResponse(); $sr = New-Object IO.StreamReader($rs.GetResponseStream(), [Text.Encoding]::UTF8); $o = $sr.ReadToEnd() | ConvertFrom-Json; $sr.Close(); $rs.Close(); $same = [bool]$appId -and ([string]$o.id -eq $appId) } catch {}
  Write-Host ""
  if ($same) {
    Write-Host "  $appName 이(가) 이미 실행 중입니다. 브라우저만 엽니다:  $url" -ForegroundColor Yellow
    Open-App
    Start-Sleep -Seconds 3
    exit 0
  }
  Write-Host "  포트 $port 를 다른 사이트나 프로그램이 이미 쓰고 있습니다." -ForegroundColor Red
  Write-Host ""
  Write-Host "  해결 방법:"
  Write-Host "   - 다른 사이트의 검은 창(서버)을 닫고 다시 실행하거나,"
  Write-Host "   - tools\port.txt 의 숫자를 다른 번호(예: $($port + 1))로 바꾸고 다시 실행하세요."
  Write-Host "     (번호를 바꾸면 새 앱으로 설치되므로, 기존 앱의 설정·자동 백업은 보이지 않습니다."
  Write-Host "      바꾸기 전에 기존 앱에서 [파일 → 저장]으로 결과를 저장해 두세요.)"
  Write-Host ""
  exit 2
}

# localhost가 IPv6(::1)로 연결될 때를 위해 IPv6 루프백도 같이 엶 (실패해도 괜찮음)
try { $listener6 = New-Object System.Net.Sockets.TcpListener ([Net.IPAddress]::IPv6Loopback), $port; $listener6.Start() } catch { $listener6 = $null }
Write-Host ""
Write-Host "  $appName 서버가 실행 중입니다:  $url" -ForegroundColor Green
Write-Host ""
Write-Host "  1) 열린 Chrome/Edge 창 위쪽의 [앱 설치] 버튼(또는 주소창 오른쪽 설치 아이콘)을 누르세요."
Write-Host "  2) 설치가 끝나면 이 창을 닫아도 됩니다. 앱은 바탕화면·시작 메뉴에서 인터넷 없이 실행됩니다."
Write-Host "  3) 새 버전으로 바꿀 때: 파일을 덮어쓰고 이 파일을 다시 실행한 뒤 앱을 열면 업데이트 알림이 뜹니다."
Write-Host ""
Write-Host "  (서버를 끄려면 이 창을 닫으세요)" -ForegroundColor DarkGray
Open-App

function Send-Response($stream, [int]$code, [string]$status, [string]$type, [byte[]]$body, [bool]$head) {
  $hdr = "HTTP/1.1 $code $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($hdr)
  $stream.Write($hb, 0, $hb.Length)
  if (-not $head -and $body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}

# 연결만 하고 요청을 늦게 보내는 브라우저 연결(미리 연결)이 다른 요청을 막지 않도록, 데이터가 도착한 연결부터 처리
$pending = New-Object System.Collections.ArrayList
function Handle-Client($client) {
  try {
    $client.ReceiveTimeout = 3000; $client.SendTimeout = 10000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
    $line = $reader.ReadLine()
    if (-not $line) { return }
    while ($true) { $h = $reader.ReadLine(); if ($h -eq $null -or $h -eq '') { break } }
    $parts = $line.Split(' ')
    $method = $parts[0]; $target = if ($parts.Length -gt 1) { $parts[1] } else { '/' }
    $head = $method -eq 'HEAD'
    if ($method -ne 'GET' -and -not $head) { Send-Response $stream 405 'Method Not Allowed' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('405')) $false; return }
    $path = $target.Split('?')[0].Split('#')[0]
    $path = [Uri]::UnescapeDataString($path)
    if ($path.EndsWith('/')) { $path += 'index.html' }
    $rel = $path.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
    $full = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $rel))
    $inside = $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    if ($inside -and ($rel -notmatch '(^|[\\/])tools([\\/]|$)') -and (Test-Path -LiteralPath $full -PathType Leaf)) {
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $type = $mime[$ext]; if (-not $type) { $type = 'application/octet-stream' }
      $bytes = [IO.File]::ReadAllBytes($full)
      Send-Response $stream 200 'OK' $type $bytes $head
      Write-Host ("  {0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $path) -ForegroundColor DarkGray
    } else {
      Send-Response $stream 404 'Not Found' 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('404 Not Found')) $head
    }
  } catch {
      } finally {
    try { $client.Close() } catch {}
  }
}

while ($true) {
  $busy = $false
  while ($listener.Pending()) { [void]$pending.Add(@{ c = $listener.AcceptTcpClient(); t = [DateTime]::Now }); $busy = $true }
  while ($listener6 -and $listener6.Pending()) { [void]$pending.Add(@{ c = $listener6.AcceptTcpClient(); t = [DateTime]::Now }); $busy = $true }
  for ($i = $pending.Count - 1; $i -ge 0; $i--) {
    $p = $pending[$i]
    $ready = $false; try { $ready = $p.c.Available -gt 0 } catch { $ready = $false }
    if ($ready) { $pending.RemoveAt($i); Handle-Client $p.c; $busy = $true }
    elseif (([DateTime]::Now - $p.t).TotalSeconds -gt 15 -or -not $p.c.Connected) { $pending.RemoveAt($i); try { $p.c.Close() } catch {} }
  }
  if (-not $busy) { Start-Sleep -Milliseconds 10 }
}
