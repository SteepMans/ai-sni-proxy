# Безопасность / Security

Этот клиент правит системный файл и направляет часть вашего трафика через
чужой сервер, поэтому к сообщениям об уязвимостях здесь относятся серьёзно.

**Сообщайте приватно:**
[github.com/SteepMans/ai-sni-proxy/security/advisories/new](https://github.com/SteepMans/ai-sni-proxy/security/advisories/new).
Публичный issue для такого не подходит.

Что особенно интересно:

- способ подменить список доменов по дороге к пользователю;
- обход проверки имён, из-за которого в `hosts` попадёт лишняя запись;
- всё, что позволяет клиенту записать в `hosts` строку, которую он писать не должен;
- открытый релей на серверной стороне — то есть возможность проксировать через
  наш сервер имя, которого нет в списке.

Ответ — в течение нескольких дней. Исправление списка или серверной части
доезжает до пользователей без нового релиза.

---

This client edits a system file and routes part of your traffic through
someone else's server, so vulnerability reports are taken seriously. Report
privately through
[GitHub security advisories](https://github.com/SteepMans/ai-sni-proxy/security/advisories/new),
never in a public issue.
