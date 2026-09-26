#!/bin/sh
# Turn the proxy on: point AI service names at it.
#
#   ./enable.sh
#
# A thin wrapper around bin/dns-ai-proxy.sh so the command you need is obvious
# from the file name.
cd "$(dirname "$0")" || exit 1

# sudo wipes the environment, so the DNS_AI_PROXY_* variables are handed to it
# explicitly. Without this, "DNS_AI_PROXY_ENTRY=... ./enable.sh" would quietly
# fall back to the default address - a system file edited somewhere other than
# where you asked.
if [ "$(id -u)" != 0 ]; then
    keep=""
    for v in DNS_AI_PROXY_ENTRY DNS_AI_PROXY_LIST_URL DNS_AI_PROXY_HOSTS; do
        eval "val=\${$v:-}"
        [ -n "$val" ] && keep="$keep $v=$val"
    done
    # shellcheck disable=SC2086
    exec sudo $keep "$0" "$@"
fi

exec ../bin/dns-ai-proxy.sh enable "$@"
