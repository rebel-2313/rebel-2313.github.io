#!/usr/bin/env bash
# =====================================================================
# 服务器端一键初始化脚本（在腾讯云 Ubuntu 22.04 轻量服务器上执行）
#
# 作用：装 Nginx、建站点目录、装好 personal-site 站点配置并启用，
#       为后续 deploy.ps1 上传网站文件做好准备。只需执行一次。
#
# 用法（用 root 登录服务器后）：
#   bash server-init.sh
#   或：wget <你的地址>/server-init.sh && bash server-init.sh
#
# 前置：控制台防火墙已放行 22（SSH）和 80（HTTP）。
# 对应文档：docs/05-部署上线指南.md 第五~七节。
# =====================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 运行（或 sudo bash $0）"
  exit 1
fi

echo "==> 1/6 更新软件源"
apt update -y && apt upgrade -y

echo "==> 2/6 设置时区为上海"
timedatectl set-timezone Asia/Shanghai || true

echo "==> 3/6 安装 Nginx 与工具"
apt install -y nginx curl git rsync ufw

echo "==> 4/6 启动 Nginx 并开机自启"
systemctl enable --now nginx

echo "==> 5/6 建站点目录与备份目录"
mkdir -p /var/www/personal-site /var/backups/personal-site
chown -R www-data:www-data /var/www/personal-site

# 放一个占位首页，方便在传正式文件前验证 Nginx 已工作
if [ ! -f /var/www/personal-site/index.html ]; then
  echo '<h1>nginx ready · waiting for deploy</h1>' > /var/www/personal-site/index.html
  chown www-data:www-data /var/www/personal-site/index.html
fi

echo "==> 6/6 安装站点配置"
# 优先用脚本同目录的 personal-site.conf（若一起上传了）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/nginx/personal-site.conf" ]; then
  cp "$SCRIPT_DIR/nginx/personal-site.conf" /etc/nginx/sites-available/personal-site
  echo "    已从 $SCRIPT_DIR/nginx/personal-site.conf 安装配置"
else
  cat > /etc/nginx/sites-available/personal-site <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/personal-site;
    index index.html;
    charset utf-8;
    charset_types text/html text/css application/javascript application/json image/svg+xml;
    access_log /var/log/nginx/personal-site.access.log;
    error_log  /var/log/nginx/personal-site.error.log;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/javascript application/json application/xml image/svg+xml;
    location ~* \.(?:css|js|mjs|svg|png|jpe?g|webp|gif|ico|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public, max-age=604800";
        access_log off;
    }
    location ~* \.(?:html|md)$ { add_header Cache-Control "no-cache"; }
    location / { try_files $uri $uri/ =404; }
    location ~ /\. { deny all; access_log off; log_not_found off; }
    error_page 404 /404.html;
    location = /404.html { internal; }
}
EOF
  echo "    已写入内置默认站点配置"
fi

# 启用站点，关掉默认站点
ln -sf /etc/nginx/sites-available/personal-site /etc/nginx/sites-enabled/personal-site
rm -f /etc/nginx/sites-enabled/default

# 系统防火墙（云控制台防火墙也要单独放行 80/22）
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow 'Nginx Full' >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

echo "==> 校验 Nginx 配置"
nginx -t

echo "==> 重载 Nginx"
systemctl reload nginx

echo ""
echo "✅ 初始化完成。浏览器打开 http://$(curl -s -4 ifconfig.me 2>/dev/null || echo '你的公网IP')/ "
echo "   应看到 'nginx ready · waiting for deploy'。"
echo "   接下来在你自己的电脑上执行 deploy/deploy.ps1 上传正式网站文件。"
