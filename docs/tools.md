# 工具说明

## Core aliases

| 命令 | 实际执行 | 用途 |
| --- | --- | --- |
| `ls` | `ls --color=auto` | 自动启用彩色输出 |
| `grep` | `grep --color=auto` | 自动高亮匹配结果 |
| `ll` | `ls -alF` | 显示包含隐藏文件的详细列表 |
| `la` | `ls -A` | 显示除 `.` 和 `..` 之外的文件 |
| `l` | `ls -CF` | 紧凑显示目录内容 |

## Kubernetes

### `kgp`

显示 namespace 编号菜单，选择后执行：

```zsh
kubectl get pods --namespace <namespace> --output wide
```

### `kd`

依次选择 namespace、资源类型和资源，然后执行 `kubectl describe`。当前支持：

- Pod
- Deployment
- StatefulSet
- Service
- Ingress
- PVC

### `ksh`

依次选择 namespace、运行中的 Pod 和容器，然后通过 `sh` 进入容器。使用 `ksh` 而不是 `kexec`，避免覆盖 Linux 原生的 `kexec` 系统命令。

如果没有安装 `kubectl`，命令会返回明确错误；如果集群查询失败，会保留 `kubectl` 的原始错误并停止，不会误报为资源为空。

## WSL proxy

### `wsl_proxy_on`

从 WSL 默认路由读取 Windows 主机地址，并为当前 Zsh 会话设置端口 `7890` 的 HTTP 和 HTTPS 代理。

### `wsl_proxy_off`

清除当前会话中的常见代理环境变量。两个代理命令都不会修改 Windows 系统代理。
