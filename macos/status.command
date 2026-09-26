#!/bin/sh
# Show whether the proxy is on.
#
# Double-click this file in Finder: macOS opens it in Terminal and runs it.
# Editing /etc/hosts needs administrator rights, so Terminal will ask for your
# login password (this one does not change anything).
#
# If macOS refuses to open the file ("unidentified developer"), remove the
# quarantine flag once:  xattr -d com.apple.quarantine *.command
cd "$(dirname "$0")" || exit 1
../bin/dns-ai-proxy.sh status
echo ""
echo "You can close this window."
