# 模块开发约定

每个模块位于 `modules/<module-id>/`，包含：

```text
module.zsh
tools.zsh
```

`module.zsh` 声明模块名称、公开命令、依赖和支持平台；`tools.zsh` 实现函数或别名。

如果 alias 有意覆盖同名系统命令，例如 `ls`，需要把名称登记到 `MODULE_ALLOW_COMMAND_SHADOWS`。函数默认不能静默覆盖系统命令。

开发要求：

- 脚本只面向 Zsh。
- 代码注释、标识符、错误信息和 commit message 使用英文。
- Markdown 文档使用中文。
- 公开命令必须登记在 `MODULE_COMMANDS`。
- 外部命令必须登记在 `MODULE_DEPENDENCIES`。
- 工具运行时应再次校验关键依赖。
- 提交前运行 `zsh tests/run.zsh`。
