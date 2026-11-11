#!/bin/sh
# Build a routing profile for the Incy and Happ phone clients.
#
#   ./mobile/build-profile.sh            take the published domain list
#   ./mobile/build-profile.sh --bundled  take domains/fallback.txt instead
#
# A phone has no hosts file to edit, so the profile carries the same mapping
# inside the client. DnsHosts answers every listed name with the entry node,
# and DirectSites sends those names straight to it instead of through the
# client's own VPN server. Everything else follows GlobalProxy, as before.
#
# Incy and Happ read the same profile format, only the link scheme differs.
# The script writes three files next to itself:
#   routing-profile.json   the profile, one entry per line
#   incy-link.txt          incy://routing/add/<base64>, import it from the clipboard
#   happ-link.txt          happ://routing/add/<base64>, the same for Happ
#
# The output only changes when the list or the entry changes, so it is safe
# to commit after a list refresh.
#
# Environment overrides, the same as the desktop client:
#   AI_SNI_PROXY_ENTRY      entry node address
#   AI_SNI_PROXY_LIST_URL   where to fetch the domain list from
set -eu

ENTRY="${AI_SNI_PROXY_ENTRY:-84.38.189.217}"
LIST_URL="${AI_SNI_PROXY_LIST_URL:-https://chimney.steep-man.ru/ai-sni-proxy/domains.txt}"

# Same floor as the client: a shorter list means a truncated download.
MIN_DOMAINS=20

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fallback_list="$script_dir/../domains/fallback.txt"

die() { printf 'build-profile: %s\n' "$1" >&2; exit 1; }

# Same filter as bin/ai-sni-proxy.sh: plain host names only, no comments and
# no leading-dot wildcards, which a profile cannot express either.
clean_list() {
    awk '
        { line = $0; sub(/#.*/, "", line); gsub(/\r/, "", line)
          gsub(/^[ \t]+|[ \t]+$/, "", line)
          if (line == "") next
          if (substr(line, 1, 1) == ".") next
          if (line !~ /^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$/) next
          if (seen[line]++) next
          print line }
    '
}

fetch_list() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 20 "$LIST_URL" 2>/dev/null || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- --timeout=20 "$LIST_URL" 2>/dev/null || return 1
    else
        return 1
    fi
}

printf '%s\n' "$ENTRY" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' \
    || die "entry does not look like an IPv4 address: $ENTRY"

if [ "${1:-}" = "--bundled" ]; then
    list=$(clean_list < "$fallback_list")
    source_name="$fallback_list"
else
    list=$(fetch_list | clean_list || true)
    source_name="$LIST_URL"
fi

n=$(printf '%s\n' "$list" | grep -c . || true)
[ "$n" -ge "$MIN_DOMAINS" ] || die "only $n names from $source_name, refusing to build a partial profile"

# Sorted so that the files do not churn when the list is only reordered.
list=$(printf '%s\n' "$list" | LC_ALL=C sort)

json="$script_dir/routing-profile.json"
printf '%s\n' "$list" | awk -v entry="$ENTRY" '
    { names[NR] = $0 }
    END {
        print "{"
        print "\"Name\": \"ai-sni-proxy\","
        print "\"GlobalProxy\": \"true\","
        print "\"RemoteDNSType\": \"DoH\","
        print "\"RemoteDNSDomain\": \"https://cloudflare-dns.com/dns-query\","
        print "\"RemoteDNSIP\": \"1.1.1.1\","
        print "\"DomesticDNSType\": \"DoH\","
        print "\"DomesticDNSDomain\": \"https://dns.google/dns-query\","
        print "\"DomesticDNSIP\": \"8.8.8.8\","
        print "\"Geoipurl\": \"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat\","
        print "\"Geositeurl\": \"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat\","
        print "\"LastUpdated\": \"\","
        print "\"DnsHosts\": {"
        printf "\"cloudflare-dns.com\": \"1.1.1.1\",\n\"dns.google\": \"8.8.8.8\""
        for (i = 1; i <= NR; i++) printf ",\n\"%s\": \"%s\"", names[i], entry
        print "\n},"
        print "\"DirectSites\": ["
        for (i = 1; i <= NR; i++) printf "%s\"full:%s\"", (i > 1 ? ",\n" : ""), names[i]
        print "\n],"
        printf "\"DirectIp\": [\"%s/32\", \"10.0.0.0/8\", \"172.16.0.0/12\", \"192.168.0.0/16\", \"169.254.0.0/16\", \"224.0.0.0/4\", \"255.255.255.255\"],\n", entry
        print "\"ProxySites\": [],"
        print "\"ProxyIp\": [],"
        print "\"BlockSites\": [],"
        print "\"BlockIp\": [],"
        print "\"DomainStrategy\": \"AsIs\","
        print "\"FakeDNS\": \"false\""
        print "}"
    }
' > "$json"

b64=$(base64 < "$json" | tr -d '\n\r')
[ -n "$b64" ] || die "base64 produced nothing"

printf 'incy://routing/add/%s\n' "$b64" > "$script_dir/incy-link.txt"
printf 'happ://routing/add/%s\n' "$b64" > "$script_dir/happ-link.txt"

printf 'profile: %s names from %s, entry %s\n' "$n" "$source_name" "$ENTRY"
printf 'wrote %s, incy-link.txt, happ-link.txt\n' "$json"
