# hexo-blog-publisher

一个给 OpenClaw / Hexo 用的博客发布 skill，目标是把“写作 → 预览 → SSH 检查 → 当次授权 → git push”串成一条可控写作流。

## 包含内容

- `SKILL.md`：skill 主流程说明
- `scripts/check_ssh.sh`：推送前 SSH 连通性检查
- `scripts/push_post.sh`：只提交目标文章并执行推送
- `references/frontmatter-template.md`：Hexo front-matter 模板
- `.env.example`：配置示例

## 特点

- 强制预览确认，不跳过发布门禁
- 推送前先做 SSH 检查
- 只提交目标文章，避免误提交其他文件
- 支持 Hexo `source/_posts` 工作流
- 适合 OpenClaw 自动生成文章后的可控发布流程

## 配置

复制 `.env.example` 为 `.env`，按需修改：

```bash
BLOG_REPO_PATH=~/blog
POSTS_SUBDIR=source/_posts
EXPORT_DIR=~/.openclaw/workspace/tmp
REPO_SSH_URL=git@github.com:yourname/your-blog.git
REMOTE_NAME=origin
BRANCH=master
```

## 用法

### 1. 检查 SSH

```bash
bash scripts/check_ssh.sh
```

### 2. 推送目标文章

```bash
bash scripts/push_post.sh <post_filename_or_path> "<commit_message>"
```

## 约束

- 未收到当次明确授权前，不应执行 push
- 默认只提交目标文章，不顺带提交其他文件
- 发布前建议先发送 `.md` 预览稿给用户确认

## License

MIT
