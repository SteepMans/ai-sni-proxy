[Русский](mobile.md)

# Phone: Incy and Happ

A phone has no `hosts` file for the desktop client to edit. The Xray clients
[Incy](https://docs.incy.cc/en/routing/) and
[Happ](https://www.happ.su/main/dev-docs/routing) have routing profiles instead,
and a profile can express the same thing: names from the list point at our
entry and go there directly rather than through the client's VPN server.

The profile lives in [`mobile`](../mobile):

| File | What it is |
|---|---|
| `incy-link.txt` | an `incy://routing/add/...` link for Incy |
| `happ-link.txt` | a `happ://routing/add/...` link for Happ |
| `routing-profile.json` | the profile itself, to see what is inside |

## Install

1. On the phone, open `incy-link.txt` or `happ-link.txt` in Raw view and copy
   the whole line. It is long, about 90 thousand characters: the whole domain
   list is inside.
2. **Incy:** add a routing profile from the clipboard (tunnel settings, routing
   profiles) and make `ai-sni-proxy` the active one.
3. **Happ:** the same, then reconnect. Happ applies a profile change only after
   a reconnect.

Only one profile can be active, so `ai-sni-proxy` replaces whatever was there.
All other traffic goes through your VPN server, as with the default profile
(`GlobalProxy: true`). If your previous profile had rules of its own, move them
into `routing-profile.json` and rebuild the link (see below).

## Check

Open <https://claude.ai/cdn-cgi/trace> in the phone browser. The `ip=` line
should show neither your own address nor your VPN server's, and `loc=` should
not be `RU`.

If it shows your own address, the client resolves the name again for direct
connections and bypasses `DnsHosts`. An IPv6 address means the phone goes
around the mapping over IPv6. Either way, please open an
[issue](https://github.com/SteepMans/ai-sni-proxy/issues) with the client name
and version.

## Rebuild

The domain list changes, and the profile is built from it by a script:

```sh
./mobile/build-profile.sh            # the published list
./mobile/build-profile.sh --bundled  # domains/fallback.txt, offline
```

It needs `sh`, `awk`, `base64` and `curl` or `wget`. Importing a profile with
the same name again overwrites it, there is no need to delete the old one.

## What is inside

- `DnsHosts`: every listed name answers with the entry address, like a `hosts` line.
- `DirectSites`: the same names with a `full:` prefix, exact match only, so
  subdomains missing from the list go as usual.
- `DirectIp`: the entry address and local networks go direct.
- `FakeDNS: false`: otherwise the client swaps in addresses of its own and
  `DnsHosts` never applies.
