# =====================================================================
# 一键部署脚本（在 Windows 电脑上运行，把网站上传到云服务器）
#
# 前提：
#   1. Windows 10/11 自带 OpenSSH 客户端（ssh / scp）。检查：ssh -V
#      若提示找不到命令，按 docs/05 里的说明安装「OpenSSH 客户端」。
#   2. 服务器已按 docs/05 装好 Nginx，且站点目录为 /var/www/personal-site。
#   3. 你有一个可以 SSH 登录的账号（root 或带 sudo 权限的普通用户）。
#
# 用法（在项目根目录执行，按实际情况替换 IP 和用户名）：
#   powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1 -Server 1.2.3.4 -User root
#   powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1 -Server 1.2.3.4 -User ubuntu -Port 22 -KeyPath "$env:USERPROFILE\.ssh\id_rsa"
#
# 脚本做的事情：打包需要的文件 → scp 上传 → 远程解包发布（自动备份 + 校验 + 回滚保护）
# =====================================================================

param(
  [Parameter(Mandatory = $true)][string]$Server,                  # 服务器 IP 或域名
  [string]$User = 'root',                                        # SSH 用户名
  [int]$Port = 22,                                               # SSH 端口
  [string]$KeyPath = '',                                         # 私钥路径（用密码登录就不用填）
  [string]$RemoteTemp = '/tmp'                                   # 服务器临时目录
)

$ErrorActionPreference = 'Stop'

# 项目根目录 = 本脚本上一级
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TarName     = 'personal-site.tar.gz'
$TarLocal    = Join-Path $env:TEMP $TarName

Write-Host "==> 0/4 检查依赖"
foreach ($cmd in 'ssh', 'scp', 'tar') {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "缺少命令 $cmd，请先安装（见 docs/05-部署上线指南.md）"
  }
}

Write-Host "==> 1/4 打包网站文件"
# 只上传网站运行需要的文件：页面、简历、静态资源
$items = @('index.html', 'resume.md', '404.html', 'assets')
foreach ($item in $items) {
  if (-not (Test-Path (Join-Path $ProjectRoot $item))) {
    throw "找不到 $item，确认脚本放在 personal-site\deploy 目录下运行"
  }
}
if (Test-Path $TarLocal) { Remove-Item $TarLocal -Force }
Push-Location $ProjectRoot
try {
  & tar -czf $TarLocal @items
  if ($LASTEXITCODE -ne 0) { throw "打包失败" }
} finally {
  Pop-Location
}
Write-Host ("    打包完成：" + $TarLocal + "（" + [math]::Round((Get-Item $TarLocal).Length / 1KB, 1) + " KB）")

# 公共的 SSH / SCP 参数（注意 ssh 用小写 -p 指定端口，scp 用大写 -P）
$sshOpts = @('-p', $Port, '-o', 'StrictHostKeyChecking=accept-new')
$scpOpts = @('-P', $Port, '-o', 'StrictHostKeyChecking=accept-new')
if ($KeyPath) {
  $sshOpts += @('-i', $KeyPath)
  $scpOpts += @('-i', $KeyPath)
}
$target = "$User@$Server"

Write-Host "==> 2/4 上传压缩包与部署脚本"
& scp @scpOpts $TarLocal "${target}:${RemoteTemp}/$TarName"
if ($LASTEXITCODE -ne 0) { throw "上传压缩包失败，检查网络 / 账号 / 端口" }
& scp @scpOpts (Join-Path $PSScriptRoot 'remote-deploy.sh') "${target}:${RemoteTemp}/remote-deploy.sh"
if ($LASTEXITCODE -ne 0) { throw "上传部署脚本失败" }

Write-Host "==> 3/4 远程执行部署（可能会要求输入 sudo 密码）"
& ssh @sshOpts $target "sudo bash ${RemoteTemp}/remote-deploy.sh ${RemoteTemp}/$TarName"
if ($LASTEXITCODE -ne 0) { throw "远程部署失败，按上面的提示排查" }

Write-Host "==> 4/4 完成"
Write-Host "    浏览器打开 http://$Server/ 验收"
Write-Host "    若是首次部署，记得先在服务器上按 docs/05 配好 Nginx 站点。"
