---
name: hexo-blog-publisher
description: 为 Hexo 博客提供“写作/改稿/预览/发布”一体化流程。用户提出写博客、改博客、保存到 Hexo `source/_posts`、发布文章到远端仓库时使用。执行顺序为：生成或修改 Markdown → 导出预览并等待确认 → SSH 连通性检查 → 仅在当次明确授权后执行 git push。
---

# Hexo Blog Publisher

按以下顺序执行，禁止跳过“预览确认”。

## 1) 加载配置

1. 进入目录：`skills/hexo-blog-publisher`
2. 读取 `.env`（不存在时先从 `.env.example` 复制）。
3. 关键字段：
   - `BLOG_REPO_PATH`：Hexo 仓库本地路径（默认 `~/blog`）
   - `POSTS_SUBDIR`：文章目录（默认 `source/_posts`）
   - `EXPORT_DIR`：预览导出目录
   - `REPO_SSH_URL`：远端 SSH 地址
   - `REMOTE_NAME` / `BRANCH`：推送目标

## 2) 生成或修改文章

1. 根据用户要求生成或修改 Markdown。
2. front-matter 参考：`references/frontmatter-template.md`。
   - 支持 `cover`（封面图）与 `top_img`（顶图）字段。
   - 文章图床调用 `cfbed-upload-skill` 上传图片，将返回 URL 插入文章（front-matter 的 `cover/top_img` 或正文 Markdown 引用）。
3. 文章落盘路径：`$BLOG_REPO_PATH/$POSTS_SUBDIR/<slug>.md`。

## 3) 写作风格与配图约束（必须执行）

1. 文章可以围绕明确问题/主题展开，开头先回答两件事：
   - 这篇文章解决什么问题
   - 读完能获得什么
2. 标题必须具体、可执行，避免泛标题。
3. 结构要求清晰，可参考这些信息层：
   - 简介（问题与目标）
   - 背景/原理
   - 实现步骤
   - 代码示例
   - 结果/效果
   - 常见问题/坑点
   - 总结与延伸阅读
4. 代码与示例可操作：给出完整可运行最小示例，并解释关键代码（做了什么 + 为什么这样做）。
5. 不能只写步骤，必须解释原理与取舍（至少覆盖“为什么这样做/与替代方案差异”）。
6. 必须包含实践经验：常见错误、性能注意点、生产建议（如适用）。
7. 结尾必须有总结：核心要点回收、适用场景、下一步学习建议。
8. 信息完整性不可缺项。
9. 配图不得仅限流程图/思维导图；优先混合使用多种素材：
   - 界面截图（关键步骤）
   - 命令输出/日志片段图
   - 对比图（改造前后）
   - 架构示意图
   - 数据图表或时间线（有数据时）
10. 每张图必须服务叙事（解释“为什么要看这张图”），避免装饰性堆图。

## 4) 预览并等待确认

1. 将预览版 `.md` 同步到 `$EXPORT_DIR`。
2. 默认以 `.md` 文件形式直接发送给用户（不要只贴路径，也不要在消息里贴全文）。
3. 附一句简短说明并明确询问是否推送远端。
4. 未收到当次明确“推送/发布/push”指令前，只允许本地修改，不得推送。

## 5) 推送前检查

运行：

```bash
bash scripts/check_ssh.sh
```

- `SSH_OK|...`：允许继续。
- `SSH_FAIL|...` / `SSH_CONFIG_*`：停止推送，先修复。

## 6) 推送（仅当次授权）

收到当次明确授权后运行：

```bash
bash scripts/push_post.sh <post_filename_or_path> "<commit_message>"
```

常见返回：

- `PUSH_OK|...`：推送成功。
- `NO_CHANGES|...`：文章无改动，不会空提交。
- `REPO_NOT_FOUND|...`：本地仓库缺失，按提示先 clone。
- `NOT_A_GIT_REPO|...` / `POST_NOT_FOUND|...` / `POST_OUTSIDE_REPO|...`：按错误提示修复后重试。

## 7) 安全约束

- 推送必须“当次确认”，禁止复用历史授权。
- 默认只提交目标文章，不顺带提交其他文件。
- 执行 push 前先复述将要推送的文件名与分支。
