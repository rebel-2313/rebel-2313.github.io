# =====================================================================
#  本地预览服务器
#  双击「启动本地预览.bat」即可运行；关掉这个黑窗口就停止。
#  它会同时打印两个网址：
#    · 本地访问：只在这台电脑上能打开
#    · 局域网访问：同一个 WiFi/路由器下的手机、朋友电脑都能打开
# =====================================================================

param(
    [int]$Port = 8080,
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

# ---------------------------------------------------------------- 启动监听
$listener = $null
for ($try = $Port; $try -le ($Port + 10); $try++) {
    try {
        $candidate = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $try)
        # 允许端口处于 TIME_WAIT 时也能重新绑定，重启脚本时不用换端口
        $candidate.Server.ExclusiveAddressUse = $false
        $candidate.Start()
        $listener = $candidate
        $Port = $try
        break
    } catch {
        if ($try -eq $Port) { Write-Host "端口 $try 被占用，试着换一个…" -ForegroundColor Yellow }
    }
}

if ($null -eq $listener) {
    Write-Host '没有找到可用端口，请稍后重试。' -ForegroundColor Red
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
Write-Host '  个人网站 · 本地预览' -ForegroundColor Cyan
Write-Host '  ------------------------------'
Write-Host ("  文件夹：{0}" -f $root)
Write-Host ''
Write-Host ("  本地打开：    http://localhost:{0}/" -f $Port) -ForegroundColor Green
foreach ($ip in $lanIps) {
    Write-Host ("  局域网打开：  http://{0}:{1}/     ← 同一个 WiFi 下的手机/朋友用这个" -f $ip, $Port) -ForegroundColor Green
}
Write-Host ''
Write-Host '  提示：如果局域网打不开，通常是 Windows 防火墙拦了 —— 在弹出的'
Write-Host '        提示里点「允许访问」即可（专用网络就行）。'
Write-Host '  停止：按 Ctrl+C 或直接关掉这个窗口。'
Write-Host ''

if (-not $NoBrowser) {
    try { Start-Process ("http://localhost:{0}/" -f $Port) | Out-Null } catch { }
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
