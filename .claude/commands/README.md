# Claude Code Commands

本目录包含自定义 Claude Code 斜杠命令。

## 可用命令

| 命令 | 描述 | 文件 |
|------|------|------|
| `/simplify` | 检查并简化代码，遵循 Unix 哲学 | [simplify.md](./simplify.md) |
| `/review` | 全面代码审查，发现潜在问题 | [review.md](./review.md) |
| `/format` | 格式化代码，统一代码风格 | [format.md](./format.md) |

## 命令格式

支持两种格式：

### Markdown 格式（推荐）
```markdown
# /command-name

**描述**: 命令功能简述
**哲学**: 可选的指导原则

---

## 用法
```
/command [参数]
```

## 功能说明
...
```

### JSON 格式（可选）
```json
{
  "name": "/command",
  "description": "...",
  "args": [...]
}
```

## 使用示例

```bash
# 简化当前文件
/simplify

# 简化指定文件
/simplify messy_code.R

# 审查代码
/review --focus=security

# 格式化代码
/format --apply
```

## 添加新命令

1. 在 `.claude/commands/` 创建 `{name}.md`
2. 以 `# /{name}` 开头
3. 定义描述、用法和功能说明
4. 重启 Claude Code 生效
