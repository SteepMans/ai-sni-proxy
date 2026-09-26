# Участие в проекте

🇬🇧 [In English](#contributing) · ⬅️ [К README](README.md)

Issues и pull request'ы открыты для всех — заводите, предлагайте, спорьте.
Право коммита в репозиторий есть только у мейнтейнера: чужие изменения
попадают в проект через pull request, который мейнтейнер читает и вливает сам.
Так устроено не из недоверия, а потому что этот код правит системный файл на
чужих машинах, и за каждую строку кто-то должен отвечать лично.

## Что полезнее всего

**Не хватает сервиса в списке.** Самый частый и самый полезный вклад. Заведите
issue с именами хостов — список на сервере обновляется, и домены приезжают
всем пользователям при следующем запуске, без нового релиза. Как узнать имена:
откройте сайт, нажмите F12 → вкладка Network, посмотрите, к каким доменам он
обращается.

**Что-то сломалось.** Приложите вывод команды `status`, вашу систему и версию,
и — если правка `hosts` прошла, но не работает — что показывает
`ping имя.сервиса`.

**Правки в код.** Приветствуются, особенно для macOS: у мейнтейнера её нет,
и весь код для неё написан консервативно и проверен только на Linux.

## Как прислать pull request

Ветвление — git-flow. Ветка `main` — это то, что выпущено; вся работа идёт
от `develop`.

```sh
git checkout develop
git checkout -b feature/короткое-имя
# правки
git commit -m "Short English headline"
```

Pull request открывайте **в `develop`**, не в `main`. Заголовок коммита — на
английском, одной строкой, без тела.

## Что проверить перед отправкой

Клиент правит чужой системный файл, поэтому проверка обязательна, и она
несложная: у скриптов есть переменная, которая подсовывает им временный файл
вместо настоящего `hosts`.

```sh
printf "127.0.0.1\tlocalhost\n" > /tmp/h
AI_SNI_PROXY_HOSTS=/tmp/h sudo -E ./bin/ai-sni-proxy.sh enable
AI_SNI_PROXY_HOSTS=/tmp/h ./bin/ai-sni-proxy.sh status
AI_SNI_PROXY_HOSTS=/tmp/h sudo -E ./bin/ai-sni-proxy.sh disable
diff <(printf "127.0.0.1\tlocalhost\n") /tmp/h && echo "откат чистый"
```

```powershell
$env:AI_SNI_PROXY_HOSTS = "$env:TEMP\h"
"127.0.0.1`tlocalhost" | Set-Content $env:AI_SNI_PROXY_HOSTS
.\bin\ai-sni-proxy.ps1 status
```

Скрипты для Linux и macOS написаны на POSIX `sh` (без bash-измов: macOS всё
ещё поставляется с bash 3.2), PowerShell-часть обязана работать на Windows
PowerShell 5.1 — той, что стоит в системе по умолчанию. Комментарии и
сообщения в коде — на английском; документация двуязычная.

## Безопасность

Нашли способ подменить список доменов на пути к пользователю, обойти проверку
имён или заставить клиент записать в `hosts` что-то чужое — не открывайте
публичный issue. Напишите мейнтейнеру напрямую через
[приватный репорт GitHub](https://github.com/SteepMans/ai-sni-proxy/security/advisories/new).

---

# Contributing

Issues and pull requests are open to everyone. Commit access belongs to the
maintainer alone: outside changes land through a pull request that the
maintainer reads and merges. That is not distrust — this code edits a system
file on other people's machines, and someone has to answer for every line of
it personally.

**The most useful contribution** is a missing service. Open an issue with the
hostnames: the server-side list is updated from it and reaches every user on
their next run, with no new release needed.

**Pull requests** go into `develop`, not `main` — the project follows
git-flow. Commit headlines in English, one line, no body.

**Before you send one**, run the client against a temporary file instead of
the real `hosts` (see the commands above) and confirm that `disable` restores
it byte for byte. Linux and macOS code is POSIX `sh` — no bash-isms, macOS
still ships bash 3.2 — and the PowerShell side must run on Windows
PowerShell 5.1.

**Security issues** go to a
[private report](https://github.com/SteepMans/ai-sni-proxy/security/advisories/new),
never to a public issue.
