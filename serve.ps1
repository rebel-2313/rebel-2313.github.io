# =====================================================================
#  本地预览服务器
#  双击「启动本地预览.bat」即可运行；关掉这个黑窗口就停止。
#  它会同时打印两个网址：
#    · 本地访问：只在这台电脑上能打开
#    · 局域网访问：同一个 WiFi/路由器下的手机、朋友电脑都能打开
#
#  v3 修复（2026-11-03）：
#    以前默认用 8080，且允许端口复用，一旦 8080 已被别的程序（例如另一个
#    项目的预览服务）占用，本脚本会"假装"绑定成功，但浏览器请求被那个程序
#    接走，于是看到的是别人的页面。
#    现在改为：
#      1) 默认端口 5180，避开最常见的 8080/3000/8000 冲突；
#      2) 先真实探测端口是否有人应答，有人应答就直接换下一个；
#      3) 绑定时强制独占（ExclusiveAddressUse = $true），绝不与别的程序共用；
#      4) 启动后打印的端口就是实际在用的端口，并在控制台回显"跳过 xx 端口"。
# =====================================================================

param(
    [int]$Port = 5180,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$root = (Resolve-Path $root).Path

if (-not (Test-Path (Join-Path $root 'index.html'))) {
    Write-Host "没有在这个文件夹里找到 index.html：$root" -ForegroundColor Red
    Read-Host '按回车退出'
    exit 1
}

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.webp' = 'image/webp'
    '.ico'  = 'image/x-icon'
    '.txt'  = 'text/plain; charset=utf-8'
    '.md'   = 'text/plain; charset=utf-8'
    '.woff' = 'font/woff'
    '.woff2'= 'font/woff2'
    '.mp4'  = 'video/mp4'
    '.mp3'  = 'audio/mpeg'
}

function Get-MimeType([string]$filePath) {
    $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
    if ($mime.ContainsKey($ext)) { return $mime[$ext] }
    return 'application/octet-stream'
}

function Send-Bytes($stream, [int]$status, [string]$reason, [byte[]]$body, [string]$contentType) {
    $head = "HTTP/1.1 $status $reason`r`n" +
            "Content-Type: $contentType`r`n" +
            "Content-Length: $($body.Length)`r`n" +
            "Cache-Control: no-cache, no-store, must-revalidate`r`n" +
            "Access-Control-Allow-Origin: *`r`n" +
            "Connection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($headBytes, 0, $headBytes.Length)
    if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
    $stream.Flush()
}

function Send-Text($stream, [int]$status, [string]$reason, [string]$text) {
    $body = [System.Text.Encoding]::UTF8.GetBytes($text)
    Send-Bytes $stream $status $reason $body 'text/plain; charset=utf-8'
}

# 探测某个端口是否已经有程序在监听（有程序应答 → 说明被占用）
function Test-PortOccupied([int]$p) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $p, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(200)) {
            $client.EndConnect($iar)
            return $true
        }
        return $false
    } catch {
        # 连接被拒绝 = 没有程序在听，可以放心用
        return $false
    } finally {
        try { $client.Close() } catch { }
    }
}

# ---------------------------------------------------------------- 启动监听
$listener = $null
$skipped = @()
for ($try = $Port; $try -le ($Port + 20); $try++) {
    if (Test-PortOccupied $try) {
        $skipped += $try
        continue
    }
    try {
        $candidate = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $try)
        # 关键：独占绑定，绝不和别的程序共用同一端口，避免"抢到了端口却看到别人页面"
        $candidate.Server.ExclusiveAddressUse = $true
        $candidate.Start()
        $listener = $candidate
        $Port = $try
        break
    } catch {
        $skipped += $try
    }
}

if ($null -eq $listener) {
    Write-Host ('{0}-{1} 范围内的端口都不可用，请稍后重试。' -f $Port, ($Port + 20)) -ForegroundColor Red
    Read-Host '按回车退出'
    exit 1
}

function Get-LanAddresses {
    $found = @()
    try {
        $found = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress -Unique
    } catch { $found = @() }
    if (-not $found -or $found.Count -eq 0) {
        # 某些系统上上面这条命令需要更高权限，换一个办法取本机地址
        try {
            $found = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
                Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                ForEach-Object { $_.IPAddressToString } |
                Where-Object { $_ -notlike '127.*' -and $_ -notlike '169.254.*' } |
                Select-Object -Unique
        } catch { $found = @() }
    }
    return @($found)
}

$lanIps = Get-LanAddresses

Write-Host ''
Write-Host '  杨叶珥 · 个人网站 本地预览' -ForegroundColor Cyan
Write-Host '  ------------------------------'
Write-Host ("  文件夹：{0}" -f $root)
if ($skipped.Count -gt 0) {
    Write-Host ("  已跳过被占用的端口：{0}（可能开着别的项目的预览服务）" -f ($skipped -join ', ')) -ForegroundColor Yellow
}
Write-Host ''
Write-Host ("  本地打开：    http://localhost:{0}/" -f $Port) -ForegroundColor Green
foreach ($ip in $lanIps) {
    Write-Host ("  局域网打开：  http://{0}:{1}/     ← 同一个 WiFi 下的手机/朋友用这个" -f $ip, $Port) -ForegroundColor Green
}
Write-Host ''
Write-Host '  提示 1：请用上面打印的端口访问。如果你以前习惯打开 8080，那个端口'
Write-Host '          现在可能属于别的程序，会显示成别人的页面。'
Write-Host '  提示 2：局域网打不开通常是 Windows 防火墙拦了，在提示里点「允许访问」。'
Write-Host '  停止：按 Ctrl+C 或直接关掉这个窗口。'
Write-Host ''

if (-not $NoBrowser) {
    # 加一个随机参数，避免浏览器拿旧缓存
    $url = ("http://localhost:{0}/?t={1}" -f $Port, [DateTime]::Now.Ticks)
    try { Start-Process $url | Out-Null } catch { }
}

# ---------------------------------------------------------------- 请求循环
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 1500
        $client.SendTimeout = 5000
        try {
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)

            $requestLine = $null
            try { $requestLine = $reader.ReadLine() } catch { $requestLine = $null }
            if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }

            # 把请求头读完（不解析，够用）
            while ($true) {
                $line = $null
                try { $line = $reader.ReadLine() } catch { break }
                if ($null -eq $line -or $line -eq '') { break }
            }

            $segments = $requestLine.Split(' ')
            $method = $segments[0].ToUpperInvariant()
            $rawPath = if ($segments.Length -gt 1) { $segments[1] } else { '/' }
            $rawPath = $rawPath.Split('?')[0]
            $decoded = [System.Uri]::UnescapeDataString($rawPath)
            if ($decoded -eq '/' -or $decoded -eq '') { $decoded = '/index.html' }

            $relative = $decoded.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $relative))

            if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                Send-Text $stream 403 'Forbidden' '403 Forbidden'
                continue
            }
            if ((Test-Path $full) -and (Get-Item $full).PSIsContainer) {
                $full = Join-Path $full 'index.html'
            }
            if (-not (Test-Path $full)) {
                Send-Text $stream 404 'Not Found' ("404 Not Found: " + $decoded)
                continue
            }

            if ($method -eq 'HEAD') {
                Send-Bytes $stream 200 'OK' (New-Object byte[] 0) (Get-MimeType $full)
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($full)
            Send-Bytes $stream 200 'OK' $bytes (Get-MimeType $full)
            Write-Host ("  {0}  {1}" -f $segments[0], $decoded) -ForegroundColor DarkGray
        } catch {
            # 单个请求出错不影响服务继续运行
        } finally {
            try { $client.Close() } catch { }
        }
    }
} finally {
    try { $listener.Stop() } catch { }
    Write-Host ''
    Write-Host '预览已停止。' -ForegroundColor Cyan
}
