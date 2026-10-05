# Занятие 9. Nginx перед бэкендом + конфигурация и секреты

Продолжаем стек занятия 8. Мы остановились на проблеме: при `--scale backend=3` каждой копии нужен свой порт на хосте, и пользователю непонятно, куда стучаться. Решение — **reverse proxy**: наружу открыт только Nginx, а запросы по копиям бэкенда он раздаёт сам. Заодно убираем пароли из compose-файла в `.env`.

```
браузер ──:80──▶ nginx ──▶ backend ×N ──▶ postgres, redis
                 (frontend-net)        (backend-net)
```

## Подготовка

- [ ] Всё из [подготовки к занятию 8](../lesson08/README.md#подготовка): Docker, репозиторий, образы.
- [ ] Обновите репозиторий: `cd devops-lab && git pull`
- [ ] Скачайте образ nginx: `bash scripts/pull-images.sh` (скрипт качает все образы курса, в том числе `nginx:1.27-alpine`).
- [ ] `git filter-repo` установлен: `git filter-repo --version` (ставится в [подготовке ноутбука](../README.md#подготовка-ноутбука)).
- [ ] Стек занятия 8 остановлен, иначе порты будут заняты: `docker compose -f lesson08/docker-compose.yml down`

## Практика

### Часть 1. Reverse proxy (40 мин)
```bash
cd lesson09
cp .env.example .env                  # впишите свой пароль (подробнее — в части 2)
docker compose up -d --build
docker compose ps                     # опубликован только порт nginx (80 -> 80)
curl localhost/                       # ответил backend через nginx
curl localhost/nginx-health           # ответил сам nginx
```
> Порт 80 занят или нет прав? В `.env` поставьте `HTTP_PORT=8080` и обращайтесь к `localhost:8080`.
> Windows/VirtualBox: в браузере Windows — `http://localhost:8080` (проброс 8080 → 80 из подготовки).

**Масштабирование без конфликта портов:**
```bash
docker compose up -d --scale backend=3
sleep 5                               # nginx перечитывает DNS каждые 5 с (resolve в nginx.conf)
for i in $(seq 6); do curl -s localhost/hits; echo; done   # served_by чередуется, счётчик общий
```

**Отказоустойчивость:**
```bash
docker compose logs -f nginx          # в другом окне: журнал запросов
docker stop devops-lab-backend-1      # «уронили» одну копию
for i in $(seq 6); do curl -s localhost/hits; echo; done   # отвечают оставшиеся
docker compose stop backend           # уронили все
curl -i localhost/                    # 502 Bad Gateway — nginx жив, а за ним никого
docker compose up -d --scale backend=3
```

**Что посмотреть в `nginx/nginx.conf`:**
- `upstream` с одной строкой `server backend:8000 resolve`; почему строка одна, объяснено в комментариях;
- `proxy_pass`;
- заголовки `X-Forwarded-*`;
- `location = /nginx-health`.

### Часть 2. Конфигурация и секреты (40 мин)
```bash
rm .env
docker compose config                 # ошибка: required variable POSTGRES_USER is missing
cp .env.example .env                  # впишите свой пароль
docker compose config                 # видно, какие значения подставились
# поменяйте в .env APP_VERSION=v2 и перезапустите — версия сменится без правки кода:
docker compose up -d
curl localhost/
```

#### Эмуляция утечки секрета (делать в ОТДЕЛЬНОЙ папке!)
```bash
mkdir /tmp/leak-demo && cd /tmp/leak-demo && git init
echo "POSTGRES_PASSWORD=Sup3rS3cret" > .env
git add .env && git commit -m "add config"        # ошибка!

# «Удаляем» — но это не помогает:
git rm --cached .env && echo ".env" > .gitignore
git add .gitignore && git commit -m "remove .env"
git log -p --all -S "Sup3rS3cret"                  # пароль всё ещё в истории

# Находим сканером:
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest git /repo -v

# Переписываем историю:
git filter-repo --invert-paths --path .env --force
git log -p --all -S "Sup3rS3cret"                  # пусто
```
Главное правило: **если секрет попал в удалённый репозиторий — считаем его скомпрометированным и меняем (ротация)**. Переписывание истории — вторично.

### Задания для тех, кто закончил раньше
1. Добавьте в `nginx.conf` свою страницу для 502: `error_page 502 /502.html;` и `location = /502.html { return 502 "Сервис перезапускается, обновите страницу через минуту\n"; }`.
2. Ограничьте частоту запросов: `limit_req_zone $binary_remote_addr zone=one:10m rate=5r/s;` (в начале файла) и `limit_req zone=one burst=10;` в `location /`. Проверьте: `for i in $(seq 50); do curl -s -o /dev/null -w "%{http_code} " localhost/; done`.
3. Включите сжатие: `gzip on; gzip_types application/json;` и сравните `curl -sI -H 'Accept-Encoding: gzip' localhost/notes`.

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `Bind for 0.0.0.0:80 failed: port is already allocated` | Порт 80 занят (стек занятия 8 или другой сервис) | `docker compose -f ../lesson08/docker-compose.yml down` или `HTTP_PORT=8080` в `.env` |
| `required variable … is missing` | Нет файла `.env` | `cp .env.example .env` |
| `curl localhost/` → 502 сразу после старта | Бэкенд ещё запускается | Подождать 5–10 с, `docker compose ps` |
| `served_by` не чередуется после `--scale` | nginx ещё не перечитал DNS | Подождать 5 с (`resolve` в nginx.conf) |
| `password authentication failed` | Том создан со старым паролем | `docker compose down -v` (данные удалятся) |
| `git: 'filter-repo' is not a git command` | Не установлен git-filter-repo | См. [подготовку ноутбука](../README.md#подготовка-ноутбука) |

## Домашнее задание

**Срок — до занятия 10.** Как сдавать: заполните шаблон [HOMEWORK.md](HOMEWORK.md) (скопируйте, назовите `ДЗ-09-фамилия.md`) и отправьте файлом в чат группы. Пароли в ответ не вставляйте.

1. **Docker secrets вместо переменной.** Переведите пароль Postgres на секрет Docker:
   - создайте файл `lesson09/secrets/db_password.txt` с паролем и добавьте папку `secrets/` в `.gitignore`;
   - в compose добавьте раздел `secrets:` и подключите секрет к сервису `db`; вместо `POSTGRES_PASSWORD` используйте `POSTGRES_PASSWORD_FILE: /run/secrets/db_password`;
   - проверьте: `docker compose exec db cat /run/secrets/db_password` показывает пароль, а `docker compose config` и `docker inspect` — нет.

   Подсказка: [документация Compose про secrets](https://docs.docker.com/compose/how-tos/use-secrets/). Бэкенду пароль по-прежнему нужен в `DATABASE_URL`. Подумайте и напишите, почему его так просто не перевести на файл.
2. **Nginx.** Сделайте дома одно из «заданий для тех, кто закончил раньше» (своя страница 502, лимит запросов или gzip) и приложите вывод команды, которая показывает результат.
3. **Вопросы (письменно, коротко):**
   - Зачем в `upstream` параметр `resolve` и что будет без него после `--scale`?
   - Почему у бэкенда в compose нет `ports`?
   - Секрет попал в публичный репозиторий. Назовите правильный порядок действий.

**В конце:** `docker compose down`.
