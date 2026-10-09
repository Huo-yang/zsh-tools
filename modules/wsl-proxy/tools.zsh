# Enable proxy variables for the current Zsh session.
wsl_proxy_on() {
  if ! command -v ip >/dev/null 2>&1; then
    print -u2 'Error: ip is not installed or not available in PATH.'
    return 127
  fi

  local host
  host="$(command ip route show default | sed -n 's|^default via \([^ ]*\).*|\1|p' | head -n1)"
  if [[ -z "$host" ]]; then
    print -u2 'Error: unable to determine the WSL host address.'
    return 1
  fi

  export HTTP_PROXY="http://${host}:7890"
  export HTTPS_PROXY="$HTTP_PROXY"
  export http_proxy="$HTTP_PROXY"
  export https_proxy="$HTTPS_PROXY"
  export NO_PROXY='localhost,127.0.0.1,::1,.localhost,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,192.168.49.0/24'
  export no_proxy="$NO_PROXY"
  print "WSL proxy enabled: $HTTP_PROXY"
}

# Disable proxy variables for the current Zsh session.
wsl_proxy_off() {
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy ALL_PROXY all_proxy
  print 'WSL proxy disabled for this shell'
}
