# hexo-blog-publisher

一个给 OpenClaw / Hexo 用的博客发布 skill，目标是把“写作 → 本地预览 → SSH 检查 → 当次授权 → git push”串成一条可控写作流。

仓库：`~/project/hexo-blog-publisher`

## 包含内容

- `SKILL.md`：skill 主流程说明
- `scripts/start_preview.sh`：清理 4000 端口占用并启动本地 Hexo 预览
- `scripts/check_ssh.sh`：推送前 SSH 连通性检查
- `scripts/push_post.sh`：只提交目标文章并执行推送
- `references/frontmatter-template.md`：Hexo front-matter 模板
- `.env.example`：配置示例

## 当前工作流

1. 生成或修改文章到 Hexo 仓库 `source/_posts`
2. 执行本地预览脚本：先检查并清理 `4000` 端口占用
3. 在博客目录执行：`hexo clean && hexo g && hexo s`
4. 提示用户打开 `http://localhost:4000` 查看预览
5. 用户当次明确授权后，再执行 SSH 检查与 `git push`

## 特点

- 默认走 `localhost:4000` 本地站点预览，不再发送 `.md` 预览文件
- 预览前自动处理 4000 端口占用
- 推送前先做 SSH 检查
- 只提交目标文章，避免误提交其他文件
- 支持 Hexo `source/_posts` 工作流
- 适合 OpenClaw 自动生成文章后的可控发布流程

## 配置

复制 `.env.example` 为 `.env`，按需修改：

```bash
BLOG_REPO_PATH=~/project/blog
POSTS_SUBDIR=source/_posts
PREVIEW_HOST=localhost
PREVIEW_PORT=4000
PREVIEW_LOG_DIR=~/tmp
REPO_SSH_URL=git@github.com:yourname/your-blog.git
REMOTE_NAME=origin
BRANCH=master
```

## 用法

### 1. 启动本地预览

```bash
bash scripts/start_preview.sh
```

成功时返回：

```text
PREVIEW_OK|http://localhost:4000|<pid>|<log_file>
```

### 2. 检查 SSH

```bash
bash scripts/check_ssh.sh
```

### 3. 推送目标文章

```bash
bash scripts/push_post.sh <post_filename_or_path> "<commit_message>"
```

## 约束

- 未收到当次明确授权前，不应执行 push
- 默认只提交目标文章，不顺带提交其他文件
- 执行 push 前先复述将要推送的文件名与分支
- 预览服务默认仅用于本地确认；若要开放给其他设备，应单独明确配置

## License

MIT
