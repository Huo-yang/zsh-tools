#!/usr/bin/env zsh

# Verify interactive Kubernetes helpers with a fake kubectl executable.
emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -gr repository_root="${0:A:h:h}"
typeset -g test_root
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

export MOCK_KUBECTL_LOG="$test_root/kubectl.log"
export PATH="$repository_root/tests/fixtures:$PATH"
touch "$MOCK_KUBECTL_LOG"

source "$repository_root/modules/kubernetes/tools.zsh"

print -l 1 2 1 | kd >/dev/null
grep -Fqx 'describe deployments api --namespace dev' "$MOCK_KUBECTL_LOG"

print -l 1 2 1 | ksh >/dev/null
grep -Fqx 'exec --stdin --tty --namespace dev pod-b --container app -- sh' \
  "$MOCK_KUBECTL_LOG"

if whence -w kexec >/dev/null 2>&1; then
  print -u2 'kexec must not be defined by the Kubernetes module.'
  return 1
fi

print 'Kubernetes helper tests passed.'
