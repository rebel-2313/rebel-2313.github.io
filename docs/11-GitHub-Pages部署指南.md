# 11 · GitHub Pages 部署指南（免费公网主页）

> 作用：不花钱就能让网站在公网访问，地址形如 `https://你的用户名.github.io/`。
> 与腾讯云服务器是**两套独立通道**：Pages 免费、免运维，适合作业验收和展示；腾讯云是自己的服务器，可完全掌控。两者可以并存。
> 部署方式：采用 GitHub Pages 的 **Deploy from a branch**（从 main 分支根目录发布）。纯静态站点用它最简单可靠，push 即更新，无需 GitHub Actions。

---

## 一、框架已搭好的部分（本仓库内，无需你操作）

| 文件 | 作用 |
| --- | --- |
| `.nojekyll` | 告诉 Pages 不要用 Jekyll 处理，原样发布静态文件 |
| `index.html` / `assets/` | 站点本体，资源用相对路径，可直接发布 |
| `404.html` | 自定义 404 页（用绝对路径，兼容子路径访问） |

> 说明：曾考虑用 GitHub Actions 自动部署，但那需要 Personal Access Token 带 `workflow` 权限，对纯静态站属于多余配置，已改用 branch 方式。

---

## 二、需要你注册 GitHub 账号（一次性）

1. 打开 https://github.com/signup 注册（邮箱建议用常用邮箱）；
2. 验证邮箱；
3. 记住你的**用户名**（本项目为 `rebel-2313`）。

---

## 三、建仓库（关键：名字必须是 `用户名.github.io`）

> 个人主站形式要求仓库名严格等于 `你的用户名.github.io`，这样地址才是 `https://用户名.github.io/`。
> 本项目仓库名：`rebel-2313.github.io`（已建好）。

1. 登录 GitHub，点右上角 `+` → `New repository`；
2. Repository name 填 `你的用户名.github.io`；
3. 选 **Public**（Pages 免费版要求公开仓库）；
4. **不要**勾选 "Add a README file"（保持空仓库，方便本地首次推送）；
5. 点 `Create repository`。

---

## 四、本地推送（助手已执行）

仓库建好后由助手在本地执行：

```bash
git remote add origin https://github.com/用户名/用户名.github.io.git
git push -u origin main
```

推送认证用 Personal Access Token（`repo` 权限即可，见 `docs/12`）。

---

## 五、启用 Pages（一次设置）

1. 进入仓库 → `Settings` → 左侧 `Pages`；
2. Build and deployment → Source 选 **Deploy from a branch**；
3. Branch 选 **`main`**，目录选 **`/ (root)`**；
4. 点 Save。等待约 1 分钟，打开 `https://用户名.github.io/` 验收。

> 本项目已通过 GitHub API 自动完成上述设置。

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

- [ ] `https://用户名.github.io/` 能打开，中文不乱码
- [ ] 样式、脚本、图片都正常（F12 控制台无 404）
- [ ] 主题切换、导航、相册正常
- [ ] 手机浏览器能访问

---

## 八、常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| 404 | 仓库名不对（必须 `用户名.github.io`），或 Pages Source / Branch 设置不对 |
| 页面没样式 | 资源路径错；本仓库用相对路径，正常不会出问题 |
| 改了没变化 | 浏览器缓存 `Ctrl + F5`；或等 push 后约 1 分钟再刷新 |
| 推送要密码 | GitHub 已不支持账号密码推送，要用 Personal Access Token，见 `docs/12` |
| 推送报 `workflow scope` | 旧版曾配 Actions workflow 时会遇到；本项目已改用 branch 方式，无此问题 |
