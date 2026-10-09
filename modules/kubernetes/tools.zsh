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
  namespaces=()
  if [[ -n "$output" ]]; then
    namespaces=("${(@f)output}")
  fi

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

# Discover an API resource, select an object, and describe it.
kd() {
  _zsh_tools_require_kubectl || return

  local scope namespace='' resource resource_name output namespaced
  local -a scopes resource_types names
  scopes=(namespaced cluster)

  _zsh_tools_choose '请选择资源范围：' "${scopes[@]}" || return
  scope="$REPLY"
  if [[ "$scope" == namespaced ]]; then
    namespaced=true
    _zsh_tools_select_namespace || return
    namespace="$REPLY"
  else
    namespaced=false
  fi

  if ! output="$(command kubectl api-resources --verbs=get,list \
    --namespaced="$namespaced" -o name)"; then
    print -u2 "Error: failed to discover $scope Kubernetes resources."
    return 1
  fi
  resource_types=()
  if [[ -n "$output" ]]; then
    resource_types=("${(@f)output}")
  fi
  if ((${#resource_types[@]} == 0)); then
    print "没有发现可查看的 $scope Kubernetes 资源。"
    return 1
  fi

  _zsh_tools_choose '请选择资源类型：' "${resource_types[@]}" || return
  resource="$REPLY"

  if [[ "$scope" == namespaced ]]; then
    if ! output="$(command kubectl get "$resource" --namespace "$namespace" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
      print -u2 "Error: failed to query $resource in namespace '$namespace'."
      return 1
    fi
  else
    if ! output="$(command kubectl get "$resource" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
      print -u2 "Error: failed to query cluster resource $resource."
      return 1
    fi
  fi
  names=()
  if [[ -n "$output" ]]; then
    names=("${(@f)output}")
  fi

  if ((${#names[@]} == 0)); then
    if [[ "$scope" == namespaced ]]; then
      print "namespace '$namespace' 中没有找到 $resource。"
    else
      print "集群中没有找到 $resource。"
    fi
    return 1
  fi

  _zsh_tools_choose "请选择要查看的 $resource：" "${names[@]}" || return
  resource_name="$REPLY"
  if [[ "$scope" == namespaced ]]; then
    command kubectl describe "$resource" "$resource_name" --namespace "$namespace"
  else
    command kubectl describe "$resource" "$resource_name"
  fi
}

# Select a running Pod in a namespace and return it in REPLY.
_zsh_tools_select_running_pod() {
  local namespace="$1" output
  local -a pods
  if ! output="$(command kubectl get pods --namespace "$namespace" \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"; then
    print -u2 "Error: failed to query Pods in namespace '$namespace'."
    return 1
  fi
  pods=()
  if [[ -n "$output" ]]; then
    pods=("${(@f)output}")
  fi

  if ((${#pods[@]} == 0)); then
    print "namespace '$namespace' 中没有运行中的 Pod。"
    return 1
  fi

  _zsh_tools_choose "请选择 $namespace 中的 Pod：" "${pods[@]}" || return
}

# Select a container in a Pod and return it in REPLY.
_zsh_tools_select_container() {
  local namespace="$1" pod="$2" output
  local -a containers
  if ! output="$(command kubectl get pod "$pod" --namespace "$namespace" \
    -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}')"; then
    print -u2 "Error: failed to query containers in Pod '$pod'."
    return 1
  fi
  containers=()
  if [[ -n "$output" ]]; then
    containers=("${(@f)output}")
  fi

  if ((${#containers[@]} == 0)); then
    print "Pod '$pod' 中没有找到容器。"
    return 1
  elif ((${#containers[@]} == 1)); then
    REPLY="${containers[1]}"
  else
    _zsh_tools_choose "请选择 $pod 中的容器：" "${containers[@]}"
  fi
}

# Select a namespace, running Pod, and container, then enter its shell.
ksh() {
  _zsh_tools_require_kubectl || return

  local namespace pod container
  _zsh_tools_select_namespace || return
  namespace="$REPLY"
  _zsh_tools_select_running_pod "$namespace" || return
  pod="$REPLY"
  _zsh_tools_select_container "$namespace" "$pod" || return
  container="$REPLY"

  print "正在进入 $namespace/$pod（容器：$container）……"
  command kubectl exec --stdin --tty --namespace "$namespace" "$pod" \
    --container "$container" -- sh
}

# Select a Pod and container, then show its logs.
kl() {
  _zsh_tools_require_kubectl || return

  local follow=false previous=false tail_lines=200 since=''
  while (($#)); do
    case "$1" in
      -f|--follow)
        follow=true
        shift
        ;;
      -p|--previous)
        previous=true
        shift
        ;;
      --tail)
        (($# >= 2)) || {
          print -u2 'Error: --tail requires a positive integer.'
          return 2
        }
        tail_lines="$2"
        shift 2
        ;;
      --since)
        (($# >= 2)) || {
          print -u2 'Error: --since requires a duration such as 10m or 1h.'
          return 2
        }
        since="$2"
        shift 2
        ;;
      --help|-h)
        print 'Usage: kl [-f|--follow] [-p|--previous] [--tail LINES] [--since DURATION]'
        return 0
        ;;
      *)
        print -u2 "Error: unknown kl option: $1"
        return 2
        ;;
    esac
  done

  [[ "$tail_lines" == <-> && "$tail_lines" -gt 0 ]] || {
    print -u2 'Error: --tail requires a positive integer.'
    return 2
  }
  if [[ "$follow" == true && "$previous" == true ]]; then
    print -u2 'Error: --follow and --previous cannot be used together.'
    return 2
  fi

  local namespace pod container
  local -a args
  _zsh_tools_select_namespace || return
  namespace="$REPLY"
  _zsh_tools_select_running_pod "$namespace" || return
  pod="$REPLY"
  _zsh_tools_select_container "$namespace" "$pod" || return
  container="$REPLY"

  args=(logs --namespace "$namespace" "$pod" --container "$container" --tail "$tail_lines")
  [[ -n "$since" ]] && args+=(--since "$since")
  [[ "$previous" == true ]] && args+=(--previous)
  [[ "$follow" == true ]] && args+=(--follow)
  command kubectl "${args[@]}"
}
