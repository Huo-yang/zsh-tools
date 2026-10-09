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

通过 Kubernetes API discovery 动态读取当前集群支持的资源，然后执行 `kubectl describe`。可以选择：

- namespace 范围的资源，例如 Pod、Deployment、StatefulSet、DaemonSet、Service、Ingress、ConfigMap、Secret、Job、CronJob、PVC 和 ServiceAccount。
- 集群范围的资源，例如 Node、Namespace、PersistentVolume、StorageClass、ClusterRole 和 CustomResourceDefinition。

支持范围不使用硬编码列表，因此能覆盖当前 Kubernetes 版本公开的全部可读取资源，也会包含集群中已经安装的 CRD。查看 Secret 时只调用 `kubectl describe`，不会自动解码或打印 Secret 数据。

### `ksh`

依次选择 namespace、运行中的 Pod 和容器。默认通过 `sh` 进入容器：

```zsh
ksh
```

容器中安装了 Bash 时，可以明确指定：

```zsh
ksh --bash
ksh -b
```

命令不会在 Bash 不存在时自动回退，`kubectl exec` 会直接显示容器返回的错误。使用 `ksh` 而不是 `kexec`，可以避免覆盖 Linux 原生的 `kexec` 系统命令。

### `kl`

依次选择 namespace、运行中的 Pod 和容器，然后查看日志。默认显示最近 200 行：

```zsh
kl
```

支持常用日志参数：

```zsh
kl --tail 500
kl --since 10m
kl -f
kl --previous
```

`--follow` 和 `--previous` 不能同时使用，避免产生无效的 `kubectl logs` 调用。

如果没有安装 `kubectl`，命令会返回明确错误；如果集群查询失败，会保留 `kubectl` 的原始错误并停止，不会误报为资源为空。

## WSL proxy

### `wsl_proxy_on`

从 WSL 默认路由读取 Windows 主机地址，并为当前 Zsh 会话设置端口 `7890` 的 HTTP 和 HTTPS 代理。

### `wsl_proxy_off`

清除当前会话中的常见代理环境变量。两个代理命令都不会修改 Windows 系统代理。
