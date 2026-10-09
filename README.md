# zsh-tools

`zsh-tools` 是一个面向 Zsh 的个人快捷工具管理器，用于把常用别名和函数按模块整理，并快速安装到新的 WSL 或 Linux 环境。

它不仅写入配置，还会检查命令冲突、外部依赖和实际加载结果，并明确区分“已经安装”和“当前可用”。

## 当前模块

| 模块 | 工具 | 外部依赖 |
| --- | --- | --- |
| `core` | `ls`、`grep`、`ll`、`la`、`l` | 无 |
| `kubernetes` | `kgp`、`kexec` | `kubectl` |
| `wsl-proxy` | `wsl_proxy_on`、`wsl_proxy_off` | `ip`、WSL |

## 快速开始

检查当前环境，不修改文件：

```zsh
zsh ./setup.zsh --check
```

打开交互式安装界面：

```zsh
zsh ./setup.zsh
```

也可以无交互安装指定模块：

```zsh
zsh ./setup.zsh --modules core,kubernetes
```

如果已有同名命令，安装默认停止。确认加载顺序后，可以显式允许本项目版本覆盖当前定义：

```zsh
zsh ./setup.zsh \
  --modules core,kubernetes,wsl-proxy \
  --allow-conflicts
```

该选项不会删除原定义。卸载 `zsh-tools` 后，原命令仍可恢复。

## 安装内容

安装器只管理以下内容：

- `~/.config/zsh-tools/` 中生成的加载配置。
- `~/.local/bin/zsh-tools` 管理命令软链接。
- `.zshrc` 中内容固定、逐字校验的一行加载入口。
- `~/.local/state/zsh-tools/` 中的状态、报告和备份。

安装前会备份 `.zshrc`。安装器不会自动安装或卸载 `kubectl` 等系统软件，也不会接管主题、提示符、历史记录等其他 Zsh 配置。

## 管理命令

安装并重新启动 Zsh 后，可以使用：

```zsh
zsh-tools status
zsh-tools list
zsh-tools doctor
zsh-tools enable kubernetes
zsh-tools disable kubernetes
zsh-tools uninstall
```

卸载只移除由本项目管理的配置，保留仓库、外部依赖、状态和备份。

## 状态含义

- `ready`：模块命令能够加载，外部依赖也已满足。
- `partial`：模块已经安装，但缺少外部依赖。
- `failed`：模块命令无法正确加载。

## 文档

- [工具说明](docs/tools.md)
- [安装与冲突处理](docs/installation.md)
- [模块开发约定](docs/development.md)
