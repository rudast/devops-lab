# Занятие 8. Docker Compose

Описываем систему из трёх сервисов одним файлом и поднимаем её одной командой:

```
backend (Flask) ──▶ PostgreSQL (db)
        └────────▶ Redis (cache)
```

## Подготовка

Перед занятием должно быть готово (инструкции — в [«Подготовке ноутбука»](../README.md#подготовка-ноутбука)):

- [ ] Docker и Docker Compose: `docker compose version` работает. На Windows — внутри ВМ VirtualBox.
- [ ] Репозиторий склонирован: `git clone https://github.com/tenroman1-design/devops-lab.git`
- [ ] Образы курса скачаны заранее: `bash scripts/pull-images.sh` (из корня репозитория). Docker Hub из России работает нестабильно, поэтому образы берём из нашего реестра.

Проверка перед занятием:
```bash
cd devops-lab
docker image ls | grep -E "postgres|redis|python"   # три образа на месте
```

## Практика

```bash
cd lesson08
docker compose up -d --build          # собрать и запустить
docker compose ps                     # все сервисы healthy?
curl localhost:8000/health            # {"status": {"postgres":"ok","redis":"ok"}}
curl localhost:8000/hits              # счётчик растёт
curl -X POST -H 'Content-Type: application/json' -d '{"text":"hello"}' localhost:8000/notes
```
> Windows/VirtualBox: в браузере Windows — `http://localhost:8000` (проброс портов из подготовки).

**Сеть.** Сервисы видят друг друга по имени сервиса:
```bash
docker compose exec backend python -c "import socket; print(socket.gethostbyname('db'))"
docker network ls                     # сеть lesson08_backend-net
docker network inspect lesson08_backend-net
```

**Тома.** Данные переживают пересоздание контейнера:
```bash
docker compose down                   # контейнеры удалены, том остался
docker compose up -d
curl localhost:8000/notes             # заметка на месте
docker volume ls                      # lesson08_pgdata
docker compose down -v                # -v удалит и том (данные пропадут!)
```

**Масштабирование.**
```bash
docker compose up -d --scale backend=3
docker compose ps                     # 3 бэкенда, каждый получил свой порт из 8000–8005
curl localhost:8000/hits; curl localhost:8001/hits; curl localhost:8002/hits   # разные served_by, общий счётчик в Redis
```
Попробуйте заменить `"8000-8005:8000"` на `"8000:8000"` и снова сделать `--scale backend=3`. Вы увидите ошибку *port is already allocated*. Почему так? Как это решит Nginx, разберём на занятии 9.

**В конце занятия:** `docker compose down` — освободить порты для следующего занятия.

## Если что-то не работает

Первое действие всегда: `docker compose ps` → `docker compose logs <сервис>`.

| Симптом | Причина | Решение |
|---|---|---|
| `Cannot connect to the Docker daemon` / `permission denied` на docker.sock | Docker не запущен / пользователь не в группе docker | macOS: запустить Docker Desktop; ВМ: `sudo usermod -aG docker $USER` и перелогиниться |
| Windows: `localhost:8000` не открывается | Нет проброса порта в VirtualBox | Настроить → Сеть → Проброс портов |
| `port is already allocated` | Порт занят другим контейнером | `docker ps`, остановить лишнее или сменить порт |
| backend: `Connection refused` к БД | `localhost` вместо имени сервиса | В URL должно быть `db`, не `localhost` |
| `pull` висит / 403 / toomanyrequests | Нет доступа к Docker Hub | `bash scripts/pull-images.sh`, см. [образы из GHCR](../README.md#образы-курса-из-нашего-реестра-ghcr) |

## Домашнее задание

Срок — до занятия 9. Как сдавать, скажет преподаватель (например: ответы и скриншоты в чат группы или файл `HOMEWORK.md` в вашем форке).

1. **Healthcheck для бэкенда.** Сейчас healthcheck есть у `db` и `cache`, а у `backend` нет. Добавьте его в `docker-compose.yml`:
   ```yaml
       healthcheck:
         test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
         interval: 5s
         timeout: 3s
         retries: 5
   ```
   Поднимите стек и дождитесь `healthy` у бэкенда в `docker compose ps`. Затем остановите Redis: `docker compose stop cache`. Что через 20–30 секунд показывает `docker compose ps` у бэкенда и почему? Что отвечает `curl -i localhost:8000/health`? Верните Redis: `docker compose start cache`.
2. **Тома.** Создайте 3 заметки. Сравните, что останется от данных после `docker compose down` + `up -d` и после `docker compose down -v` + `up -d`. Объясните разницу одним-двумя предложениями.
3. **Найдите IP.** С помощью `docker network inspect lesson08_backend-net` выпишите внутренние IP всех контейнеров при `--scale backend=3`. Затем выполните `docker compose exec backend python -c "import socket; print(socket.gethostbyname_ex('backend'))"`. Что вернулось и почему адресов несколько?
4. **Вопросы (письменно, коротко):**
   - Почему внутри контейнера бэкенда нельзя подключиться к базе по `localhost`?
   - Чем `depends_on: [db]` отличается от `depends_on: { db: { condition: service_healthy } }`?
   - Почему нельзя просто сделать `--scale db=3`?

**В конце:** `docker compose down`.
