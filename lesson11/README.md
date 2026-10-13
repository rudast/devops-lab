# Занятие 11. Своё приложение в облаке: Terraform + cloud-init + Docker Compose

На занятии 10 мы подняли кодом пустую ВМ и nginx на ней. Сегодня на такой же ВМ заработает **приложение курса** — стек из занятий 8–9: nginx → backend → PostgreSQL + Redis. Всё поднимается одной командой `terraform apply`, а в конце его можно открыть с телефона.

```
terraform apply
   │  ВМ + группа безопасности + ключ + публичный IP
   ▼
ВМ в cloud.ru ── cloud-init (один раз, при первом старте) ─────────────────────┐
   │  apt: docker.io, git                                                       │
   │  git clone devops-lab   ·   .env с паролем из TF_VAR_db_password           │
   │  cd lesson09 && docker compose up -d --build --scale backend=N             │
   ▼                                                                            │
http://<публичный IP>/  →  nginx:80  →  backend ×N  →  PostgreSQL, Redis   ◀───┘
```

Что нового по сравнению с занятием 10:

| Было на занятии 10 | Сегодня |
|---|---|
| cloud-init ставит nginx | cloud-init поднимает весь стек занятия 9 через Docker Compose |
| `templatefile` с одной переменной | `templatefile` с пятью: имя, репозиторий, реестр, пароль, число копий бэкенда |
| паролей нет | пароль базы — через `TF_VAR_db_password` и `sensitive = true` |
| зона — первая в списке у всех (в ней кончались машины нужного типа) | зона — по хэшу имени, только там, где нужный тип ВМ есть |
| по ВМ на каждого | **одна ВМ на пару** — квота общая |

## Квоты: почему работаем в парах

В общем проекте лимит — **30 ВМ, 30 vCPU, 60 ГБ RAM, 1200 ГБ диска** на всю группу (30 человек). По одной минимальной ВМ на каждого хватило бы ровно впритык: ни запаса на ВМ преподавателя, ни на чью-то забытую машину, ни на `-replace`. Поэтому:

- работаем **командами по 2** (если нечётно — по 3): одна ВМ на команду, 14 команд + ВМ преподавателя = 15 из 30 — половина квоты в запасе;
- тип ВМ — только минимальный **s7n.medium.2** (1 vCPU / 2 ГБ), это проверяет `validation` в `variables.tf`;
- диск — минимум образа;
- зону код выбирает сам — см. `locals` в `main.tf`: зоны, где наш тип ВМ есть, и одна из них по хэшу имени ВМ. ВМ команд расходятся по разным зонам.

## Подготовка

- [ ] Занятие 10 пройдено: Terraform установлен, `~/.terraformrc` настроен, SSH-ключ есть ([подготовка занятия 10](../lesson10/README.md#подготовка)).
- [ ] Ресурсы занятия 10 удалены: `cd lesson10/practice && terraform state list` → пусто. Иначе ваша старая ВМ занимает место в квоте.
- [ ] Обновите репозиторий: `cd devops-lab && git pull`, проверьте `ls lesson11` → `README.md  HOMEWORK.md  practice  solution`.
- [ ] Найдите напарника. Работаете **с одного ноутбука**: «водитель» печатает и запускает, «штурман» читает план и ищет ответы в коде. Роли меняете после каждой части. Префикс команды — две фамилии: `ivanov-petrov`.

Ключи доступа преподаватель даст на занятии, как и в прошлый раз.

## Практика

90 минут, семь частей. Застряли больше чем на 5 минут — подсмотрите в `solution/` и двигайтесь дальше.

| Часть | Что делаем | Время |
|---|---|---|
| 1 | Подготовка: ключи, префикс команды, пароль базы | 10 мин |
| 2 | Шаблон cloud-init и `templatefile`, `sensitive` | 15 мин |
| 3 | `apply` и наблюдаем, как ВМ сама себя настраивает | 20 мин |
| 4 | Приложение в интернете | 5 мин |
| 5 | Где живёт пароль | 10 мин |
| 6 | Две копии бэкенда: `~` в плане, а копий не прибавилось | 15 мин |
| 7 | Граница Terraform и уборка | 15 мин |

### Часть 1. Подготовка (10 мин)

```bash
cd lesson11/practice
export SBC_ACCESS_KEY="…"  SBC_SECRET_KEY="…"         # ключи от преподавателя
cp terraform.tfvars.example terraform.tfvars           # впишите prefix команды: ivanov-petrov
export TF_VAR_db_password="$(openssl rand -hex 12)"    # пароль базы — 24 случайных символа
echo ${#TF_VAR_db_password}                            # 24 — длина, сам пароль не печатаем
terraform init
```

`TF_VAR_<имя>` — так Terraform читает переменную из окружения. Пароль не лежит ни в одном файле: ни в Git, ни в `terraform.tfvars`. Как и `export` ключей, он живёт только в этом окне терминала.

> Откройте `variables.tf` и найдите проверку у `db_password`: только латинские буквы и цифры, не короче 12. Почему так строго? Пароль попадёт в строку подключения `postgresql://app:<пароль>@db:5432/appdb`, и символы `@`, `:` или `/` её сломают.

### Часть 2. Шаблон cloud-init и templatefile (15 мин)

Вся настройка ВМ — в одном файле. Прочитайте его вдвоём:

```bash
cat cloud-init.yaml.tftpl
```

| Блок | Что делает |
|---|---|
| `packages` | ставит Docker и git |
| `write_files` → `/opt/app.env` | пишет `.env` для docker-compose.yml занятия 9 — с паролем |
| `write_files` → `/opt/start-app.sh` | скрипт запуска: Docker Compose, образы из реестра курса, `git clone`, `docker compose up` |
| `runcmd` | запускает скрипт и пишет лог в `/var/log/start-app.log` |

Найдите все подстановки `${…}` — их пять. Значения для них передаёт `templatefile` в `main.tf`. Три уже есть, **два `TODO` допишите** (подсказка — в комментарии над ними):

```bash
grep -n TODO main.tf
terraform plan        # Plan: 7 to add (группа + 2 правила, ключ, ВМ, IP, привязка)
```

Найдите в плане строку `user_data`. Там не текст шаблона, а длинная строка из букв и цифр. Это **хэш**: провайдер хранит в state только отпечаток `user_data`, чтобы заметить изменения, а сам текст — нет.

Теперь в `variables.tf` раскомментируйте у `db_password` строку `sensitive = true` и снова `terraform plan`:

```
+ user_data = (sensitive value)
```

Terraform помечает **всё, что вычислено из секрета**: `user_data` собран из шаблона с паролем, поэтому тоже скрыт.

### Часть 3. apply и наблюдаем (20 мин)

```bash
terraform apply       # ВМ создаётся 1–2 минуты
terraform output      # zone, public_ip, url, ssh_command, logs_command
```

ВМ создана, но приложение ещё нет: cloud-init только начал работу. Заходим и смотрим:

```bash
ssh root@$(terraform output -raw public_ip)
cloud-init status --wait          # ждёт конца cloud-init (3–7 минут): status: done
tail -f /var/log/start-app.log    # в соседнем окне — что происходит прямо сейчас
```

Пока ждёте, найдите в логе: скачивание образов из `ghcr.io/…`, `git clone`, сборку бэкенда (`pip install`), `docker compose up`. Последняя строка — `готово: приложение на порту 80`.

```bash
cd /opt/devops-lab/lesson09
docker compose ps                 # nginx, backend, db, cache — все Up, db и cache — healthy
exit
```

> `Connection refused` или `timed out` при `ssh` в первую минуту — ВМ ещё загружается. Подождите и повторите.

### Часть 4. Приложение в интернете (5 мин)

```bash
curl $(terraform output -raw url)              # {"service":"backend","version":"lesson-11",…}
curl $(terraform output -raw health_url)       # {"status":{"postgres":"ok","redis":"ok"},…}
curl $(terraform output -raw url)hits          # счётчик в Redis растёт
curl -X POST -H 'Content-Type: application/json' \
     -d '{"text":"привет из облака"}' $(terraform output -raw url)notes
```

Откройте `http://<public_ip>/notes` с телефона. Это то же приложение, что на занятиях 8–9 жило на ноутбуке, только теперь оно в облаке и поднимается одной командой.

### Часть 5. Где живёт пароль (10 мин)

`sensitive` скрывает значение **с экрана**. Проверим, где пароль на самом деле лежит.

**1. Output.** Раскомментируйте в `outputs.tf` блок `output "db_password"` и выполните `terraform apply` (изменятся только outputs), затем:

```bash
terraform output                      # db_password = <sensitive>  — значение скрыто
terraform output -raw db_password     # а так пароль виден целиком
```

Теперь удалите в этом блоке строку `sensitive = true` и запустите `terraform plan`. Terraform выдаст ошибку: output ссылается на переменную, помеченную как `sensitive`, поэтому сам output тоже обязан быть помечен `sensitive = true`. Верните строку на место.

**2. State.**

```bash
grep -c "$TF_VAR_db_password" terraform.tfstate     # больше нуля — пароль в state открытым текстом
```

Найдите, в каком месте state он лежит (`grep -n`). Значения outputs хранятся в state открытым текстом, даже помеченные `sensitive`. Поэтому state — секретный файл: в Git его нельзя, а в команде доступ к нему — как к паролям.

**3. ВМ.** Зайдите по SSH:

```bash
cat /opt/app.env | grep PASSWORD
curl -s http://169.254.169.254/openstack/latest/user_data | grep PASSWORD
```

Второй командой ВМ спрашивает у облака свои метаданные — тот самый `user_data`. Его может прочитать **любой процесс на ВМ**. Вывод: `user_data` — не сейф. Для учебного стенда это приемлемо, в бою секреты берут из хранилища секретов (Vault, Lockbox) при запуске.

### Часть 6. Две копии бэкенда (15 мин)

На занятии 9 вы делали `docker compose up --scale backend=2`. Здесь это переменная `backend_count`. Сначала оставим след в базе:

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"text":"запись до изменений"}' $(terraform output -raw url)notes
```

В `terraform.tfvars` поставьте `backend_count = 2` и **предскажите план**, потом проверьте:

```bash
terraform plan        # ~ sbercloud_compute_instance.app — update in-place, user_data (sensitive value)
terraform apply
ssh root@$(terraform output -raw public_ip) "cd /opt/devops-lab/lesson09 && docker compose ps backend"
```

Копия бэкенда по-прежнему **одна**. Почему? Это уже было на занятии 10: провайдер записал новый `user_data` в работающую ВМ, но cloud-init выполняется только при **первом** запуске. Нужна новая ВМ:

```bash
terraform apply -replace=sbercloud_compute_instance.app     # -/+ ВМ, публичный IP тот же
```

Через 5–7 минут (снова `cloud-init status --wait`) проверьте:

```bash
for i in 1 2 3 4 5 6; do curl -s $(terraform output -raw url) | grep -o '"served_by":"[^"]*"'; done   # два разных served_by
curl -s $(terraform output -raw url)notes          # а где «запись до изменений»?
```

Записи нет: база жила на диске старой ВМ, и `-replace` удалил её вместе с ВМ. Вот почему в бою базу держат **отдельно** — на отдельной ВМ с отдельным диском или в управляемом сервисе облака — а ВМ приложения делают одноразовыми.

### Часть 7. Граница Terraform и уборка (15 мин)

Зайдите на ВМ и «сломайте» приложение руками:

```bash
ssh root@$(terraform output -raw public_ip) "cd /opt/devops-lab/lesson09 && docker compose stop backend"
curl -i $(terraform output -raw url)          # 502 или 504 — знакомо по занятию 9
terraform plan                                # No changes!
```

Приложение лежит, а Terraform считает, что всё в порядке. **Terraform управляет ресурсами облака** — ВМ, сетью, IP, — а не тем, что запущено внутри ВМ. За содержимым серверов следят другие инструменты: системы управления конфигурацией (Ansible), мониторинг и проверки здоровья.

Починить можно двумя способами — обсудите, какой «правильный»:
- `ssh … docker compose start backend` — быстро, но руками;
- `terraform apply -replace=…` — по коду, но новая ВМ и потеря данных.

Уборка:

```bash
terraform destroy
terraform state list       # пусто
```

### Задания для тех, кто закончил раньше

1. Добавьте переменную `app_version` и передайте её в шаблон вместо `lesson-11` в строке `APP_VERSION`. После `-replace` проверьте `curl $(terraform output -raw url)`.
2. Выведите output `notes_url` — адрес страницы заметок.
3. В `/var/log/start-app.log` найдите, сколько секунд заняли скачивание образов и сборка бэкенда. Что дольше и почему?

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `No value for required variable` … `db_password` | Не задан `TF_VAR_db_password` в этом окне | `export TF_VAR_db_password="$(openssl rand -hex 12)"` |
| `Invalid value for variable` … `db_password` | В пароле спецсимволы или он короче 12 | Сгенерируйте `openssl rand -hex 12` |
| `Invalid reference` … `TODO` | Не выполнено задание части 2 | Подставьте `var.db_password` и `var.backend_count` |
| `Invalid template interpolation value` / `vars map does not contain key` | В карте `templatefile` нет переменной, которая есть в шаблоне | Сверьте пять подстановок `${…}` с картой |
| `Output refers to sensitive values` | У output с паролем нет `sensitive = true` | Добавьте `sensitive = true` в блок output |
| `Invalid value for variable` … `s7n.medium.2` | Задан другой тип ВМ | Оставьте `vm_flavor` по умолчанию |
| `Quota exceeded` при apply | Кончились vCPU/ВМ в проекте — чьи-то ВМ не удалены | Сообщите преподавателю; проверьте, что ВМ занятия 10 удалена |
| `cloud-init status` → `error` | Скрипт запуска упал | `tail -50 /var/log/start-app.log` — ищите последнюю ошибку |
| В логе ошибка `docker pull ghcr.io/…` | Нет доступа к реестру | Повторите: `bash /opt/start-app.sh > /var/log/start-app.log 2>&1` |
| `curl` → `Connection refused` после `status: done` | Стек не поднялся | `cd /opt/devops-lab/lesson09 && docker compose ps` и `docker compose logs backend` |
| `/health` → `postgres: error` | База ещё стартует | Подождите 10–20 секунд |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` после `-replace` | Новая ВМ на том же IP | `ssh-keygen -R <IP>` (как на занятии 10) |

## ⛔ Главное правило: ресурсы не оставляем

ВМ и публичный IP стоят денег и занимают общую квоту, пока существуют. В конце занятия:

```bash
terraform destroy
terraform state list       # пусто
```

## Домашнее задание

**Срок — до занятия 12.** Как сдавать: заполните шаблон [HOMEWORK.md](HOMEWORK.md) (скопируйте, назовите `ДЗ-11-фамилия.md`) и отправьте файлом в чат группы. ДЗ — **индивидуальное**.

> **ДЗ делается без `apply`** — только `terraform plan`. Квота общая: 30 ВМ на всю группу, и дома каждый `apply` отнимает место у занятия. `plan` ничего не создаёт и квоту не тратит.

Работайте в копии: `cp -r solution hw && cd hw && rm -rf .terraform terraform.tfstate*`. В `terraform.tfvars` — префикс **`<фамилия>-hw`**. Пароль: `export TF_VAR_db_password="$(openssl rand -hex 12)"`.

1. **Версия приложения.** Добавьте переменную `app_version` (строка, по умолчанию `"lesson-11"`) и передайте её в шаблон вместо `lesson-11` в строке `APP_VERSION`. Приложите изменённые места трёх файлов (`variables.tf`, `main.tf`, `cloud-init.yaml.tftpl`) и итоговую строку `terraform plan`.
2. **Проверка SSH.** Добавьте к `allowed_ssh_cidr` `validation`: значение должно быть корректным CIDR (подсказка: `can(cidrhost(var.allowed_ssh_cidr, 0))`). Покажите ошибку `plan` для `allowed_ssh_cidr = "мой-ip"` и успешный `plan` для `"203.0.113.25/32"`.
3. **Output `notes_url`.** Добавьте output с адресом страницы заметок. Что показывает `plan` для него и почему?
4. **Вопросы (письменно, коротко):**
   - Почему после `backend_count = 2` и `apply` копий бэкенда не прибавилось? Что сделал `-replace` и что при этом потерялось?
   - Где в итоге хранится пароль базы: перечислите все места, которые нашли в части 5. Что из этого защищает `sensitive = true`, а что — нет?
   - Почему после `docker compose stop backend` план пустой? Каким инструментом следят за тем, что запущено внутри ВМ?
   - Зачем зону выбирать по хэшу имени, а не брать первую из списка? Зачем `ignore_changes = [availability_zone, image_id]`?
5. **Уборка:** приложите вывод `terraform state list` в папке `hw` — он должен быть **пустым** (вы делали только `plan`).

**Что сдать** — всё по шаблону [HOMEWORK.md](HOMEWORK.md): код, выводы команд и ответы. **Без** `terraform.tfvars`, `terraform.tfstate`, ключей и пароля.
