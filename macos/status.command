#!/bin/sh
# Show whether the proxy is on.
#
# Double-click this file in Finder: macOS opens it in Terminal and runs it.
# This one only looks at the hosts file and changes nothing, so no password
# is needed.
#
# If macOS refuses to open the file ("unidentified developer"), remove the
# quarantine flag once:  xattr -d com.apple.quarantine *.command
cd "$(dirname "$0")" || exit 1
../bin/ai-sni-proxy.sh status "$@"

echo ""
echo "You can close this window."
