# Manual setup

Everything the scripts do, done by hand. Useful if you do not want to run
someone else's script against a system file, if your machine is locked down,
or if you just want to see the change before you make it.

🇷🇺 [По-русски](manual.md) · ⬅️ [Back to the README](../README.en.md)

---

## What you are about to change

One file — the `hosts` file your operating system checks before asking a DNS
server. You add lines that look like this:

```
84.38.189.217	claude.ai
84.38.189.217	chatgpt.com
```

From then on, connections to those names go to `84.38.189.217` instead of the
service's own address. Everything not listed keeps working exactly as before.

Wrap the block in two marker lines so you (and the scripts) can find it again:

```
# >>> dns-ai-proxy: begin, do not edit by hand >>>
84.38.189.217	claude.ai
...
# <<< dns-ai-proxy: end <<<
```

---

## Step 1 — get the list

Open <https://chimney.steep-man.ru/dns-ai-proxy/domains.txt> in a browser, or:

```sh
curl -fsSL https://chimney.steep-man.ru/dns-ai-proxy/domains.txt
```

It is a plain text file: one hostname per line, comments start with `#`.
The offline copy in [`domains/fallback.txt`](../domains/fallback.txt) is the
same thing.

You do not need all 700+ names. A useful minimum for one service is the site
itself plus its API:

```
claude.ai
www.claude.ai
claude.com
api.anthropic.com
chatgpt.com
chat.openai.com
api.openai.com
```

Leaving names out only means those names keep going out directly.

---

## Step 2 — turn the list into hosts lines

Each line becomes `<address><tab><name>`. A one-liner that does it:

```sh
curl -fsSL https://chimney.steep-man.ru/dns-ai-proxy/domains.txt \
  | grep -v '^#' | grep . \
  | awk '{print "84.38.189.217\t" $0}'
```

```powershell
(Invoke-WebRequest 'https://chimney.steep-man.ru/dns-ai-proxy/domains.txt' -UseBasicParsing).Content `
  -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object { "84.38.189.217`t$_" }
```

---

## Step 3 — edit the file

### Windows

The file is at `C:\Windows\System32\drivers\etc\hosts`.

1. Press Start, type `Notepad`, right-click it and choose **Run as
   administrator**. Without this Notepad will refuse to save.
2. **File → Open**, paste the path above. Change the file filter from
   *Text Documents* to **All Files**, or you will not see it.
3. Copy the current file somewhere safe first — Desktop is fine.
4. Paste your block at the end, between the two marker lines.
5. Save. Then, in a terminal: `ipconfig /flushdns`.

### macOS

```sh
sudo cp /etc/hosts ~/hosts-backup
sudo nano /etc/hosts
```

Paste the block at the end, then `Ctrl+O`, `Enter`, `Ctrl+X` to save and quit.
Flush the DNS cache:

```sh
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Linux

```sh
sudo cp /etc/hosts ~/hosts-backup
sudo nano /etc/hosts
```

Paste, save, and flush if your system caches:

```sh
sudo resolvectl flush-caches     # systemd-resolved
```

---

## Step 4 — check it worked

```sh
ping -c 1 claude.ai          # should show 84.38.189.217
curl -sI https://claude.ai | head -1
```

```powershell
ping claude.ai
curl.exe -sI https://claude.ai | Select-Object -First 1
```

The address must be the proxy, and the site must still answer with a valid
certificate. If the certificate warning appears, something is intercepting the
connection — undo the change and ask.

**Browsers need one more thing.** Chrome, Edge, Firefox and Yandex Browser can
resolve names through their own encrypted DNS, which ignores the `hosts` file
entirely. If the site still shows the region error while `ping` points at the
proxy, turn off "Secure DNS" / "DNS over HTTPS" in the browser settings and
restart it.

---

## Undoing it

Delete everything between the two marker lines, or restore the copy you made:

```sh
sudo cp ~/hosts-backup /etc/hosts
```

On Windows: replace the file with your copy from the Desktop, again with an
administrator Notepad, and run `ipconfig /flushdns`.

---

## Using your own server

Replace `84.38.189.217` with your server's address everywhere above. The server
needs to listen on 443 and route by SNI without decrypting. The nginx part is
short:

```nginx
stream {
    map $ssl_preread_server_name $backend {
        claude.ai          $ssl_preread_server_name:443;
        api.anthropic.com  $ssl_preread_server_name:443;
        default            127.0.0.1:9;      # nothing listens there
    }

    server {
        listen 443;
        ssl_preread on;
        proxy_pass $backend;
    }
}
```

Keep the `default` line. Without it you are running an open relay, and it will
be found and abused within days.
