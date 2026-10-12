# Занятие 11. Terraform как проект: модули, for_each и state в облаке

На занятии 10 вся инфраструктура жила в одном файле, а state — на ноутбуке. Для одной ВМ и одного человека этого хватает. Но как только серверов несколько, а над кодом работает команда, нужно три вещи:

1. **Модуль** — описать «сервер» один раз и вызывать его как функцию.
2. **`for_each`** — создать N серверов одной картой, а не копипастой.
3. **Удалённый state с блокировкой** — хранить state в общей базе данных, чтобы вся команда видела одну и ту же картину, а два одновременных `apply` не испортили его.

```
                       ┌──────────── practice/ (корневой модуль) ────────────┐
var.servers = {        │  data: образ, подсеть      resource: firewall, ключ  │
  web-1 = {}     ──▶   │  module "web" (for_each) ──▶ ../modules/vm  × N      │
  web-2 = {}           └──────────────────────────────┬──────────────────────┘
}                                                     │ state
                                                      ▼
                    PostgreSQL курса: workspace <prefix>-l11 (+ блокировка)
```

## Подготовка

- [ ] Занятие 10 пройдено: Terraform установлен, `~/.terraformrc` настроен, SSH-ключ есть ([подготовка занятия 10](../lesson10/README.md#подготовка)).
- [ ] После занятия 10 вы сделали `terraform destroy` — проверьте: `cd lesson10/practice && terraform state list` → пусто.
- [ ] Обновите репозиторий:
  ```bash
  cd devops-lab && git pull
  ls lesson11        # README.md  HOMEWORK.md  modules  practice  solution
  ```
- [ ] Найдите напарника: часть 4 делается в паре.

Ключи доступа преподаватель даст на занятии, как и в прошлый раз. Для части 3 он даст ещё **строку подключения к базе state** (`PG_CONN_STR`) — тоже только в закрытый чат, тоже только в `export`.

## Практика

### Часть 1. Модуль: читаем и вызываем (20 мин)

Модуль — это просто папка с `.tf`-файлами. У него есть **входы** (`variable`), **выходы** (`output`) и ресурсы внутри.

```bash
cd lesson11
cat modules/vm/variables.tf     # входы: name, image_id, flavor, subnet_id, key_pair, public_ip…
cat modules/vm/main.tf          # ВМ + публичный IP (EIP) — тот же код, что в занятии 10
cat modules/vm/outputs.tf       # выходы: id, name, private_ip, public_ip
```

Обратите внимание на `count = var.public_ip ? 1 : 0` в `modules/vm/main.tf`. Так в Terraform делают ресурс «по условию»: 1 копия или ни одной. Пригодится на занятии 12, где у серверов не будет публичных IP.

Теперь вызываем модуль:

```bash
cd practice
export SBC_ACCESS_KEY="…"  SBC_SECRET_KEY="…"      # ключи от преподавателя
cp terraform.tfvars.example terraform.tfvars        # впишите свой prefix
grep -n TODO main.tf                                # три TODO в блоке module "web"
```

Замените три `TODO` в `main.tf`:

| TODO | Что подставить | Подсказка |
|---|---|---|
| `source` | путь к папке модуля | относительно папки `practice` |
| `subnet_id` | ID общей подсети | её уже читает `data "sbercloud_vpc_subnet" "course"` выше |
| `key_pair` | **имя** ключа | ресурс `sbercloud_kps_keypair.key` выше |

```bash
terraform init          # скачает провайдер и «подключит» модуль: "- web in ../modules/vm"
terraform plan          # Plan: 7 to add (firewall + 2 правила + ключ + ВМ, EIP, привязка)
terraform apply
curl $(terraform output -raw url)       # «Я — <prefix>-web-1» (через 1–2 мин)
terraform state list                     # module.web.sbercloud_compute_instance.this — адрес ресурса внутри модуля
```

> Модуль не знает, откуда взялись образ и подсеть: их передаёт вызывающий код. Поэтому один и тот же модуль работает и с публичными серверами (сегодня), и с приватными (занятие 12).

### Часть 2. for_each: N серверов одной картой (20 мин)

В `variables.tf` уже есть переменная `servers` — карта «имя сервера → настройки»:

```hcl
default = {
  "web-1" = {}
  "web-2" = {}
}
```

**1. Превращаем один вызов модуля в N.** В `main.tf`, в блоке `module "web"`:

```hcl
module "web" {
  source   = "../modules/vm"
  for_each = var.servers                                  # ← добавить

  name = "${var.prefix}-${each.key}"                      # ← было "${var.prefix}-web-1"
  ...
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-${each.key}"                    # ← и здесь
  })
}
```

В `outputs.tf` закомментируйте выходы части 1 и раскомментируйте выходы части 2 (с `for`).

**2. Смотрим план — и пугаемся.**

```bash
terraform plan
```

План хочет **удалить** `module.web` и создать `module.web["web-1"]` и `module.web["web-2"]`. Почему? У ресурса сменился **адрес** в state: был `module.web`, стал `module.web["web-1"]`. Terraform думает, что это разные серверы.

**3. Говорим Terraform, что это переезд.** Раскомментируйте в конце `main.tf` блок `moved`:

```hcl
moved {
  from = module.web
  to   = module.web["web-1"]
}
```

```bash
terraform plan      # web-1: "has moved to module.web["web-1"]", добавляется только web-2
terraform apply
terraform output    # public_ips = { "web-1" = "…", "web-2" = "…" }
```

**4. Добавляем и убираем серверы.** В `terraform.tfvars`:

```hcl
servers = {
  "web-1" = {}
  "web-2" = {}
  "web-3" = {}
}
```

`terraform plan` покажет `+` только для web-3. Теперь уберите строку `"web-2" = {}` и снова выполните `terraform plan`: удаляется **ровно web-2**, web-1 и web-3 не трогаются. Примените нужный вариант, но оставьте не больше двух серверов: квоты общие.

> **Почему не `count`?** С `count` серверы адресуются по номеру: `[0]`, `[1]`, `[2]`. Пусть имена берутся из списка `["web-1", "web-2", "web-3"]`. Уберите из списка `web-2` — номера «сдвинутся»: сервер `[1]` получит настройки web-3 и изменится, хотя его не трогали, а `[2]` (настоящий web-3) будет удалён. У `for_each` адрес — имя (`["web-3"]`), оно не сдвигается.

### Часть 3. State в базе данных (15 мин)

Сейчас state — файл `terraform.tfstate` на вашем ноутбуке. Его не видит напарник, его можно потерять вместе с ноутбуком, его нельзя класть в Git (в нём IP, ID и иногда секреты). И главное: если два человека одновременно сделают `apply`, каждый со своей копией, они испортят друг другу работу.

Решение — **backend**: хранилище state вне ноутбука. У нас это **PostgreSQL курса** (бэкенд `pg`): преподаватель поднял его кодом из `lesson10/shared/state-db.tf`. State лежит в таблице, а на время `plan`/`apply` Terraform ставит **блокировку**. Второй человек в тот же state не попадёт, пока первый не закончит.

```bash
cat backend.tf.example           # в нём нет ни адреса, ни пароля — только имя схемы
export PG_CONN_STR="…"           # строка подключения от преподавателя: адрес, пользователь, пароль
```

Переносим свой state в базу. Каждый работает в своём **workspace** — отдельном state внутри общей базы, по одному на человека:

```bash
mv terraform.tfstate lesson11.tfstate        # 1. откладываем локальный state в сторону
cp backend.tf.example backend.tf             # 2. подключаем backend "pg"
terraform init                               #    Successfully configured the backend "pg"!
terraform workspace new <prefix>-l11         # 3. свой workspace: Created and switched to workspace
terraform state push lesson11.tfstate        # 4. загружаем отложенный state в базу
```

Проверяем:

```bash
terraform workspace list    # все workspace группы; ваш — со звёздочкой
terraform state list        # те же ресурсы — state теперь читается из базы
terraform plan              # No changes
rm lesson11.tfstate terraform.tfstate.backup
```

> ⚠️ Workspace `default` — общий для всех, в нём не работаем. Если `terraform workspace show` показывает `default` — сделайте `terraform workspace select <prefix>-l11`.

> **Почему в блоке `backend` нет пароля?** Переменные в `backend` использовать нельзя: backend настраивается раньше, чем Terraform читает переменные. А секреты в файлах держать нельзя. Поэтому строка подключения приходит из переменной окружения `PG_CONN_STR`, а свой state каждый выбирает через workspace.

### Часть 4. Работа в паре: блокировка и чужой state (10 мин)

Вы с напарником — два «инженера», которые работают с одной инфраструктурой. Делаем копию папки и подключаемся к **state напарника**:

```bash
cd ..                                   # из practice в lesson11
cp -r practice practice-partner
cd practice-partner
rm -rf .terraform terraform.tfstate*
terraform init
terraform workspace select <prefix-напарника>-l11
terraform state list                    # серверы напарника!
```

**Блокировка.** Напарник у себя в `practice` запускает `terraform apply` и **не отвечает** на вопрос `Enter a value:` — пока он думает, state заблокирован. Вы в это время в копии:

```bash
terraform plan
#   Error: Error acquiring the state lock
#   Error message: Workspace is already locked: <prefix-напарника>-l11
terraform plan -lock-timeout=60s        # ждём до минуты, пока блокировку не снимут
```

Напарник отвечает `no` — ваш `plan` сразу продолжается. Затем поменяйтесь ролями.

> Если бы state лежал у каждого в своём файле, два `apply` прошли бы оба — и один затёр бы изменения другого. Блокировка превращает это в понятную ошибку. А если ноутбук с `apply` упал или потерял сеть, соединение с базой рвётся и блокировка снимается **сама**.

**Чужой план.** Теперь просто `terraform plan` в копии. План, скорее всего, **не пустой**. Ищите причину в плане:
- другой `prefix` в вашем `terraform.tfvars` → Terraform хочет переименовать все ресурсы;
- другой публичный ключ в `~/.ssh/id_ed25519.pub` → ключевая пара `-/+`;
- другая карта `servers`.

Только `plan`, **никаких `apply`** в чужом workspace! Поставьте в `terraform.tfvars` префикс напарника — план станет короче. Вывод: инфраструктуру описывают **код + переменные + state** вместе. Код лежит в Git, state в базе, а переменные команда тоже должна хранить общими, а не у каждого свои.

```bash
cd .. && rm -rf practice-partner        # чужой state больше не нужен
```

### Часть 5. Уборка (5 мин)

```bash
cd practice
terraform destroy
terraform state list       # пусто
```

Ваш workspace в базе **остаётся**, но state в нём пустой. Так и должно быть: при следующем `apply` Terraform продолжит с него.

### Задания для тех, кто закончил раньше

1. Добавьте в модуль вход `flavor` со значением по умолчанию и сделайте у одного сервера в `servers` другой тип ВМ. Карта в `servers` для этого должна уметь хранить `flavor`.
2. Выведите output `servers`: карта «имя → { ip, url }» одним for-выражением.
3. Посмотрите state из базы напрямую: `terraform state pull | head -30`. Найдите там ресурсы модуля.

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `Module not installed` | Добавили или изменили модуль без init | `terraform init` |
| `Unreadable module directory` / `source` не найден | Неверный путь в `source` | `source = "../modules/vm"` — путь от папки `practice` |
| `Invalid reference` в `subnet_id`/`key_pair` | Пропущена часть адреса | `data.<тип>.<имя>.id`, `<тип>.<имя>.name` |
| План хочет удалить web-1 после `for_each` | Сменился адрес ресурса | Блок `moved` из части 2 |
| `conn_str` не задан / `connection refused` при init | Нет `PG_CONN_STR` в этом окне терминала | `export PG_CONN_STR="…"` (строка от преподавателя) |
| `password authentication failed` | Ошибка в строке подключения | Скопируйте строку заново, целиком, в кавычках |
| `no pg_hba.conf entry … no encryption` | В строке нет `sslmode=require` | Скопируйте строку целиком |
| `Error acquiring the state lock` | В этот state сейчас работает кто-то другой | Подождите или `-lock-timeout=60s`. Это защита, а не ошибка |
| `terraform workspace show` → `default` | Не выбран свой workspace | `terraform workspace select <prefix>-l11` |
| Do you want to copy existing state to the new backend? | Не отложили `terraform.tfstate` перед `init` | Ответьте `no` и сделайте шаги 1, 3, 4 части 3 |

## ⛔ Главное правило: ресурсы не оставляем

Всё как на занятии 10. Каждый сервер — это ВМ и **публичный IP**, оба стоят денег, пока существуют. В конце занятия и каждой сессии ДЗ:

```bash
terraform destroy
terraform state list       # пусто
```

## Домашнее задание

**Срок — до занятия 12.** Как сдавать: заполните шаблон [HOMEWORK.md](HOMEWORK.md) (скопируйте, назовите `ДЗ-11-фамилия.md`) и отправьте файлом в чат группы.

Работайте в копии: `cp -r practice hw && cd hw && rm -rf .terraform terraform.tfstate*`. Префикс — **`<фамилия>-hw`**, state — **отдельный** workspace:

```bash
export PG_CONN_STR="…"
terraform init
terraform workspace new <фамилия>-hw11
```

1. **Свой модуль firewall.** Вынесите группу безопасности в модуль `lesson11/modules/firewall`:
   - входы `name` (строка) и `ports` (список чисел);
   - внутри — группа безопасности и правила через `for_each` по портам;
   - выход `id`.

   Подключите его в `hw/main.tf` вместо ресурсов `sbercloud_networking_secgroup*`. Порты — `[22, 80]`.

   **Цель — переезд без пересоздания:** добавьте блоки `moved`, чтобы `terraform plan` после рефакторинга показал `0 to add, 0 to change, 0 to destroy`. Подсказка: адрес правила внутри модуля выглядит так: `module.firewall.sbercloud_networking_secgroup_rule.this["22"]`.
2. **Три сервера.** Задайте `servers` из трёх серверов, у одного `disk_size = 20`. Сделайте `apply`. Затем удалите из карты средний сервер и сохраните **итоговую строку** `terraform plan` (`Plan: …`). Что удаляется и что нет?
3. **State в базе.** Приложите вывод `terraform workspace show` и `terraform state list`.
4. **Вопросы (письменно, коротко):**
   - Чем `for_each` лучше `count` для серверов? Что случится с `count`, если удалить средний элемент?
   - Почему в блоке `backend` нельзя использовать переменные и как мы обошли это ограничение (адрес и пароль базы, свой state у каждого)?
   - Что может случиться, если два человека одновременно сделают `apply` в один state без блокировки? Что произошло у вас в части 4 и почему блокировка снимается сама, если ноутбук упал?
   - Зачем нужен блок `moved`?
5. ⛔ **Уборка:** `terraform destroy` и пустой `terraform state list`. Без этого ДЗ не принимается.

**Что сдать** — всё по шаблону [HOMEWORK.md](HOMEWORK.md): код модуля `firewall`, вызов модуля и блоки `moved`, выводы команд, ответы и вывод `destroy`. **Без** `terraform.tfvars`, `terraform.tfstate`, ключей и строки `PG_CONN_STR`.
