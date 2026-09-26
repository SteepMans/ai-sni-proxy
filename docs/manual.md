# Ручная настройка

Всё, что делают скрипты, — руками. Пригодится, если не хочется запускать чужой
скрипт на системном файле, если машина под политиками или если просто хочется
сначала увидеть правку.

🇬🇧 [In English](manual.en.md) · ⬅️ [Назад к README](../README.md)

---

## Что именно меняется

Один файл — `hosts`, в который операционная система заглядывает раньше, чем
спрашивает DNS-сервер. Вы добавляете строки вида:

```
84.38.189.217	claude.ai
84.38.189.217	chatgpt.com
```

После этого соединения к этим именам идут на `84.38.189.217` вместо
собственного адреса сервиса. Всё, чего в списке нет, работает как раньше.

Оберните блок двумя метками, чтобы потом найти его глазами (и чтобы скрипты
его узнали):

```
# >>> dns-ai-proxy: begin, do not edit by hand >>>
84.38.189.217	claude.ai
...
# <<< dns-ai-proxy: end <<<
```

---

## Шаг 1 — взять список

Откройте <https://chimney.steep-man.ru/dns-ai-proxy/domains.txt> в браузере или:

```sh
curl -fsSL https://chimney.steep-man.ru/dns-ai-proxy/domains.txt
```

Это обычный текст: одно имя в строке, комментарии начинаются с `#`. Копия без
сети — [`domains/fallback.txt`](../domains/fallback.txt), содержимое то же.

Все 700+ имён не обязательны. Разумный минимум для одного сервиса — сам сайт и
его API:

```
claude.ai
www.claude.ai
claude.com
api.anthropic.com
chatgpt.com
chat.openai.com
api.openai.com
```

Пропущенные имена просто продолжат ходить напрямую.

---

## Шаг 2 — превратить список в строки hosts

Каждая строка становится `<адрес><таб><имя>`. Однострочник:

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

## Шаг 3 — отредактировать файл

### Windows

Файл лежит в `C:\Windows\System32\drivers\etc\hosts`.

1. Пуск → наберите «Блокнот» → правой кнопкой → **Запуск от имени
   администратора**. Без этого Блокнот откажется сохранять.
2. **Файл → Открыть**, вставьте путь выше. Переключите фильтр с «Текстовые
   документы» на **Все файлы**, иначе файла не будет видно.
3. Сначала сохраните копию текущего файла куда-нибудь — например, на рабочий
   стол.
4. Вставьте свой блок в конец, между двумя метками.
5. Сохраните. Затем в терминале: `ipconfig /flushdns`.

### macOS

```sh
sudo cp /etc/hosts ~/hosts-backup
sudo nano /etc/hosts
```

Вставьте блок в конец, затем `Ctrl+O`, `Enter`, `Ctrl+X` — сохранить и выйти.
Сбросьте кэш DNS:

```sh
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Linux

```sh
sudo cp /etc/hosts ~/hosts-backup
sudo nano /etc/hosts
```

Вставьте, сохраните и сбросьте кэш, если он есть:

```sh
sudo resolvectl flush-caches     # systemd-resolved
```

---

## Шаг 4 — проверить

```sh
ping -c 1 claude.ai          # должен показать 84.38.189.217
curl -sI https://claude.ai | head -1
```

```powershell
ping claude.ai
curl.exe -sI https://claude.ai | Select-Object -First 1
```

Адрес должен быть прокси, а сайт — по-прежнему отвечать с действительным
сертификатом. Если появилось предупреждение о сертификате, соединение кто-то
перехватывает: откатите правку и разберитесь, прежде чем продолжать.

**Браузеру нужно ещё кое-что.** Chrome, Edge, Firefox и Яндекс.Браузер умеют
резолвить имена через собственный шифрованный DNS, который файл `hosts` не
смотрит вовсе. Если `ping` показывает прокси, а сайт всё равно пишет про
регион — выключите «Безопасный DNS» / «DNS через HTTPS» в настройках браузера
и перезапустите его.

---

## Как откатить

Удалите всё между двумя метками или верните сохранённую копию:

```sh
sudo cp ~/hosts-backup /etc/hosts
```

В Windows — замените файл своей копией с рабочего стола, снова через Блокнот
от администратора, и выполните `ipconfig /flushdns`.

---

## Со своим сервером

Замените `84.38.189.217` на адрес своего сервера везде выше. Серверу нужно
слушать 443-й порт и маршрутизировать по SNI, не расшифровывая. Часть для
nginx короткая:

```nginx
stream {
    map $ssl_preread_server_name $backend {
        claude.ai          $ssl_preread_server_name:443;
        api.anthropic.com  $ssl_preread_server_name:443;
        default            127.0.0.1:9;      # там никто не слушает
    }

    server {
        listen 443;
        ssl_preread on;
        proxy_pass $backend;
    }
}
```

Строку `default` не убирайте. Без неё это открытый релей — его найдут и начнут
использовать в считаные дни.
