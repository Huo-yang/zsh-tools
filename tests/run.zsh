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
[[ "$(grep -Fc '# managed by zsh-tools' "$ZSH_TOOLS_ZSHRC")" == 1 ]]

cp -p -- "$ZSH_TOOLS_ZSHRC" "$test_root/zshrc-valid"
sed -i 's/^\[\[/true; [[/' "$ZSH_TOOLS_ZSHRC"
if zsh "$repository_root/setup.zsh" --modules core --allow-conflicts >/dev/null 2>&1; then
  print -u2 'Modified entry install test failed.'
  return 1
fi
if zsh "$repository_root/setup.zsh" --uninstall --yes >/dev/null 2>&1; then
  print -u2 'Modified entry uninstall test failed.'
  return 1
fi
cp -p -- "$test_root/zshrc-valid" "$ZSH_TOOLS_ZSHRC"

zsh "$repository_root/setup.zsh" \
  --modules core,kubernetes,wsl-proxy \
  --allow-conflicts
[[ "$(grep -Fc '# managed by zsh-tools' "$ZSH_TOOLS_ZSHRC")" == 1 ]]

zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" status
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" doctor
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" disable kubernetes
! grep -q kubernetes "$ZSH_TOOLS_CONFIG_HOME/enabled-modules.zsh"
zsh "$ZSH_TOOLS_BIN_HOME/zsh-tools" enable kubernetes
grep -q kubernetes "$ZSH_TOOLS_CONFIG_HOME/enabled-modules.zsh"

zsh "$repository_root/setup.zsh" --uninstall --yes
[[ ! -e "$ZSH_TOOLS_CONFIG_HOME" ]]
[[ ! -e "$ZSH_TOOLS_BIN_HOME/zsh-tools" ]]
! grep -Fq '# managed by zsh-tools' "$ZSH_TOOLS_ZSHRC"
grep -Fq '# Existing user configuration' "$ZSH_TOOLS_ZSHRC"

mv -- "$ZSH_TOOLS_ZSHRC" "$ZDOTDIR/real-zshrc"
ln -s -- "$ZDOTDIR/real-zshrc" "$ZSH_TOOLS_ZSHRC"
zsh "$repository_root/setup.zsh" --modules core --allow-conflicts >/dev/null
[[ -L "$ZSH_TOOLS_ZSHRC" ]]
zsh "$repository_root/setup.zsh" --uninstall --yes >/dev/null
[[ -L "$ZSH_TOOLS_ZSHRC" ]]
grep -Fq '# Existing user configuration' "$ZDOTDIR/real-zshrc"

mkdir -p -- "$ZSH_TOOLS_CONFIG_HOME"
print 'foreign configuration' > "$ZSH_TOOLS_CONFIG_HOME/user-file"
if zsh "$repository_root/setup.zsh" --modules core >/dev/null 2>&1; then
  print -u2 'Path conflict test failed.'
  return 1
fi
rm -- "$ZSH_TOOLS_CONFIG_HOME/user-file"
rmdir -- "$ZSH_TOOLS_CONFIG_HOME"

print 'All tests passed.'
