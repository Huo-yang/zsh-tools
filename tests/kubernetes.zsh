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

print -l 1 1 2 1 | kd >/dev/null
grep -Fqx 'describe deployments api --namespace dev' "$MOCK_KUBECTL_LOG"

export MOCK_EMPTY_RESOURCE=deployments
typeset empty_output
if empty_output="$(print -l 1 1 2 | kd 2>&1)"; then
  print -u2 'Empty resource test unexpectedly succeeded.'
  return 1
fi
[[ "$empty_output" == *"namespace 'dev' 中没有找到 deployments。"* ]]
unset MOCK_EMPTY_RESOURCE

print -l 1 1 3 1 | kd >/dev/null
grep -Fqx 'describe configmaps application --namespace dev' "$MOCK_KUBECTL_LOG"

print -l 1 1 4 1 | kd >/dev/null
grep -Fqx 'describe secrets credentials --namespace dev' "$MOCK_KUBECTL_LOG"

print -l 2 1 1 | kd >/dev/null
grep -Fqx 'describe nodes node-a' "$MOCK_KUBECTL_LOG"

print -l 1 2 1 | ksh >/dev/null
grep -Fqx 'exec --stdin --tty --namespace dev pod-b --container app -- sh' \
  "$MOCK_KUBECTL_LOG"

print -l 1 1 2 | ksh --bash >/dev/null
grep -Fqx 'exec --stdin --tty --namespace dev pod-a --container sidecar -- bash' \
  "$MOCK_KUBECTL_LOG"

if ksh --zsh >/dev/null 2>&1; then
  print -u2 'Unknown ksh option test failed.'
  return 1
fi

print -l 1 2 1 | kl --tail 50 --since 10m >/dev/null
grep -Fqx 'logs --namespace dev pod-b --container app --tail 50 --since 10m' \
  "$MOCK_KUBECTL_LOG"

print -l 1 1 2 | kl --follow >/dev/null
grep -Fqx 'logs --namespace dev pod-a --container sidecar --tail 200 --follow' \
  "$MOCK_KUBECTL_LOG"

if kl --follow --previous >/dev/null 2>&1; then
  print -u2 'Incompatible log options test failed.'
  return 1
fi

if whence -w kexec >/dev/null 2>&1; then
  print -u2 'kexec must not be defined by the Kubernetes module.'
  return 1
fi

print 'Kubernetes helper tests passed.'
