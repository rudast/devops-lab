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
- [ ] `terraform version` — **1.6 или новее** (блок `import` в части 6 и `required_version` в коде). Старше — поставьте новую версию с зеркала, как в занятии 10.
- [ ] После занятия 10 вы сделали `terraform destroy` — проверьте: `cd lesson10/practice && terraform state list` → пусто.
- [ ] Обновите репозиторий:
  ```bash
  cd devops-lab && git pull
  ls lesson11        # README.md  HOMEWORK.md  modules  practice  solution
  ```
- [ ] Найдите напарника: часть 8 делается в паре.

Ключи доступа преподаватель даст на занятии, как и в прошлый раз. Для части 7 он даст ещё **строку подключения к базе state** (`PG_CONN_STR`) — тоже только в закрытый чат, тоже только в `export`.

## Практика

90 минут, девять коротких частей. В каждой — своё задание: что-то дописать в коде, предсказать план, проверить результат. Застряли больше чем на 5 минут — подсмотрите в `solution/` и двигайтесь дальше.

| Часть | Что делаем | Время |
|---|---|---|
| 1 | Вызываем модуль: один сервер | 15 мин |
| 2 | Дорабатываем модуль: новый выход и диск | 10 мин |
| 3 | `for_each` и `moved`: N серверов одной картой | 15 мин |
| 4 | Выходы через `for`: пишем сами | 10 мин |
| 5 | `terraform console`: проверяем выражения на живом state | 5 мин |
| 6 | Ресурс «потерялся» из state: `state rm` и `import` | 10 мин |
| 7 | State в базе данных | 10 мин |
| 8 | В паре: блокировка и чужой state | 10 мин |
| 9 | Уборка | 5 мин |

### Часть 1. Модуль: читаем и вызываем (15 мин)

Модуль — это просто папка с `.tf`-файлами. У него есть **входы** (`variable`), **выходы** (`output`) и ресурсы внутри.

```bash
cd lesson11
cat modules/vm/variables.tf     # входы: name, image_id, flavor, subnet_id, key_pair, disk_size, public_ip…
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

### Часть 2. Дорабатываем модуль (10 мин)

Модуль — это ваш код, его можно и нужно менять. Два изменения.

**1. Новый выход `url`.** Сейчас адрес страницы собирается в `practice/outputs.tf`. Пусть его отдаёт сам модуль. Допишите в конец `../modules/vm/outputs.tf` выход `url`: строка `http://<публичный IP>/` или `null`, если публичного IP нет (`public_ip = false`). Образец — соседний выход `public_ip`.

Затем в `practice/outputs.tf` замените значение выхода `url` на `module.web.url`.

```bash
terraform plan      # No changes — ресурсы не меняются, выход тот же
terraform apply
terraform output url
```

<details><summary>Ответ</summary>

```hcl
output "url" {
  value = var.public_ip ? "http://${sbercloud_vpc_eip.this[0].address}/" : null
}
```
</details>

**2. Диск побольше.** В `main.tf` в вызове модуля поставьте `disk_size = 15`. Предскажите план, потом проверьте:

```bash
terraform plan      # ~ module.web.sbercloud_compute_instance.this — system_disk_size: 10 → 15, на месте
terraform apply
```

Модуль передал новое значение внутрь, а провайдер умеет увеличивать диск без пересоздания ВМ. Уменьшить диск обратно нельзя — облако вернёт ошибку.

### Часть 3. for_each: N серверов одной картой (15 мин)

В `variables.tf` уже есть переменная `servers` — карта «имя сервера → настройки». У каждого сервера может быть свой `disk_size` (по умолчанию 10).

**1. Задаём серверы.** В `terraform.tfvars`:

```hcl
servers = {
  "web-1" = { disk_size = 15 }     # у web-1 диск уже 15 ГБ — уменьшать нельзя
  "web-2" = {}
}
```

**2. Превращаем один вызов модуля в N.** В `main.tf`, в блоке `module "web"`:

```hcl
module "web" {
  source   = "../modules/vm"
  for_each = var.servers                                  # ← добавить

  name      = "${var.prefix}-${each.key}"                 # ← было "${var.prefix}-web-1"
  disk_size = max(each.value.disk_size, data.sbercloud_images_image.ubuntu.min_disk_gb)  # ← было 15
  ...
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-${each.key}"                    # ← и здесь
  })
}
```

`each.key` — имя сервера из карты, `each.value` — его настройки. В `outputs.tf` **закомментируйте** выходы части 1: `module.web` теперь карта серверов, у неё нет `.public_ip`. Свои выходы напишете в части 4.

**3. Смотрим план — и пугаемся.**

```bash
terraform plan
```

План хочет **удалить** `module.web` и создать `module.web["web-1"]` и `module.web["web-2"]`. Почему? У ресурса сменился **адрес** в state: был `module.web`, стал `module.web["web-1"]`. Terraform думает, что это разные серверы.

**4. Говорим Terraform, что это переезд.** Раскомментируйте в конце `main.tf` блок `moved`:

```hcl
moved {
  from = module.web
  to   = module.web["web-1"]
}
```

```bash
terraform plan      # web-1: "has moved to module.web["web-1"]", добавляется только web-2
terraform apply
```

**5. Добавляем и убираем серверы.** Допишите в карту `"web-3" = {}` — `terraform plan` покажет `+` только для web-3. Теперь уберите строку `"web-2" = {}` и снова `terraform plan`: удаляется **ровно web-2**, web-1 и web-3 не трогаются. Примените вариант с **двумя** серверами (web-1 и web-2): квоты общие.

> **Почему не `count`?** С `count` серверы адресуются по номеру: `[0]`, `[1]`, `[2]`. Пусть имена берутся из списка `["web-1", "web-2", "web-3"]`. Уберите из списка `web-2` — номера «сдвинутся»: сервер `[1]` получит настройки web-3 и изменится, хотя его не трогали, а `[2]` (настоящий web-3) будет удалён. У `for_each` адрес — имя (`["web-3"]`), оно не сдвигается.

### Часть 4. Выходы через for (10 мин)

`module.web` теперь карта: `{ "web-1" = <выходы модуля>, "web-2" = <выходы модуля> }`. Чтобы собрать из неё список или новую карту, нужно **for-выражение**:

```hcl
[for k, vm in module.web : vm.private_ip]               # список:  ["192.168.8.11", "192.168.8.12"]
{ for k, vm in module.web : k => vm.private_ip }        # карта:   { "web-1" = "192.168.8.11", … }
[for k, s in var.servers : k if s.disk_size > 10]       # с фильтром if
```

Допишите в `outputs.tf` четыре выхода вместо `TODO` (заготовки там уже есть):

| Выход | Что должно получиться |
|---|---|
| `public_ips` | карта «имя → публичный IP» |
| `urls` | список адресов страниц — из выхода `url` модуля (часть 2) |
| `big_disks` | список имён серверов, у которых `disk_size` больше 10 |
| `servers_count` | сколько серверов (функция `length`) |

```bash
terraform plan      # Changes to Outputs — ресурсы не трогаются
terraform apply
terraform output    # big_disks = ["web-1"], servers_count = 2 …
for u in $(terraform output -json urls | tr -d '[]",'); do curl -s $u | grep -o "Я — [^<]*"; done
```

### Часть 5. terraform console (5 мин)

`terraform console` — интерактивная проверка выражений на вашем настоящем state. Удобно, чтобы проверить `for` или функцию до того, как писать её в код.

```bash
terraform console
```

Попробуйте и объясните результат:

```hcl
keys(var.servers)
module.web["web-1"].private_ip
[for vm in module.web : vm.name]
cidrhost(data.sbercloud_vpc_subnet.course.cidr, 10)
merge(local.tags, { role = "web" })
upper(var.prefix)
```

Задание: одним выражением получите карту «имя ВМ → внутренний IP», где имя — полное (`<prefix>-web-1`), а не ключ карты. Выход — `exit` или Ctrl+D.

> `console` тоже читает state и ставит на него блокировку. Пока он открыт, `apply` в той же папке будет ждать — закрывайте его.

### Часть 6. Ресурс «потерялся» из state: rm и import (10 мин)

Реальная ситуация: ресурс в облаке есть, а в state его нет. Например, его создали руками в консоли, state откатили или кто-то сделал `state rm`. Устроим это сами — с SSH-ключом.

```bash
terraform state list | grep keypair
terraform state rm sbercloud_kps_keypair.key    # убрали ТОЛЬКО запись из state, ключ в облаке остался
terraform plan                                   # Plan: 1 to add — Terraform хочет создать ключ заново
```

Если сделать `apply`, облако ответит ошибкой: ключ с таким именем уже существует. Правильный путь — **импортировать** существующий ресурс в state. Допишите в конец `main.tf`:

```hcl
import {
  to = sbercloud_kps_keypair.key
  id = "${var.prefix}-l11-key"     # у ключа ID — это его имя
}
```

```bash
terraform plan      # Plan: 1 to import, 0 to add, 0 to change, 0 to destroy
terraform apply
terraform plan      # No changes
```

После успешного импорта блок `import` можно удалить: он нужен один раз.

> Если после импорта `plan` показывает изменения — значит, код описывает ресурс не так, как он есть в облаке. Это и есть главный смысл импорта: подогнать код под реальность, пока `plan` не станет пустым.

### Часть 7. State в базе данных (10 мин)

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

### Часть 8. В паре: блокировка и чужой state (10 мин)

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

### Часть 9. Уборка (5 мин)

```bash
cd practice
terraform destroy
terraform state list       # пусто
```

Ваш workspace в базе **остаётся**, но state в нём пустой. Так и должно быть: при следующем `apply` Terraform продолжит с него.

### Задания для тех, кто закончил раньше

1. Сделайте у одного сервера в `servers` другой тип ВМ: карта `servers` должна уметь хранить `flavor` (`optional(string, …)`), а вызов модуля — передавать его.
2. Выведите output `servers`: карта «имя → { ip, url }» одним for-выражением.
3. Посмотрите state из базы напрямую: `terraform state pull | head -30`. Найдите там ресурсы модуля.

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `Unsupported Terraform Core version` | Terraform старше 1.6 | Поставить новую версию с зеркала (README занятия 10) |
| `Module not installed` | Добавили или изменили модуль без init | `terraform init` |
| `Unreadable module directory` / `source` не найден | Неверный путь в `source` | `source = "../modules/vm"` — путь от папки `practice` |
| `Invalid reference` в `subnet_id`/`key_pair` | Пропущена часть адреса | `data.<тип>.<имя>.id`, `<тип>.<имя>.name` |
| План хочет удалить web-1 после `for_each` | Сменился адрес ресурса | Блок `moved` из части 3 |
| `Unsupported attribute` … `public_ip` после `for_each` | Выходы части 1 ссылаются на `module.web.public_ip`, а это теперь карта | Закомментируйте их, напишите выходы части 4 |
| Ошибка уменьшения диска / `shrink` у web-1 | В карте `servers` у web-1 нет `disk_size = 15` | Верните `"web-1" = { disk_size = 15 }` |
| `Cannot import non-existent remote object` | Неверный `id` в `import` | ID ключа — его имя: `<prefix>-l11-key` |
| `plan` висит / `Error acquiring the state lock` у себя же | Открыт `terraform console` в другом окне | Закройте console (`exit`) |
| `conn_str` не задан / `connection refused` при init | Нет `PG_CONN_STR` в этом окне терминала | `export PG_CONN_STR="…"` (строка от преподавателя) |
| `password authentication failed` | Ошибка в строке подключения | Скопируйте строку заново, целиком, в кавычках |
| `no pg_hba.conf entry … no encryption` | В строке нет `sslmode=require` | Скопируйте строку целиком |
| `Error acquiring the state lock` | В этот state сейчас работает кто-то другой | Подождите или `-lock-timeout=60s`. Это защита, а не ошибка |
| `terraform workspace show` → `default` | Не выбран свой workspace | `terraform workspace select <prefix>-l11` |
| Do you want to copy existing state to the new backend? | Не отложили `terraform.tfstate` перед `init` | Ответьте `no` и сделайте шаги 1, 3, 4 части 7 |

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
   - Что может случиться, если два человека одновременно сделают `apply` в один state без блокировки? Что произошло у вас в части 8 и почему блокировка снимается сама, если ноутбук упал?
   - Зачем нужен блок `moved`?
5. ⛔ **Уборка:** `terraform destroy` и пустой `terraform state list`. Без этого ДЗ не принимается.

**Что сдать** — всё по шаблону [HOMEWORK.md](HOMEWORK.md): код модуля `firewall`, вызов модуля и блоки `moved`, выводы команд, ответы и вывод `destroy`. **Без** `terraform.tfvars`, `terraform.tfstate`, ключей и строки `PG_CONN_STR`.
