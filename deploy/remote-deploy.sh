# 服务器端部署脚本（在云服务器上执行）
#
# 作用：把 /tmp/personal-site.tar.gz 解包并发布到 /var/www/personal-site，
#       自动备份旧版本、校验 Nginx 配置、失败可回滚。
#
# 用法（在服务器上，root 或带 sudo 的用户）：
#   sudo bash remote-deploy.sh /tmp/personal-site.tar.gz
#
# 目录约定：
#   站点目录   /var/www/personal-site
#   备份目录   /var/backups/personal-site/<时间戳>
# =====================================================================

set -euo pipefail

TARBALL="${1:-/tmp/personal-site.tar.gz}"
SITE_DIR="/var/www/personal-site"
BACKUP_DIR="/var/backups/personal-site"
STAGE_DIR="$(mktemp -d)"

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 sudo 运行：sudo bash $0 $TARBALL"
  exit 1
fi

if [ ! -f "$TARBALL" ]; then
  echo "找不到上传包：$TARBALL"
  exit 1
fi

echo "==> 1/5 解包到临时目录"
tar -xzf "$TARBALL" -C "$STAGE_DIR"
if [ ! -f "$STAGE_DIR/index.html" ]; then
  echo "压缩包里没有 index.html，检查上传的是不是网站根目录"
  rm -rf "$STAGE_DIR"
  exit 1
fi

echo "==> 2/5 备份当前线上版本"
mkdir -p "$BACKUP_DIR"
if [ -d "$SITE_DIR" ]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  cp -a "$SITE_DIR" "$BACKUP_DIR/$STAMP"
  echo "    已备份到 $BACKUP_DIR/$STAMP"
  # 只保留最近 5 份备份
  ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf
else
  echo "    首次部署，无需备份"
fi

echo "==> 3/5 发布新版本"
mkdir -p "$SITE_DIR"
# --delete 保证服务器上删掉的文件（比如不用的旧图片）也被清理
rsync -a --delete "$STAGE_DIR"/ "$SITE_DIR"/
chown -R www-data:www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 755 {} \;
find "$SITE_DIR" -type f -exec chmod 644 {} \;

echo "==> 4/5 校验 Nginx 配置"
if ! nginx -t; then
  echo "Nginx 配置有误，回滚到上一版本"
  LAST="$(ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | head -n 1)"
  if [ -n "$LAST" ]; then
    rsync -a --delete "$LAST"/ "$SITE_DIR"/
    chown -R www-data:www-data "$SITE_DIR"
    echo "    已回滚：$LAST"
  fi
  rm -rf "$STAGE_DIR"
  exit 1
fi

echo "==> 5/5 重载 Nginx"
systemctl reload nginx

rm -rf "$STAGE_DIR"
echo "✅ 部署完成：http://$(curl -s -4 ifconfig.me 2>/dev/null || echo '服务器IP')/"
