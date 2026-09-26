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
sudo ../bin/dns-ai-proxy.sh enable
echo ""
echo "You can close this window."
