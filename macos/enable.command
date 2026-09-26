#!/bin/sh
# Turn the proxy on: point AI service names at it.
#
# Double-click this file in Finder: macOS opens it in Terminal and runs it.
# Editing /etc/hosts needs administrator rights, so Terminal will ask for your
# login password.
#
# If macOS refuses to open the file ("unidentified developer"), remove the
# quarantine flag once:  xattr -d com.apple.quarantine *.command
cd "$(dirname "$0")" || exit 1

# sudo wipes the environment, so the AI_SNI_PROXY_* variables are handed to it
# explicitly. Without this, "AI_SNI_PROXY_ENTRY=... ./enable.sh" would quietly
# fall back to the default address - a system file edited somewhere other than
# where you asked.
if [ "$(id -u)" != 0 ]; then
    keep=""
    for v in AI_SNI_PROXY_ENTRY AI_SNI_PROXY_LIST_URL AI_SNI_PROXY_HOSTS; do
        eval "val=\${$v:-}"
        [ -n "$val" ] && keep="$keep $v=$val"
    done
    # shellcheck disable=SC2086
    exec sudo $keep "$0" "$@"
fi

../bin/ai-sni-proxy.sh enable "$@"

echo ""
echo "You can close this window."
