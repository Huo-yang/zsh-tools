# Show a numbered selection menu.
_zsh_tools_choose() {
  local prompt="$1"
  shift
  local choice i
  local -a entries=("$@")

  print -- "$prompt"
  for ((i = 1; i <= ${#entries[@]}; i++)); do
    printf '%-3d %-24s' "$i" "${entries[i]}"
    ((i % 4 == 0)) && printf '\n'
  done
  ((${#entries[@]} % 4 != 0)) && printf '\n'

  while true; do
    printf '输入编号（或 Ctrl+C 取消）：'
    read -r choice || return 1
    if [[ "$choice" == <-> ]] && ((choice >= 1 && choice <= ${#entries[@]})); then
      REPLY="${entries[choice]}"
      return 0
    fi
    print '编号无效，请重新选择。'
  done
}

# Verify that kubectl is available before running a helper.
_zsh_tools_require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    print -u2 'Error: kubectl is not installed or not available in PATH.'
    return 127
  fi
}

# Select a Kubernetes namespace and return it in REPLY.
_zsh_tools_select_namespace() {
  local output
  local -a namespaces
  if ! output="$(command kubectl get namespaces \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
    print -u2 'Error: failed to query Kubernetes namespaces.'
    return 1
  fi
  namespaces=("${(@f)output}")

  if ((${#namespaces[@]} == 0)); then
    print '没有找到 namespace。'
    return 1
  fi

  _zsh_tools_choose '请选择 namespace：' "${namespaces[@]}"
}

# Select a namespace and show its Pods.
kgp() {
  _zsh_tools_require_kubectl || return

  local namespace
  _zsh_tools_select_namespace || return
  namespace="$REPLY"
  command kubectl get pods --namespace "$namespace" --output wide
}

# Select a namespaced resource and describe it.
kd() {
  _zsh_tools_require_kubectl || return

  local namespace resource resource_name output
  local -a resource_types names
  resource_types=(
    pods
    deployments
    statefulsets
    services
    ingresses
    persistentvolumeclaims
  )

  _zsh_tools_select_namespace || return
  namespace="$REPLY"
  _zsh_tools_choose '请选择资源类型：' "${resource_types[@]}" || return
  resource="$REPLY"

  if ! output="$(command kubectl get "$resource" --namespace "$namespace" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
    print -u2 "Error: failed to query $resource in namespace '$namespace'."
    return 1
  fi
  names=("${(@f)output}")

  if ((${#names[@]} == 0)); then
    print "namespace '$namespace' 中没有找到 $resource。"
    return 1
  fi

  _zsh_tools_choose "请选择要查看的 $resource：" "${names[@]}" || return
  resource_name="$REPLY"
  command kubectl describe "$resource" "$resource_name" --namespace "$namespace"
}

# Select a namespace, running Pod, and container, then enter its shell.
ksh() {
  _zsh_tools_require_kubectl || return

  local namespace pod container output
  local -a pods containers
  _zsh_tools_select_namespace || return
  namespace="$REPLY"

  if ! output="$(command kubectl get pods --namespace "$namespace" \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
    print -u2 "Error: failed to query Pods in namespace '$namespace'."
    return 1
  fi
  pods=("${(@f)output}")

  if ((${#pods[@]} == 0)); then
    print "namespace '$namespace' 中没有运行中的 Pod。"
    return 1
  fi

  _zsh_tools_choose "请选择 $namespace 中的 Pod：" "${pods[@]}" || return
  pod="$REPLY"

  if ! output="$(command kubectl get pod "$pod" --namespace "$namespace" \
    -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}')"; then
    print -u2 "Error: failed to query containers in Pod '$pod'."
    return 1
  fi
  containers=("${(@f)output}")

  if ((${#containers[@]} == 0)); then
    print "Pod '$pod' 中没有找到容器。"
    return 1
  elif ((${#containers[@]} == 1)); then
    container="${containers[1]}"
  else
    _zsh_tools_choose "请选择 $pod 中的容器：" "${containers[@]}" || return
    container="$REPLY"
  fi

  print "正在进入 $namespace/$pod（容器：$container）……"
  command kubectl exec --stdin --tty --namespace "$namespace" "$pod" \
    --container "$container" -- sh
}
