#!/usr/bin/env zsh

# Run isolated installation lifecycle tests.
emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -gr repository_root="${0:A:h:h}"
typeset -g test_root
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

export HOME="$test_root/home"
export ZDOTDIR="$test_root/zdot"
export ZSH_TOOLS_CONFIG_HOME="$test_root/config/zsh-tools"
export ZSH_TOOLS_STATE_HOME="$test_root/state/zsh-tools"
export ZSH_TOOLS_BIN_HOME="$test_root/bin"
export ZSH_TOOLS_ZSHRC="$ZDOTDIR/.zshrc"

mkdir -p -- "$HOME" "$ZDOTDIR"
print '# Existing user configuration' > "$ZSH_TOOLS_ZSHRC"

local file
while IFS= read -r -d '' file; do
  zsh -n "$file"
done < <(find "$repository_root" -type f -name '*.zsh' ! -path '*/tests/*' -print0)
zsh -n "$repository_root/bin/zsh-tools"

(
  source "$repository_root/lib/zsh-tools.zsh"
  zt_registry_load
  kgp() { return 0; }
  if zt_install false kubernetes >/dev/null 2>&1; then
    print -u2 'Conflict test failed.'
    return 1
  fi
)

zsh "$repository_root/setup.zsh" \
  --modules core,kubernetes,wsl-proxy \
  --allow-conflicts

[[ -r "$ZSH_TOOLS_CONFIG_HOME/.managed-by-zsh-tools" ]]
[[ -L "$ZSH_TOOLS_BIN_HOME/zsh-tools" ]]
[[ "$(grep -Fxc '# >>> zsh-tools >>>' "$ZSH_TOOLS_ZSHRC")" == 1 ]]

zsh "$repository_root/setup.zsh" \
  --modules core,kubernetes,wsl-proxy \
  --allow-conflicts
[[ "$(grep -Fxc '# >>> zsh-tools >>>' "$ZSH_TOOLS_ZSHRC")" == 1 ]]

zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" status
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" doctor
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" disable kubernetes
! grep -q kubernetes "$ZSH_TOOLS_CONFIG_HOME/enabled-modules.zsh"
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" enable kubernetes
grep -q kubernetes "$ZSH_TOOLS_CONFIG_HOME/enabled-modules.zsh"

zsh "$repository_root/setup.zsh" --uninstall --yes
[[ ! -e "$ZSH_TOOLS_CONFIG_HOME" ]]
[[ ! -e "$ZSH_TOOLS_BIN_HOME/zsh-tools" ]]
! grep -Fq '# >>> zsh-tools >>>' "$ZSH_TOOLS_ZSHRC"
grep -Fq '# Existing user configuration' "$ZSH_TOOLS_ZSHRC"

mkdir -p -- "$ZSH_TOOLS_CONFIG_HOME"
print 'foreign configuration' > "$ZSH_TOOLS_CONFIG_HOME/user-file"
if zsh "$repository_root/setup.zsh" --modules core >/dev/null 2>&1; then
  print -u2 'Path conflict test failed.'
  return 1
fi
rm -- "$ZSH_TOOLS_CONFIG_HOME/user-file"
rmdir -- "$ZSH_TOOLS_CONFIG_HOME"

print 'All tests passed.'
