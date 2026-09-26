#!/bin/sh
# Show whether the proxy is on.
#
#   ./status.sh
#
# A thin wrapper around bin/ai-sni-proxy.sh so the command you need is obvious
# from the file name.
cd "$(dirname "$0")" || exit 1

exec ../bin/ai-sni-proxy.sh status "$@"
