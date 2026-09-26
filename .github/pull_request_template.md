<!-- Pull request'ы идут в develop, не в main. Заголовок коммита — на английском, одной строкой. -->

**Что меняется и зачем**


**Как проверено**

<!-- Клиент правит системный файл, поэтому проверка обязательна. Подставьте
     временный файл вместо настоящего hosts и убедитесь, что откат чистый:

     printf "127.0.0.1\tlocalhost\n" > /tmp/h
     AI_SNI_PROXY_HOSTS=/tmp/h sudo -E ./bin/ai-sni-proxy.sh enable
     AI_SNI_PROXY_HOSTS=/tmp/h sudo -E ./bin/ai-sni-proxy.sh disable
     diff <(printf "127.0.0.1\tlocalhost\n") /tmp/h
-->

- [ ] проверено на: Windows / macOS / Linux (нужное оставить)
- [ ] `disable` возвращает файл байт в байт
- [ ] для Linux и macOS — POSIX `sh`, без bash-измов
- [ ] для Windows — работает на PowerShell 5.1
