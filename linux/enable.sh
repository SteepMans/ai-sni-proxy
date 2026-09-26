#!/bin/sh
# Turn the proxy on: point AI service names at it.
#
#   ./enable.sh
#
# A thin wrapper around bin/dns-ai-proxy.sh so the command you need is obvious
# from the file name.
cd "$(dirname "$0")" || exit 1
exec sudo ../bin/dns-ai-proxy.sh enable "$@"
