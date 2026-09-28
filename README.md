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
- [Занятие 9. Конфигурация и секреты](#занятие-9-конфигурация-и-секреты)
- [Занятие 10. Terraform + Ansible](#занятие-10-terraform--ansible-cloudru)
- [Занятие 11. CI](#занятие-11-ci)
- [Занятие 12. CD + Nginx](#занятие-12-cd--nginx)
- [Если что-то не работает](#если-что-то-не-работает)

## Структура репозитория

```
app/                      код, Dockerfile, тесты
lesson08/                 docker-compose.yml с захардкоженными паролями (так делать НЕ надо)
lesson09/                 тот же compose, но конфигурация в .env
lesson10/terraform/       ВМ + сеть в cloud.ru (провайдер sbercloud)
lesson10/ansible/         установка Docker на ВМ
lesson12/                 production compose + nginx
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
| Ansible | настройка ВМ | 10 |
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
Попробуйте заменить `"8000-8005:8000"` на `"8000:8000"` и снова `--scale backend=3` — увидите ошибку *port is already allocated*. Почему? Как это решит Nginx — узнаем на занятии 12.

---

## Занятие 9. Конфигурация и секреты

```bash
cd lesson09
docker compose config                 # ошибка: required variable POSTGRES_USER is missing
cp .env.example .env                  # впишите свой пароль
docker compose config                 # видно, какие значения подставились
docker compose up -d --build
```

### Эмуляция утечки секрета (делать в ОТДЕЛЬНОЙ папке!)
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
pip install git-filter-repo
git filter-repo --invert-paths --path .env --force
git log -p --all -S "Sup3rS3cret"                  # пусто
```
Главное правило: **если секрет попал в удалённый репозиторий — считаем его скомпрометированным и меняем (ротация)**. Переписывание истории — вторично.

---

## Занятие 10. Terraform + Ansible (cloud.ru)

Нужны: Terraform с настроенным `~/.terraformrc` (см. [подготовку](#terraform-для-всех)), Ansible, ключи доступа cloud.ru.

```bash
cd lesson10/terraform
export SBC_ACCESS_KEY="..."  SBC_SECRET_KEY="..."   # ключи из консоли cloud.ru, НЕ в код
cp terraform.tfvars.example terraform.tfvars       # впишите prefix
terraform init
terraform plan
terraform apply
terraform output public_ip
```
Terraform сам создаст `../ansible/inventory.ini`. Дальше:
```bash
cd ../ansible
ansible web -m ping
ansible-playbook playbook.yml         # 1-й запуск: changed=N
ansible-playbook playbook.yml         # 2-й запуск: changed=0 — это идемпотентность
ssh deploy@<IP> docker ps             # deploy в группе docker, sudo не нужен
```
> Имя образа ОС и пользователь по умолчанию (`root`/`ubuntu`) зависят от облака — сверьтесь с консолью.
> Не забудьте в конце курса: `terraform destroy`.

---

## Занятие 11. CI

1. Сделайте **Fork** этого репозитория (кнопка вверху справа) и клонируйте свой форк. Во вкладке **Actions** форка нажмите «I understand my workflows, go ahead and enable them».
2. Откройте вкладку **Actions** — пайплайн `ci-cd` запустится на push.
3. Создайте ветку, сломайте тест или добавьте лишний импорт, откройте Pull Request — job `test` станет красным.
4. Почините, смёржите в `main` — появятся jobs `build` → образ в **Packages** (`ghcr.io/<login>/<repo>/backend`).

---

## Занятие 12. CD + Nginx

В репозитории: **Settings → Secrets and variables → Actions**

| Тип | Имя | Значение |
|---|---|---|
| Secret | `SSH_HOST` | публичный IP ВМ |
| Secret | `SSH_USER` | `deploy` |
| Secret | `SSH_PRIVATE_KEY` | приватный ключ, чей публичный ключ добавлен пользователю deploy |
| Secret | `POSTGRES_USER` / `POSTGRES_PASSWORD` | учётка БД для прода |
| Variable | `DEPLOY_ENABLED` | `true` |

Push в `main` → test → build → deploy → smoke test. Проверка:
```bash
curl http://<IP>/            # served_by меняется?
ssh deploy@<IP> "cd /opt/app && docker compose up -d --scale backend=3 && docker compose restart nginx"
for i in $(seq 6); do curl -s http://<IP>/hits; echo; done   # запросы идут на разные реплики
```

> Ключ для CI сделайте отдельный: `ssh-keygen -t ed25519 -N '' -f ~/.ssh/ci_deploy` и `ssh-copy-id -i ~/.ssh/ci_deploy.pub deploy@<IP>`.

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
| `password authentication failed` | Том создан со старым паролем | `docker compose down -v` (данные удалятся) |
| `terraform init`: провайдер не скачивается | Нет `~/.terraformrc` с зеркалом | См. [Terraform](#terraform-для-всех) |
| Ansible: `UNREACHABLE` | ВМ ещё грузится / не тот пользователь / закрыт порт 22 | Подождать 1–2 мин, проверить `ansible_user` |
| Job `deploy` — skipped | Нет переменной `DEPLOY_ENABLED=true` | Settings → Secrets and variables → Actions → **Variables** |

## Не забудьте

После окончания курса удалите облачные ресурсы — они тарифицируются, пока существуют:
```bash
cd lesson10/terraform && terraform destroy
```
