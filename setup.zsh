#!/usr/bin/env zsh

# Interactive and automated entry point for zsh-tools.
emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -gr ZSH_TOOLS_ROOT="${0:A:h}"
source "$ZSH_TOOLS_ROOT/lib/zsh-tools.zsh"
zt_registry_load

usage() {
  print 'Usage: zsh ./setup.zsh [options]'
  print
  print 'Options:'
  print '  --modules <ids>     Install comma-separated modules'
  print '  --allow-conflicts   Allow selected tools to override loaded commands'
  print '  --check             Inspect modules and dependencies without changes'
  print '  --uninstall         Remove the managed installation'
  print '  --yes               Skip uninstall confirmation'
  print '  --help              Show this help'
}

show_check() {
  local id missing conflicts platform
  platform="$(zt_platform)"
  print "zsh-tools module check ($platform)"
  print
  for id in "${ZT_MODULES[@]}"; do
    print "${ZT_MODULE_NAME[$id]} [$id]"
    print "  Commands: ${ZT_MODULE_COMMANDS[$id]}"
    if zt_module_supported "$id"; then
      print '  Platform: supported'
    else
      print "  Platform: unsupported (${ZT_MODULE_PLATFORMS[$id]})"
    fi
    missing="$(zt_module_missing_dependencies "$id")"
    [[ -z "$missing" ]] && print '  Dependencies: ready' ||
      print "  Dependencies: missing $missing"
    conflicts="$(zt_command_conflicts "$id")"
    [[ -z "$conflicts" ]] && print '  Conflicts: none' ||
      print "  Conflicts: $conflicts"
    print
  done
}

interactive_select() {
  local -a selected=()
  local id input item index
  for id in "${ZT_MODULES[@]}"; do
    zt_module_supported "$id" && selected+=("$id")
  done

  while true; do
    print
    print '┌────────────────────────────────────────────────────────────┐'
    print '│ zsh-tools installer                                        │'
    print '├────────────────────────────────────────────────────────────┤'
    index=1
    for id in "${ZT_MODULES[@]}"; do
      local mark=' ' note=''
      (( ${selected[(Ie)$id]} )) && mark='x'
      zt_module_supported "$id" || note='unsupported'
      local missing="$(zt_module_missing_dependencies "$id")"
      [[ -n "$missing" ]] && note="missing: $missing"
      printf '│ %d. [%s] %-16s %-27s │\n' "$index" "$mark" "$id" "$note"
      ((index++))
    done
    print '├────────────────────────────────────────────────────────────┤'
    print '│ 输入编号切换，a 全选，n 清空，Enter 安装，q 退出            │'
    print '└────────────────────────────────────────────────────────────┘'
    printf '> '
    read -r input || return 1

    case "$input" in
      '') break ;;
      q|Q) return 1 ;;
      a|A)
        selected=()
        for id in "${ZT_MODULES[@]}"; do
          zt_module_supported "$id" && selected+=("$id")
        done
        ;;
      n|N) selected=() ;;
      *)
        for item in ${(s:,:)input}; do
          [[ "$item" == <-> ]] || continue
          ((item >= 1 && item <= ${#ZT_MODULES[@]})) || continue
          id="${ZT_MODULES[$item]}"
          zt_module_supported "$id" || continue
          index="${selected[(Ie)$id]}"
          if ((index)); then
            selected[$index]=()
          else
            selected+=("$id")
          fi
        done
        ;;
    esac
  done

  ((${#selected[@]})) || {
    zt_error 'No modules selected.'
    return 1
  }
  reply=("${selected[@]}")
}

confirm_conflicts() {
  local -a modules=("$@")
  local id conflicts found=false answer
  for id in "${modules[@]}"; do
    conflicts="$(zt_command_conflicts "$id")"
    if [[ -n "$conflicts" ]]; then
      zt_warn "${ZT_MODULE_NAME[$id]} conflicts with: $conflicts"
      found=true
    fi
  done
  [[ "$found" == false ]] && return 1
  print 'zsh-tools can load after the existing definitions without deleting them.'
  printf '输入 yes 允许本次覆盖，否则取消：'
  read -r answer
  [[ "$answer" == yes ]]
}

main() {
  local action=install modules_csv='' allow_conflicts=false assume_yes=false
  while (($#)); do
    case "$1" in
      --modules)
        (($# >= 2)) || { zt_error '--modules requires a value.'; return 2; }
        modules_csv="$2"
        shift 2
        ;;
      --allow-conflicts) allow_conflicts=true; shift ;;
      --check) action=check; shift ;;
      --uninstall) action=uninstall; shift ;;
      --yes) assume_yes=true; shift ;;
      --help|-h) usage; return 0 ;;
      *) zt_error "Unknown option: $1"; usage; return 2 ;;
    esac
  done

  case "$action" in
    check)
      show_check
      ;;
    uninstall)
      if [[ "$assume_yes" != true ]]; then
        local answer
        printf '卸载 zsh-tools 管理的配置？仓库和外部依赖会保留。[y/N] '
        read -r answer
        [[ "$answer" == [yY] ]] || { zt_info 'Cancelled.'; return 0; }
      fi
      zt_uninstall
      ;;
    install)
      local -a modules=()
      if [[ -n "$modules_csv" ]]; then
        modules=(${(s:,:)modules_csv})
      else
        typeset -ga reply=()
        interactive_select || return
        modules=("${reply[@]}")
        if [[ "$allow_conflicts" != true ]] && confirm_conflicts "${modules[@]}"; then
          allow_conflicts=true
        fi
      fi
      zt_install "$allow_conflicts" "${modules[@]}"
      ;;
  esac
}

main "$@"
