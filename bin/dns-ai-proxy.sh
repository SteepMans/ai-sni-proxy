#!/bin/sh
# dns-ai-proxy client for Linux and macOS.
#
#   sudo ./dns-ai-proxy.sh enable    point AI service names at the proxy
#   sudo ./dns-ai-proxy.sh disable   undo it
#        ./dns-ai-proxy.sh status    show what is in place right now
#
# The script edits one block of /etc/hosts, marked with the lines below, and
# never touches anything outside it. A timestamped copy of the file is made
# before every change.
#
# Written in POSIX sh on purpose: macOS still ships bash 3.2, and this way the
# same file runs there and on any Linux without a second dialect to maintain.
#
# Environment overrides:
#   DNS_AI_PROXY_ENTRY      entry node address (default below)
#   DNS_AI_PROXY_LIST_URL   where to fetch the domain list from
#   DNS_AI_PROXY_HOSTS      hosts file to edit (useful for a dry run)
set -eu

ENTRY="${DNS_AI_PROXY_ENTRY:-84.38.189.217}"
LIST_URL="${DNS_AI_PROXY_LIST_URL:-https://chimney.steep-man.ru/dns-ai-proxy/domains.txt}"
HOSTS="${DNS_AI_PROXY_HOSTS:-/etc/hosts}"

BEGIN_MARK="# >>> dns-ai-proxy: begin, do not edit by hand >>>"
END_MARK="# <<< dns-ai-proxy: end <<<"

# A list this short means the download was truncated or we were served
# something else entirely. Better to keep the bundled copy than to write
# half a list into a system file.
MIN_DOMAINS=20

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fallback_list="$script_dir/../domains/fallback.txt"

die() { printf 'dns-ai-proxy: %s\n' "$1" >&2; exit 1; }
say() { printf '%s\n' "$1"; }

require_root() {
    [ "$(id -u)" = 0 ] || die "this needs root, run it with sudo: sudo $0 $1"
}

# Keep only well-formed host names, drop comments, blank lines and the
# leading-dot wildcard entries the proxy understands but hosts files do not.
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

# Fresh list from the server when we can reach it, bundled copy when we cannot.
# Prints the domains; the note about which source was used goes to stderr so it
# does not end up inside the hosts file.
resolve_list() {
    fetched=$(fetch_list | clean_list || true)
    n=$(printf '%s' "$fetched" | grep -c . || true)
    if [ "${n:-0}" -ge "$MIN_DOMAINS" ]; then
        printf 'list: %s names from %s\n' "$n" "$LIST_URL" >&2
        printf '%s\n' "$fetched"
        return 0
    fi
    [ -f "$fallback_list" ] || die "could not download the list and no bundled copy at $fallback_list"
    bundled=$(clean_list < "$fallback_list")
    n=$(printf '%s' "$bundled" | grep -c . || true)
    [ "${n:-0}" -ge "$MIN_DOMAINS" ] || die "bundled list at $fallback_list looks broken ($n names)"
    printf 'list: could not reach %s, using the bundled copy (%s names)\n' "$LIST_URL" "$n" >&2
    printf '%s\n' "$bundled"
}

# A begin without an end means someone edited the file by hand or a previous
# run was interrupted. Cutting "everything to the end of file" would take their
# lines with it, so we stop instead.
assert_block_intact() {
    begins=$(grep -c -F -x "$BEGIN_MARK" "$HOSTS" || true)
    ends=$(grep -c -F -x "$END_MARK" "$HOSTS" || true)
    [ "$begins" = "$ends" ] || die \
        "the dns-ai-proxy block in $HOSTS is damaged: $begins begin marks, $ends end marks. Nothing changed."
}

strip_block() {
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { inside = 1; next }
        $0 == e { inside = 0; next }
        !inside { print }
    ' "$HOSTS"
}

backup_hosts() {
    stamp=$(date +%Y%m%d-%H%M%S)
    backup="$HOSTS.bak-dns-ai-proxy-$stamp"
    n=1
    while [ -e "$backup" ]; do
        backup="$HOSTS.bak-dns-ai-proxy-$stamp-$n"
        n=$((n + 1))
    done
    cp -p "$HOSTS" "$backup"
    printf '%s' "$backup"
}

# Write through a temporary file and move it into place: a plain redirect
# truncates the original first, and an interruption there leaves the machine
# with no hosts file at all.
#
# The temporary file is created first and only then given the original's owner
# and mode. The other way round - copying the original and writing into the
# copy - fails when the file belongs to someone else in a sticky directory,
# because the kernel refuses that write even for root (fs.protected_regular).
write_hosts() {
    tmp="$HOSTS.dns-ai-proxy.tmp"
    rm -f "$tmp"
    cat > "$tmp"
    # GNU coreutils first, BSD and macOS second; both are best effort, because
    # a hosts file with default root ownership is already correct.
    if ! chmod --reference="$HOSTS" "$tmp" 2>/dev/null; then
        chmod "$(stat -f '%Lp' "$HOSTS" 2>/dev/null || echo 644)" "$tmp" 2>/dev/null || true
    fi
    if ! chown --reference="$HOSTS" "$tmp" 2>/dev/null; then
        owner=$(stat -f '%u:%g' "$HOSTS" 2>/dev/null || true)
        [ -n "$owner" ] && chown "$owner" "$tmp" 2>/dev/null || true
    fi
    mv -f "$tmp" "$HOSTS"
}

flush_dns() {
    if [ "$(uname -s)" = "Darwin" ]; then
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
        return
    fi
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl flush-caches 2>/dev/null || true
    elif command -v systemd-resolve >/dev/null 2>&1; then
        systemd-resolve --flush-caches 2>/dev/null || true
    fi
}

cmd_enable() {
    require_root enable
    [ -f "$HOSTS" ] || die "no hosts file at $HOSTS"
    assert_block_intact

    domains=$(resolve_list)
    count=$(printf '%s\n' "$domains" | grep -c . || true)

    backup=$(backup_hosts)
    {
        strip_block
        printf '%s\n' "$BEGIN_MARK"
        printf '# enabled %s, %s names -> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$count" "$ENTRY"
        printf '%s\n' "$domains" | while IFS= read -r d; do
            [ -n "$d" ] && printf '%s\t%s\n' "$ENTRY" "$d"
        done
        printf '%s\n' "$END_MARK"
    } | write_hosts

    flush_dns
    say "enabled: $count names now point at $ENTRY"
    say "backup:  $backup"
    say "undo:    sudo $0 disable"
}

cmd_disable() {
    require_root disable
    [ -f "$HOSTS" ] || die "no hosts file at $HOSTS"
    assert_block_intact

    if ! grep -q -F -x "$BEGIN_MARK" "$HOSTS"; then
        say "nothing to undo: no dns-ai-proxy block in $HOSTS"
        return 0
    fi
    backup=$(backup_hosts)
    strip_block | write_hosts
    flush_dns
    say "disabled: the dns-ai-proxy block is gone from $HOSTS"
    say "backup:   $backup"
}

cmd_status() {
    [ -f "$HOSTS" ] || die "no hosts file at $HOSTS"
    if ! grep -q -F -x "$BEGIN_MARK" "$HOSTS"; then
        say "off: no dns-ai-proxy block in $HOSTS"
        return 0
    fi
    inside=$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { inside = 1; next }
        $0 == e { inside = 0; next }
        inside  { print }
    ' "$HOSTS")
    names=$(printf '%s\n' "$inside" | grep -cv '^#' || true)
    addresses=$(printf '%s\n' "$inside" | grep -v '^#' | awk '{print $1}' | sort -u | tr '\n' ' ')
    say "on: $names names in $HOSTS point at $addresses"
    printf '%s\n' "$inside" | grep '^# enabled' || true
}

case "${1:-}" in
    enable)  cmd_enable ;;
    disable) cmd_disable ;;
    status)  cmd_status ;;
    *)
        say "usage: $0 enable | disable | status"
        say ""
        say "  enable   fetch the domain list and point those names at the proxy (needs sudo)"
        say "  disable  remove the block from the hosts file (needs sudo)"
        say "  status   show whether it is on and how many names are listed"
        exit 2
        ;;
esac
