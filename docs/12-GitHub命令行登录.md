# 12 · GitHub 命令行登录（推送认证）

> GitHub 从 2021 年起不再支持用「账号 + 密码」推送代码，必须用 **Personal Access Token（PAT）** 或 **GitHub CLI 登录**。
> 本文件记录两种方式，账号注册好后二选一即可。选 A 最简单，推荐。

---

## 方式 A：Personal Access Token（推荐，最省事）

### 1. 生成令牌
1. 登录 GitHub → 右上角头像 → `Settings`；
2. 左侧最底部 `Developer settings` → `Personal access tokens` → `Tokens (classic)`；
3. 点 `Generate new token` → `Generate new token (classic)`；
4. Note 填 `personal-site`（随便写，方便认）；
5. Expiration 选 `No expiration`（或 90 天，到期再换）；
6. 勾选权限：**`repo`**（整个大类勾上即可，包含 repo:status、repo_deployment 等）；
7. 点 `Generate token`，**立刻复制那串 `ghp_` 开头的字符串**（页面只显示一次）。

### 2. 配置到本地（交给助手执行 / 或自己执行）
把令牌告诉我，我在本地配置 HTTPS 凭据，之后推送不再要密码：

```bash
# 令牌通过凭据管理器保存，推送时自动使用
git config --global credential.helper manager
# 首次 push 时，用户名填 GitHub 用户名，密码处粘贴令牌（不是账号密码）
```

或者在本地 Windows 的「凭据管理器 → Windows 凭据」里添加一条：`git:https://github.com`，用户名填 GitHub 用户名，密码填令牌。

> ⚠️ 令牌等同于密码，不要写进代码、不要提交到仓库、不要发给别人。只是本次配置临时给我用，用完你可随时在 GitHub 后台 Revoke（吊销）。

---

## 方式 B：GitHub CLI（命令行登录，最规范）

### 1. 安装（Windows）
- 用 winget：`winget install --id GitHub.cli`
- 或下载安装包：https://cli.github.com/
- 验证：`gh --version`

### 2. 登录
```bash
gh auth login
```
按提示选：`GitHub.com` → `HTTPS` → `Login with a web browser`，复制设备码、在浏览器粘贴授权即可。

### 3. 之后推送
配置好后，`git push` 会自动用 CLI 的登录态，无需令牌。

---

## 三、选 A 还是 B？

| 你的情况 | 建议 |
| --- | --- |
| 只推这一个仓库，图快 | A（PAT） |
| 以后会经常用 GitHub、想规范 | B（CLI） |
| 不想把令牌发给任何人 | B（CLI，走浏览器授权） |

---

## 常见错误

| 报错 | 原因 |
| --- | --- |
| `Authentication failed` | 令牌填错 / 用了账号密码 / 令牌没勾 `repo` 权限 |
| `Password authentication removed` | GitHub 不支持密码了，必须用令牌 |
| 令牌泄露担心 | 去 GitHub `Settings → Developer settings → Tokens` 点 Revoke 立即作废 |
