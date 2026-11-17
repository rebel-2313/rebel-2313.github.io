# 11 · GitHub Pages 部署指南（免费公网主页）

> 作用：不花钱就能让网站在公网访问，地址形如 `https://你的用户名.github.io/`。
> 与腾讯云服务器是**两套独立通道**：Pages 免费、免运维，适合作业验收和展示；腾讯云是自己的服务器，可完全掌控。两者可以并存。
> 本仓库已配好自动部署：只要 push 到 `main`，GitHub Actions 会自动发布。

---

## 一、框架已搭好的部分（本仓库内，无需你操作）

| 文件 | 作用 |
| --- | --- |
| `.github/workflows/deploy-pages.yml` | 推送到 main 后自动构建并发布到 Pages |
| `.nojekyll` | 告诉 Pages 不要用 Jekyll 处理，原样发布静态文件 |
| `404.html` | 自定义 404 页（用绝对路径，兼容子路径访问） |
| `index.html` / `assets/` | 站点本体，资源用相对路径，可直接发布 |

---

## 二、需要你注册 GitHub 账号（一次性）

1. 打开 https://github.com/signup 注册（邮箱建议用常用邮箱）；
2. 验证邮箱；
3. 记住你的**用户名**（下面要用，假设叫 `yangyeer`，实际换成你自己的）。

---

## 三、建仓库（关键：名字必须是 `用户名.github.io`）

> 个人主站形式要求仓库名严格等于 `你的用户名.github.io`，这样地址才是 `https://用户名.github.io/`。
> 例如用户名 `yangyeer` → 仓库名 `yangyeer.github.io`。

1. 登录 GitHub，点右上角 `+` → `New repository`；
2. Repository name 填 `你的用户名.github.io`；
3. 选 **Public**（Pages 免费版要求公开仓库）；
4. **不要**勾选 "Add a README file"（保持空仓库，方便本地首次推送）；
5. 点 `Create repository`。

---

## 四、本地推送（我来执行 / 也可你照抄）

仓库建好后，把**你的用户名**告诉我，我在本地执行下面几条即可完成首次上传：

```bash
# 在项目根目录
git remote add origin https://github.com/你的用户名/你的用户名.github.io.git
git add -A
git commit -m "chore: 配置 GitHub Pages 自动部署"
git branch -M main
git push -u origin main
```

> 认证方式：推送时 Git 会弹窗让你登录 GitHub（浏览器授权或输入令牌）。我也可帮你配置命令行登录，见 `docs/12`。

---

## 五、启用 Pages（仓库建好后设置一次）

1. 进入仓库 → `Settings` → 左侧 `Pages`；
2. Build and deployment → Source 选 **GitHub Actions**；
3. 保存后，回到 `Actions` 标签，会看到 `Deploy to GitHub Pages` 正在运行；
4. 等待变绿（约 1 分钟），打开 `https://你的用户名.github.io/` 验收。

---

## 六、日常更新

改完内容后，只需：

```bash
git add -A
git commit -m "content: 更新xxx"
git push
```

push 后约 1 分钟，Pages 自动更新。无需手动操作。

---

## 七、验收清单

- [ ] `https://你的用户名.github.io/` 能打开，中文不乱码
- [ ] 样式、脚本、图片都正常（F12 控制台无 404）
- [ ] 主题切换、导航、相册正常
- [ ] Actions 里 `Deploy to GitHub Pages` 显示成功
- [ ] 手机浏览器能访问

---

## 八、常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| 404 | 仓库名不对（必须 `用户名.github.io`），或 Pages Source 没选 GitHub Actions |
| 页面没样式 | 资源路径错；本仓库用相对路径，正常不会出问题 |
| Actions 红色失败 | 点进失败的那次看日志；确认 workflow 文件在 `.github/workflows/` 下 |
| 改了没变化 | 浏览器缓存，`Ctrl + F5` 强刷；或等 Actions 跑完 |
| 推送要密码 | GitHub 已不支持账号密码推送，要用 Personal Access Token 或 CLI 登录，见 `docs/12` |
