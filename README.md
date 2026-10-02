# devops-lab — учебный проект для модулей 3–4

Сервис: **backend (Flask) + PostgreSQL + Redis**, дальше — **Nginx**, **CI/CD** и деплой в облако cloud.ru.

| Эндпоинт | Что делает |
|---|---|
| `GET /` | версия и имя контейнера (`served_by`), который ответил |
| `GET /health` | проверяет связь с PostgreSQL и Redis (200 / 503) |
| `GET /hits` | счётчик в Redis |
| `GET/POST /notes` | заметки в PostgreSQL: `{"text": "..."}` |

**Перед первым занятием** пройдите раздел [«Подготовка ноутбука»](#подготовка-ноутбука) — на практике времени на установку не будет.

## Содержание
- [Подготовка ноутбука](#подготовка-ноутбука)
  - [Docker в Ubuntu (VirtualBox)](#docker-и-docker-compose-в-ubuntu-вм-virtualbox)
  - [Docker на macOS](#docker-и-docker-compose-на-macos)
  - [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr)
  - [Зеркала Docker Hub (запасной вариант)](#зеркала-docker-hub-запасной-вариант)
- [Занятие 8. Docker Compose](#занятие-8-docker-compose)
- [Занятие 9. Nginx перед бэкендом + конфигурация и секреты](#занятие-9-nginx-перед-бэкендом--конфигурация-и-секреты)
- [Занятие 10. IaC: своя ВМ в cloud.ru через Terraform](#занятие-10-infrastructure-as-code-своя-вм-в-cloudru-через-terraform)
- [Занятие 11. CI: проверяем и собираем образ](#занятие-11-ci-проверяем-и-собираем-образ-автоматически)
- [Занятие 12. CD: деплой без рук](#занятие-12-cd-деплой-без-рук)
- [Если что-то не работает](#если-что-то-не-работает)

## Структура репозитория

```
app/                      код, Dockerfile, тесты
lesson08/                 docker-compose.yml с захардкоженными паролями (так делать НЕ надо)
lesson09/                 + Nginx (reverse proxy) перед бэкендом, конфигурация в .env
lesson10/practice/        занятие 10: ваша рабочая папка Terraform
lesson10/steps/           шаги 01…05: data sources, firewall, SSH-ключ, ВМ + IP, nginx через cloud-init
lesson10/terraform/       готовое решение занятия 10 (ответы)
lesson10/shared/          общая сеть курса (запускает преподаватель)
lesson10/ansible/         Ansible: Docker на ВМ и выкатка стека (понадобится позже)
lesson12/                 production compose: бэкенд из GHCR, деплой из CI/CD
.github/workflows/        CI/CD-пайплайн (занятия 11–12) и копирование образов в GHCR
scripts/pull-images.sh    скачать образы курса из GHCR
```

---

## Подготовка ноутбука

Выберите свою ОС: на Windows всё ставится внутрь виртуальной машины Ubuntu (VirtualBox), на Mac — напрямую. Установка Docker расписана ниже отдельно для [Ubuntu](#docker-и-docker-compose-в-ubuntu-вм-virtualbox) и [macOS](#docker-и-docker-compose-на-macos).

| Инструмент | Зачем | Занятие |
|---|---|---|
| Docker + Docker Compose | запуск контейнеров | 8–12 |
| Git + аккаунт GitHub + SSH-ключ | код, CI/CD | 8–12 |
| git-filter-repo | чистка истории от секретов | 9 |
| Terraform | создание ВМ в облаке | 10 |
| Ansible | настройка ВМ | позже |
| Редактор (VS Code) | удобно, но не обязательно | — |

### Windows → VirtualBox + Ubuntu Server

На Windows работаем внутри виртуальной машины с Ubuntu Server: там те же команды, что на серверах в облаке, и работает Ansible. Docker ставим **внутрь ВМ**, Docker Desktop на Windows для курса не нужен.

**Требования:** 8 ГБ ОЗУ на ноутбуке (ВМ заберёт 4 ГБ), 30 ГБ свободного места, включённая виртуализация (Intel VT-x / AMD-V) в BIOS.

#### 1. Установка ВМ
1. Скачайте и установите [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (Windows hosts).
2. Скачайте образ [Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server) (`.iso`).
3. VirtualBox → **Создать**: имя `devops`, ISO — скачанный образ, галочку «Пропустить автоматическую установку» **поставить**. Ресурсы: **2 CPU, 4096 МБ RAM, диск 25 ГБ**.
4. Запустите ВМ и пройдите установщик Ubuntu. Всё по умолчанию, кроме двух моментов:
   - придумайте имя пользователя и пароль (запомните!);
   - на шаге **SSH Setup** отметьте **Install OpenSSH server**.
5. После установки: **Reboot Now**, при запросе извлеките ISO (Устройства → Оптические диски).

#### 2. Проброс портов (чтобы заходить из Windows)
Выключите ВМ → **Настроить → Сеть → Адаптер 1 (NAT) → Дополнительно → Проброс портов** и добавьте правила:

| Имя | Порт хоста | Порт гостя | Зачем |
|---|---|---|---|
| ssh | 2222 | 22 | подключаться к ВМ по SSH |
| app | 8000 | 8000 | backend (занятия 8–9) |
| app1 | 8001 | 8001 | реплики при `--scale` |
| app2 | 8002 | 8002 | реплики при `--scale` |
| web | 8080 | 80 | nginx |

Протокол TCP, IP-адреса оставьте пустыми.

#### 3. Подключение из Windows
Запустите ВМ (можно «Запустить → Запуск в фоновом режиме») и работайте из **Windows Terminal / PowerShell**, а не из окна VirtualBox — так работает копирование и вставка:
```powershell
ssh -p 2222 <ваш_пользователь>@localhost
```
Удобнее всего — **VS Code** с расширением **Remote - SSH**: Connect to Host → `<ваш_пользователь>@localhost:2222`. Редактируете файлы прямо внутри ВМ.

#### 4. Всё остальное — внутри ВМ
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install -y git curl unzip ansible pipx
pipx ensurepath && pipx install git-filter-repo
```
Docker и Docker Compose — см. раздел [Docker в Ubuntu](#docker-и-docker-compose-в-ubuntu-вм-virtualbox) ниже.

Terraform — см. раздел [Terraform](#terraform-для-всех) ниже (версия **linux_amd64**). SSH-ключ для GitHub создавайте **внутри ВМ**.

> **В браузере Windows** сервисы ВМ открываются по проброшенным портам: `http://localhost:8000`, nginx — `http://localhost:8080`.
> **Если ВМ не стартует** с ошибкой про VT-x/AMD-V — включите виртуализацию в BIOS. Если VirtualBox работает очень медленно (черепаха в строке состояния) — отключите Hyper-V: PowerShell от администратора `bcdedit /set hypervisorlaunchtype off` и перезагрузка (Docker Desktop и WSL после этого работать не будут — для курса они не нужны).

### macOS

Нужен [Homebrew](https://brew.sh).
```bash
brew install git ansible git-filter-repo
```
Docker и Docker Compose — см. раздел [Docker на macOS](#docker-и-docker-compose-на-macos) ниже.
Terraform — см. следующий раздел (версия **darwin_arm64** для Mac на M1–M4, **darwin_amd64** для Intel).

### Docker и Docker Compose в Ubuntu (ВМ VirtualBox)

Ставим **Docker Engine** из официального репозитория Docker. Compose идёт плагином — команда `docker compose` (через пробел). Все команды — внутри ВМ.

1. Удалите старые/неофициальные пакеты, если они есть (ошибки «not installed» — это нормально):
   ```bash
   for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
     sudo apt-get remove -y $pkg
   done
   ```
2. Подключите репозиторий Docker:
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc

   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
   https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```
3. Установите Docker Engine, Buildx и Compose:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
4. Разрешите запускать docker без `sudo` и включите автозапуск:
   ```bash
   sudo usermod -aG docker $USER
   sudo systemctl enable --now docker
   exit            # выйдите из SSH и подключитесь снова — иначе группа не применится
   ```
5. Проверка (после повторного входа):
   ```bash
   docker version
   docker compose version        # Docker Compose version v2.x или новее
   docker run --rm hello-world   # «Hello from Docker!»
   ```
6. **Скачайте образы курса из нашего реестра** — см. раздел [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr). Docker Hub из России работает нестабильно.

> Короткий путь для тех, кто торопится: `curl -fsSL https://get.docker.com | sudo sh` — официальный скрипт делает шаги 1–3 сам. Шаги 4 и 6 всё равно нужны.

### Docker и Docker Compose на macOS

На Mac ставим **Docker Desktop** — в него уже входят Docker Engine, Compose и Buildx.

1. Узнайте процессор: меню Apple → «Об этом Mac». **Apple M1/M2/M3/M4** → версия *Apple Silicon*, **Intel** → версия *Intel chip*.
2. Установите одним из способов:
   - скачайте `.dmg` с https://docs.docker.com/desktop/setup/install/mac-install/ и перетащите Docker в «Программы»;
   - или через Homebrew: `brew install --cask docker`
3. Запустите **Docker** из «Программ», примите соглашение и дождитесь зелёного статуса *Engine running* (значок кита в строке меню).
4. Рекомендуемые настройки: **Settings → Resources** — CPU 2+, Memory 4 ГБ+; **Settings → General** — включить *Start Docker Desktop when you sign in* (по желанию).
5. Проверка в терминале:
   ```bash
   docker version
   docker compose version
   docker run --rm hello-world
   ```
6. **Скачайте образы курса из нашего реестра** — см. раздел [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr).

> На Mac с Apple Silicon все образы курса (`postgres`, `redis`, `nginx`, `python`) есть в версии arm64 — ничего дополнительно настраивать не нужно.

### Образы курса из нашего реестра (GHCR)

Docker Hub из России работает нестабильно, поэтому все базовые образы курса скопированы в **GitHub Container Registry** этого репозитория (`ghcr.io/tenroman1-design/devops-lab/...`). Их обновляет workflow `mirror-images` раз в месяц; образы собраны для amd64 (ВМ) и arm64 (Mac на M1–M4).

| Привычное имя | Копия в нашем реестре |
|---|---|
| `postgres:17-alpine` | `ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine` |
| `redis:7-alpine` | `ghcr.io/tenroman1-design/devops-lab/redis:7-alpine` |
| `python:3.12-slim` | `ghcr.io/tenroman1-design/devops-lab/python:3.12-slim` |
| `nginx:1.27-alpine` | `ghcr.io/tenroman1-design/devops-lab/nginx:1.27-alpine` |
| `hello-world:latest` | `ghcr.io/tenroman1-design/devops-lab/hello-world:latest` |
| `zricethezav/gitleaks:latest` | `ghcr.io/tenroman1-design/devops-lab/gitleaks:latest` |

**Скачать всё одной командой** — скрипт скачает образы из GHCR и даст им привычные имена, поэтому `docker-compose.yml` и `Dockerfile` работают без изменений:
```bash
git clone https://github.com/tenroman1-design/devops-lab.git && cd devops-lab
bash scripts/pull-images.sh
```
Без клонирования репозитория:
```bash
curl -fsSL https://raw.githubusercontent.com/tenroman1-design/devops-lab/main/scripts/pull-images.sh | bash
```
Вручную, для одного образа:
```bash
docker pull ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine
docker tag  ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine postgres:17-alpine
```
Логин в GHCR не нужен — пакеты публичные.

### Зеркала Docker Hub (запасной вариант)

Если нужен образ, которого нет в нашем реестре, а `docker pull` зависает на `Waiting` / `Pulling fs layer` или падает с `TLS handshake timeout`, `403`, `toomanyrequests` — подключите зеркала Docker Hub. Docker перебирает их по порядку и только в конце идёт в сам Docker Hub.

| Зеркало | Кто поддерживает |
|---|---|
| `https://dh-mirror.gitverse.ru` | GitVerse (СберТех) |
| `https://dockerhub.timeweb.cloud` | Timeweb Cloud |
| `https://dockerhub1.beget.com` | Beget |
| `https://mirror.gcr.io` | Google |

**Ubuntu (ВМ):**
```bash
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://dh-mirror.gitverse.ru",
    "https://dockerhub.timeweb.cloud",
    "https://dockerhub1.beget.com",
    "https://mirror.gcr.io"
  ],
  "max-concurrent-downloads": 3
}
EOF
sudo systemctl restart docker
docker info | grep -A4 "Registry Mirrors"     # должны быть видны все четыре
docker pull hello-world
```

**macOS:** Docker Desktop → **Settings → Docker Engine** → добавьте в JSON ключ `registry-mirrors` с тем же списком (остальные ключи, которые там уже есть, не удаляйте) → **Apply & restart**.

**Если какой-то образ всё равно не качается** — скачайте его напрямую с зеркала и дайте привычное имя:
```bash
docker pull dh-mirror.gitverse.ru/library/postgres:17-alpine          # официальные образы — через library/
docker tag  dh-mirror.gitverse.ru/library/postgres:17-alpine postgres:17-alpine

docker pull dh-mirror.gitverse.ru/zricethezav/gitleaks:latest         # образы пользователей — как есть
docker tag  dh-mirror.gitverse.ru/zricethezav/gitleaks:latest zricethezav/gitleaks:latest
```
Прерывайте зависший pull через **Ctrl+C**, а не Ctrl+Z (Ctrl+Z только ставит процесс на паузу). Уже скачанные слои при повторе заново не качаются.

> Зеркала поддерживают сторонние компании, и любое из них может перестать работать — поэтому в списке их несколько. Если недоступны все, преподаватель раздаст образы архивом: `docker load -i images.tar`.

### Terraform (для всех)

Сайт HashiCorp и реестр Terraform из России недоступны, поэтому используем **зеркало cloud.ru**.

1. Скачайте архив для своей платформы: https://tf-mirror-distr.obs-website.ru-moscow-1.hc.sbercloud.ru/
2. Распакуйте и положите бинарник в PATH:
   ```bash
   unzip terraform_*.zip
   sudo mv terraform /usr/local/bin/
   terraform -version
   ```
   > macOS может заблокировать запуск скачанного файла: `xattr -d com.apple.quarantine /usr/local/bin/terraform`
3. Создайте файл `~/.terraformrc`, чтобы провайдеры тоже качались с зеркала:
   ```hcl
   provider_installation {
     network_mirror {
       url     = "https://terraform.cloud.ru/"
       include = ["registry.terraform.io/*/*"]
     }
     direct {
       exclude = ["registry.terraform.io/*/*"]
     }
   }
   ```

### Git, GitHub и SSH-ключ (для всех)

```bash
git config --global user.name  "Имя Фамилия"
git config --global user.email "you@edu.hse.ru"
ssh-keygen -t ed25519 -C "you@edu.hse.ru"     # Enter на все вопросы
cat ~/.ssh/id_ed25519.pub                     # скопировать → GitHub: Settings → SSH and GPG keys → New SSH key
ssh -T git@github.com                         # «Hi <login>! You've successfully authenticated»
```

### Скачайте образы заранее

Чтобы не ждать сеть в аудитории — из нашего реестра (см. [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr)):
```bash
bash scripts/pull-images.sh
```

### Финальная проверка

```bash
docker compose version && git --version && terraform -version && ansible --version && git filter-repo --version
git clone https://github.com/tenroman1-design/devops-lab.git && cd devops-lab
bash scripts/pull-images.sh
```
Все команды отработали без ошибок — вы готовы. Если нет — напишите в чат группы текст ошибки и свою ОС.

---

## Занятие 8. Docker Compose

```bash
cd lesson08
docker compose up -d --build          # собрать и запустить
docker compose ps                     # все сервисы healthy?
curl localhost:8000/health            # {"status": {"postgres":"ok","redis":"ok"}}
curl localhost:8000/hits              # счётчик растёт
curl -X POST -H 'Content-Type: application/json' -d '{"text":"hello"}' localhost:8000/notes
```

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
Попробуйте заменить `"8000-8005:8000"` на `"8000:8000"` и снова `--scale backend=3` — увидите ошибку *port is already allocated*. Почему? Как это решит Nginx — на занятии 9.

---

## Занятие 9. Nginx перед бэкендом + конфигурация и секреты

Продолжаем стек занятия 8. Проблема, на которой мы остановились: при `--scale backend=3` каждой копии нужен свой порт на хосте, и пользователю непонятно, куда стучаться. Решение — **reverse proxy**: наружу открыт только Nginx, а он сам раздаёт запросы копиям бэкенда. Заодно убираем пароли из compose-файла в `.env`.

```
браузер ──:80──▶ nginx ──▶ backend ×N ──▶ postgres, redis
                 (frontend-net)        (backend-net)
```

### Часть 1. Reverse proxy (40 мин)
```bash
cd lesson09
docker compose -f ../lesson08/docker-compose.yml down     # погасить стек занятия 8, чтобы освободить порты
cp .env.example .env                                     # впишите свой пароль (подробнее — в части 2)
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

**Что посмотреть в `nginx/nginx.conf`:** `upstream` с одной строкой `server backend:8000 resolve` (почему одной — объяснено в комментариях), `proxy_pass`, заголовки `X-Forwarded-*`, `location = /nginx-health`.

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
4. Переведите пароль Postgres на Docker secrets: `POSTGRES_PASSWORD_FILE` + раздел `secrets:` в compose.

---

## Занятие 10. Infrastructure as Code: своя ВМ в cloud.ru через Terraform

На занятиях 8–9 стек жил на ноутбуке. Сегодня мы своими руками описываем в коде виртуальную машину в облаке, создаём её Terraform'ом, кладём на неё свой SSH-ключ и подключаемся. Затем меняем инфраструктуру и учимся читать план: что изменится на месте, а что будет пересоздано.

**Как устроено:** все работают в **одном общем проекте** cloud.ru. Ключи доступа выдаёт преподаватель. Сеть (VPC и подсеть) уже создана заранее, папка `lesson10/shared`. Каждый создаёт свои ресурсы с префиксом — своей фамилией: `ivanov-vm`, `ivanov-sg`, `ivanov-key`, `ivanov-eip`.

> ⚠️ В общем проекте видны ресурсы всех студентов. **Трогайте только свои** (с вашим префиксом). Terraform удаляет лишь то, что записано в **вашем** state.

```
lesson10/
  practice/   ← здесь работаете вы: стартовые versions.tf, variables.tf
  steps/      ← файлы шагов 01…05: копируете в practice по одному
  terraform/  ← готовое решение (ответы) — подглядывайте, если застряли
  shared/     ← общая сеть курса (запускает только преподаватель)
```

Перед занятием: Terraform и `~/.terraformrc` с зеркалом (см. [подготовку](#terraform-для-всех)) и SSH-ключ `~/.ssh/id_ed25519` (см. [Git, GitHub и SSH-ключ](#git-github-и-ssh-ключ-для-всех)). Студентам на Windows всё нужно делать **внутри ВМ VirtualBox**.

### Часть 1. Подготовка (10 мин)
```bash
cd devops-lab/lesson10/practice
export SBC_ACCESS_KEY="…"  SBC_SECRET_KEY="…"   # выдаст преподаватель. НЕ в файлы, НЕ в Git
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519   # нет ключа — создайте (Enter на все вопросы)
cp terraform.tfvars.example terraform.tfvars        # впишите prefix = "вашафамилия"
terraform init          # скачает провайдер sbercloud с зеркала
terraform validate      # синтаксис в порядке?
terraform plan          # пока: No changes — в папке ещё нет ресурсов
```
> Переменные `SBC_*` живут только в текущем окне терминала: в новом окне сделайте `export` заново.

### Часть 2. Собираем ВМ по шагам (25 мин)
Каждый шаг выполняется одинаково: скопировать файл, прочитать его, выполнить **задание** внутри (если есть), затем `terraform plan` → прочитать план → `terraform apply`.

| Шаг | Файл | Что создаём | В плане | Задание |
|---|---|---|---|---|
| 1 | `01-data.tf` | ничего — **читаем** образ Ubuntu, тип ВМ, общую сеть | `0 to add`, outputs | — |
| 2 | `02-firewall.tf` | группа безопасности + правило SSH | `2 to add` | впишите порт SSH вместо `TODO_PORT` |
| 3 | `03-keypair.tf` | ваш **публичный** ключ в облаке | `1 to add` | сошлитесь на переменную с путём к ключу |
| 4 | `04-vm.tf` | ВМ + публичный IP + их связка | `3 to add` | сошлитесь на имя ключа из шага 3 |

```bash
cp ../steps/01-data.tf .
terraform plan && terraform apply
# … и так далее: 02, 03, 04
terraform output                      # все выходные значения
```
> Ошибка `Invalid reference … TODO_…` означает, что задание шага ещё не выполнено. Прочитайте сообщение: Terraform показывает файл и строку.
> На шаге 3 сравните отпечатки: `terraform output key_fingerprint` и `ssh-keygen -lf ~/.ssh/id_ed25519.pub`.

### Часть 3. Подключаемся к ВМ (15 мин)
ВМ загружается 1–2 минуты после `apply`.
```bash
ssh root@$(terraform output -raw public_ip)
# первый вход: "Are you sure you want to continue connecting?" → yes (отпечаток сервера сохранится в ~/.ssh/known_hosts)
```
На ВМ осмотритесь:
```bash
hostname                        # ваша-фамилия-vm
cat ~/.ssh/authorized_keys      # ваш публичный ключ — сравните с cat ~/.ssh/id_ed25519.pub на ноутбуке
ip -4 addr                      # внутренний адрес 192.168.x.x — а заходили вы по публичному (EIP)
nproc; free -h; df -h /         # сколько ресурсов описали в коде — столько и получили
exit
```
Проверьте, что вход **только по ключу**:
```bash
ssh -o PubkeyAuthentication=no root@<IP>    # Permission denied — пароля нет, и это правильно
```

### Часть 4. Меняем инфраструктуру и читаем план (20 мин)
1. **Изменение на месте (`~`).** В `04-vm.tf` добавьте тег `lesson = "10"` в `tags` → `terraform plan`: `~ update in-place` → `apply`.
2. **Пересоздание правила (`-/+`).** Закройте SSH для всех, кроме себя. Узнайте свой IP: `curl -s ifconfig.me`. В `terraform.tfvars` пропишите `allowed_ssh_cidr = "<IP>/32"`. Выполните `terraform plan`: правило будет `-/+ must be replaced`, ищите в плане `# forces replacement`. Затем `apply` и проверьте, что `ssh` по-прежнему работает.
3. **Пересоздание ВМ с cloud-init.** Ставим nginx при старте машины:
   ```bash
   cp ../steps/05-http.tf ../steps/cloud-init.yaml.tftpl .
   ```
   В `04-vm.tf` внутрь ресурса `sbercloud_compute_instance.vm` добавьте:
   ```hcl
   user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", { prefix = var.prefix })
   ```
   ```bash
   terraform fmt                 # выровнять код
   terraform plan                # ВМ: -/+ (user_data forces replacement), правило HTTP: + create, EIP — без изменений!
   terraform apply
   curl http://$(terraform output -raw public_ip)/      # «Привет! Эту ВМ создал …» (через 1–2 мин после apply)
   ssh root@$(terraform output -raw public_ip)          # WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
   ssh-keygen -R $(terraform output -raw public_ip)     # это новая ВМ с новым ключом сервера — забываем старый
   ```
   > IP остался прежним, потому что EIP — отдельный ресурс. Машина же новая: всё, что вы руками сделали на старой, пропало. Поэтому в IaC настройку описывают в коде, а не делают руками.

### Часть 5. Дрейф, state и пересоздание с нуля (10 мин)
```bash
# Дрейф: в консоли cloud.ru переименуйте СВОЮ ВМ (например, в <prefix>-vm-renamed), затем:
terraform plan                     # Terraform заметил расхождение и предлагает вернуть имя
terraform apply

terraform state list               # что Terraform считает «своим»
terraform state show sbercloud_compute_instance.vm

terraform destroy                  # удалить всё своё (общая сеть останется)
terraform apply                    # и пересоздать с нуля одной командой — сила IaC
terraform destroy                  # в конце занятия — обязательно (ресурсы стоят денег)
```

### Задания для тех, кто закончил раньше
1. **Короткое имя для SSH.** Добавьте в `~/.ssh/config` блок `Host hse-vm` с `HostName <IP>`, `User root` и `IdentityFile ~/.ssh/id_ed25519`. После этого вход выполняется командой `ssh hse-vm`.
2. **Диск.** Поставьте `vm_disk_size = 30` → `plan` покажет изменение на месте (`~`). После `apply` проверьте `df -h /` на ВМ. Потом попробуйте вернуть 20 и прочитайте ошибку: уменьшать диск нельзя.
3. **Пустите соседа.** Добавьте его публичный ключ в `~/.ssh/authorized_keys` на своей ВМ и проверьте, что он может войти. Затем обсудите: увидит ли это изменение `terraform plan`? Почему нет? Что станет с этим ключом после пересоздания ВМ?
4. **`terraform console`.** Посчитайте в нём `cidrhost("192.168.8.0/22", 10)`, `upper(var.prefix)`, `data.sbercloud_compute_flavors.vm.ids`.

---

## Занятие 11. CI: проверяем и собираем образ автоматически

> ⚠️ Материалы занятий 11–12 (CI/CD) ещё обновляются под новую программу — инструкции ниже могут измениться.

Продолжение занятия 10: сейчас образ бэкенда собирается прямо на сервере — долго, без тестов, и непонятно, какая версия где работает. Переносим сборку в GitHub Actions: каждый push проверяется, а из `main` собирается образ с тегом коммита и кладётся в GHCR.

1. Сделайте **Fork** этого репозитория (кнопка вверху справа) и клонируйте свой форк. Во вкладке **Actions** форка нажмите «I understand my workflows, go ahead and enable them».
2. Откройте вкладку **Actions** — пайплайн `ci-cd` запустится на push.
3. Создайте ветку, добавьте лишний импорт (`echo "import json" >> app/main.py`), откройте Pull Request — job `test` станет красным.
   > ⚠️ GitHub по умолчанию предлагает открыть PR в исходный репозиторий курса. Переключите **base repository** на свой форк.
4. Почините, смёржите в `main` — появится job `build` → образ в **Packages** (`ghcr.io/<login>/<repo>/backend:sha-…`).
5. Скачайте свой образ и запустите его локально вместо сборки — это и есть «артефакт»:
   ```bash
   docker pull ghcr.io/<login>/devops-lab/backend:latest
   ```

### Задания для тех, кто закончил раньше
1. Включите защиту ветки `main`: Settings → Branches → Require status checks to pass (`test`).
2. Добавьте в job `test` шаг сканирования секретов — продолжение занятия 9:
   ```yaml
   - uses: actions/checkout@v7
     with: { fetch-depth: 0 }
   - name: Gitleaks
     working-directory: .
     run: docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest git /repo -v
   ```
3. Напишите ещё один тест в `app/tests/test_app.py` — например, что `/` возвращает поле `service`.

---

## Занятие 12. CD: деплой без рук

Продолжение занятий 10 и 11: на занятии 10 мы выкатывали стек командой `ansible-playbook deploy.yml` с ноутбука, на занятии 11 научились собирать образ в CI. Теперь соединяем: после мёржа в `main` пайплайн **сам** заходит на ВМ, скачивает свежий образ из GHCR и перезапускает стек (`lesson12/docker-compose.prod.yml` — тот же стек, но бэкенд берётся из реестра, а не собирается на сервере). Имя проекта то же (`devops-lab`), поэтому стек занятия 10 просто заменяется, а данные в томе сохраняются.

В репозитории: **Settings → Secrets and variables → Actions**

| Тип | Имя | Значение |
|---|---|---|
| Secret | `SSH_HOST` | публичный IP ВМ |
| Secret | `SSH_USER` | `deploy` |
| Secret | `SSH_PRIVATE_KEY` | приватный ключ, чей публичный ключ добавлен пользователю deploy |
| Secret | `POSTGRES_USER` / `POSTGRES_PASSWORD` | те же, что на занятии 10 (иначе Postgres не пустит: пароль уже записан в томе) |
| Variable | `DEPLOY_ENABLED` | `true` |

> Ключ для CI сделайте отдельный: `ssh-keygen -t ed25519 -N '' -f ~/.ssh/ci_deploy` и `ssh-copy-id -i ~/.ssh/ci_deploy.pub deploy@<IP>`.

Push в `main` → test → build → deploy → smoke test. Проверка:
```bash
curl http://<IP>/            # version = sha-<коммит>
ssh deploy@<IP> "cd /opt/app && docker compose up -d --scale backend=3"   # nginx сам увидит новые реплики через ~5 с
for i in $(seq 6); do curl -s http://<IP>/hits; echo; done   # запросы идут на разные реплики
```

**Откат:** Actions → откройте прошлый успешный запуск `ci-cd` → **Re-run all jobs** — пересоберётся и выкатится тот коммит.

### Задания для тех, кто закончил раньше
1. Включите ручное подтверждение деплоя: Settings → Environments → `production` → Required reviewers. Получится Continuous Delivery.
2. Сломайте `/health`: в `app/main.py` замените `(200 if ok else 503)` на `503` и запушьте. Тесты пройдут (без базы они и ждут 503), деплой выкатится, а smoke test покрасит пайплайн в красный. Откатитесь через Re-run прошлого успешного запуска.
3. Замените ssh-шаги в job `deploy` на вызов `ansible-playbook` из занятия 10.

---

## Если что-то не работает

Первое действие всегда: `docker compose ps` → `docker compose logs <сервис>`.

| Симптом | Причина | Решение |
|---|---|---|
| `Cannot connect to the Docker daemon` / `permission denied` на docker.sock | Docker не запущен / пользователь не в группе docker | macOS: запустить Docker Desktop; ВМ: `sudo usermod -aG docker $USER` и перелогиниться |
| Windows: `localhost:8000` не открывается | Нет проброса порта в VirtualBox | Настроить → Сеть → Проброс портов |
| `port is already allocated` | Порт занят другим контейнером | `docker ps`, остановить лишнее или сменить порт |
| backend: `Connection refused` к БД | `localhost` вместо имени сервиса | В URL должно быть `db`, не `localhost` |
| `pull` висит на `Waiting` / TLS handshake timeout / 403 / toomanyrequests | Нет доступа к Docker Hub | [Образы из GHCR](#образы-курса-из-нашего-реестра-ghcr) или [зеркала](#зеркала-docker-hub-запасной-вариант) |
| `pull` висит на `Waiting` на всех слоях сразу, даже после перезапуска | Остались процессы `docker pull`, остановленные через Ctrl+Z, и недокачанные куски | `pkill -9 -f "docker pull"`; `sudo systemctl stop docker docker.socket containerd`; `sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/*`; `sudo systemctl start containerd docker` |
| `password authentication failed` | Том создан со старым паролем | `docker compose down -v` (данные удалятся) |
| `terraform init`: провайдер не скачивается | Нет `~/.terraformrc` с зеркалом | См. [Terraform](#terraform-для-всех) |
| `No valid credential sources found` | Нет `SBC_ACCESS_KEY` / `SBC_SECRET_KEY` в этом окне терминала | `export …` в том же окне |
| `Invalid value for variable` (prefix) | Префикс с заглавными/кириллицей/пробелом | Только строчная латиница, цифры, дефис: `ivanov` |
| `Invalid reference … TODO_…` | Задание шага не выполнено | Замените TODO по подсказке в комментарии файла |
| `no such file` в `file(pathexpand(…))` | Нет SSH-ключа | `ssh-keygen -t ed25519` |
| `Your query returned no results` (образ / VPC) | Другое имя образа или сеть курса не создана | Спросить преподавателя; `image_name_regex`, `vpc_name` в tfvars |
| `already exists` / `name … is duplicated` | Такой префикс уже занят другим студентом | Взять другой префикс (например, `ivanov2`) |
| `quota` / `Insufficient …` | Кончились квоты общего проекта | Сказать преподавателю, работать в паре |
| `ssh: Connection timed out` | ВМ ещё грузится / правило SSH не с вашего IP | Подождать 1–2 мин; проверить `allowed_ssh_cidr` и `curl -s ifconfig.me` |
| `Permission denied (publickey)` | Не тот ключ / не тот пользователь | `ssh -i ~/.ssh/id_ed25519 root@<IP>`; ключ из шага 3 должен быть ваш |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | ВМ пересоздана на том же IP | `ssh-keygen -R <IP>` |
| Job `deploy` — skipped | Нет переменной `DEPLOY_ENABLED=true` | Settings → Secrets and variables → Actions → **Variables** |

## Не забудьте

После окончания курса удалите облачные ресурсы — они тарифицируются, пока существуют:
```bash
cd lesson10/practice && terraform destroy
```
