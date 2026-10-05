# Занятие 10. Infrastructure as Code: своя ВМ в cloud.ru через Terraform

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

## Подготовка

Сделайте всё это **дома, до занятия** — на практике на установку времени не будет. Студенты на Windows: всё — **внутри ВМ VirtualBox**, там же будете работать на занятии.

### Шаг 0. Обновите репозиторий
```bash
cd devops-lab && git pull
ls lesson10/practice          # versions.tf  variables.tf  terraform.tfvars.example
```

> Сайт HashiCorp (releases.hashicorp.com) и реестр Terraform из России не открываются. Поэтому и сам Terraform, и плагины (провайдеры) мы берём с **зеркала cloud.ru**. Команды `brew install terraform` и `apt install terraform` тоже не сработают: они качают с тех же заблокированных адресов.

Установка — три шага: **1)** скачать и установить Terraform, **2)** настроить `~/.terraformrc`, чтобы провайдеры качались с зеркала, **3)** проверить.

### Шаг 1. Установить Terraform

**Windows → внутри ВМ VirtualBox (Ubuntu Server).** Terraform ставим в ВМ, а не в Windows: там же у вас Docker и SSH-ключ. Команды выполняйте в ВМ (по SSH из Windows или прямо в окне VirtualBox):
```bash
sudo apt update && sudo apt install -y curl unzip

TF_VER=1.15.7                              # версия Terraform (список: см. ниже)
ARCH=$(dpkg --print-architecture)          # обычно amd64
curl -fLo /tmp/terraform.zip \
  "https://tf-mirror-distr.obs-website.ru-moscow-1.hc.sbercloud.ru/terraform/${TF_VER}/terraform_${TF_VER}_linux_${ARCH}.zip"
sudo unzip -o /tmp/terraform.zip terraform -d /usr/local/bin/
rm /tmp/terraform.zip

terraform -version                         # Terraform v1.15.7 on linux_amd64
```

**macOS** (в «Терминале»):
```bash
TF_VER=1.15.7
ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64   # arm64 — Apple M1…M4, amd64 — Intel
curl -fLo /tmp/terraform.zip \
  "https://tf-mirror-distr.obs-website.ru-moscow-1.hc.sbercloud.ru/terraform/${TF_VER}/terraform_${TF_VER}_darwin_${ARCH}.zip"
sudo mkdir -p /usr/local/bin
sudo unzip -o /tmp/terraform.zip terraform -d /usr/local/bin/
rm /tmp/terraform.zip

terraform -version                         # Terraform v1.15.7 on darwin_arm64
```
> `sudo` спросит пароль от вашего компьютера. Символы при вводе не отображаются — так и должно быть.

**Если `curl` выдал ошибку 404**, такой версии на зеркале нет. Откройте в браузере https://tf-mirror-distr.obs-website.ru-moscow-1.hc.sbercloud.ru/terraform/, выберите любую версию **1.x без** `alpha`, `beta`, `rc` и подставьте её номер в `TF_VER`. Подойдёт любая версия от 1.5 и новее.

<details>
<summary>Без командной строки: скачать архив в браузере</summary>

1. Откройте https://tf-mirror-distr.obs-website.ru-moscow-1.hc.sbercloud.ru/terraform/ и выберите версию.
2. Скачайте архив для своей системы:
   - Ubuntu (ВМ VirtualBox): `terraform_<версия>_linux_amd64.zip`
   - Mac с процессором Apple (M1…M4): `terraform_<версия>_darwin_arm64.zip`
   - Mac с процессором Intel: `terraform_<версия>_darwin_amd64.zip`
   Какой у вас процессор, видно в меню  → «Об этом Mac»: «Chip Apple M…» или «Processor … Intel».
3. Распакуйте архив и переместите файл `terraform` в `/usr/local/bin/`:
   ```bash
   sudo mkdir -p /usr/local/bin && sudo mv ~/Downloads/terraform /usr/local/bin/
   ```
4. macOS заблокирует запуск файла, скачанного браузером («не удаётся проверить разработчика»). Снимите блокировку:
   ```bash
   sudo xattr -d com.apple.quarantine /usr/local/bin/terraform
   ```
</details>

### Шаг 2. Провайдеры — тоже с зеркала: `~/.terraformrc`

Без этого файла команда `terraform init` на занятии не сможет скачать провайдер cloud.ru. Скопируйте блок целиком и выполните (на Windows — в ВМ):
```bash
cat > ~/.terraformrc <<'EOF'
provider_installation {
  network_mirror {
    url     = "https://terraform.cloud.ru/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF
cat ~/.terraformrc        # проверьте, что файл записался
```

### Шаг 3. Проверка: Terraform скачивает провайдер cloud.ru
```bash
mkdir -p /tmp/tf-check && cd /tmp/tf-check
cat > main.tf <<'EOF'
terraform {
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
  }
}
EOF
terraform init            # ждём: "Terraform has been successfully initialized!"
cd ~ && rm -rf /tmp/tf-check
```
Увидели `successfully initialized` — Terraform готов к занятию. Облачные ключи для этой проверки не нужны: она только скачивает провайдер.

| Ошибка | Что значит | Что делать |
|---|---|---|
| `curl: (22) … 404` | Нет такой версии на зеркале | Выбрать версию на странице зеркала и поменять `TF_VER` |
| `terraform: command not found` | Файл не попал в `/usr/local/bin` | Повторить `sudo unzip …`; проверить `ls -l /usr/local/bin/terraform` |
| `cannot execute binary file` / `bad CPU type` | Скачан архив не для вашего процессора | Mac M1…M4 — `darwin_arm64`, Intel — `darwin_amd64`, ВМ — `linux_amd64` |
| `unzip: command not found` | Не установлен unzip | `sudo apt install -y unzip` |
| `Failed to query available provider packages` / `could not connect to registry.terraform.io` | Нет `~/.terraformrc` или опечатка в нём | Повторить шаг 2 и сравнить файл с примером |
| `… cannot be opened because the developer cannot be verified` (macOS) | Карантин для файлов из браузера | `sudo xattr -d com.apple.quarantine /usr/local/bin/terraform` |
| Таймаут при `curl` или `init` | Мешает VPN или прокси | Выключить VPN и повторить |

### Шаг 4. SSH-ключ

По этому ключу вы будете входить на свою ВМ в облаке. Если ключ уже делали для GitHub, ничего не нужно.
```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519      # нет ключа — создайте (Enter на все вопросы)
cat ~/.ssh/id_ed25519.pub                              # ваш ПУБЛИЧНЫЙ ключ: одна строка ssh-ed25519 …
```
> Файл `~/.ssh/id_ed25519` **без** `.pub` — приватный ключ. Его никому не показываем и никуда не копируем.

### Чек-лист перед занятием
- [ ] `terraform -version` показывает версию 1.x
- [ ] проверка из шага 3 прошла: «Terraform has been successfully initialized!»
- [ ] `ls ~/.ssh/id_ed25519.pub` — файл есть
- [ ] `git pull` сделан, папка `lesson10/practice` на месте

Ключи доступа к облаку (`SBC_ACCESS_KEY`, `SBC_SECRET_KEY`) выдаст преподаватель на занятии. **Их нельзя записывать в файлы, коммитить и публиковать** — это ключи от общего проекта всей группы.

## Практика

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
3. **cloud-init и пересоздание ВМ (`-replace`).** Ставим nginx при старте машины:
   ```bash
   cp ../steps/05-http.tf ../steps/cloud-init.yaml.tftpl .
   ```
   В `04-vm.tf` внутрь ресурса `sbercloud_compute_instance.vm` добавьте:
   ```hcl
   user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", { prefix = var.prefix })
   ```
   ```bash
   terraform fmt                 # выровнять код
   terraform plan                # правило HTTP: + create, ВМ: ~ update in-place (user_data)
   terraform apply
   curl http://$(terraform output -raw public_ip)/      # Connection refused! Почему?
   ```
   Провайдер записал новый `user_data` в существующую ВМ, но **cloud-init выполняется только при первом запуске** — nginx никто не поставил. План честно показал `~`, а результат не тот: Terraform не знает, что происходит *внутри* машины. Пересоздаём ВМ явно:
   ```bash
   terraform apply -replace=sbercloud_compute_instance.vm   # ВМ: -/+, EIP — без изменений!
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
2. **Диск.** По умолчанию диск минимальный для образа (output `disk_min_gb`). Поставьте `vm_disk_size` на 10 ГБ больше → `plan` покажет изменение на месте (`~`). После `apply` проверьте `df -h /` на ВМ. Потом попробуйте вернуть прежнее значение и прочитайте ошибку: уменьшать диск нельзя.
3. **Пустите соседа.** Добавьте его публичный ключ в `~/.ssh/authorized_keys` на своей ВМ и проверьте, что он может войти. Затем обсудите: увидит ли это изменение `terraform plan`? Почему нет? Что станет с этим ключом после пересоздания ВМ?
4. **`terraform console`.** Посчитайте в нём `cidrhost("192.168.8.0/22", 10)`, `upper(var.prefix)`, `data.sbercloud_compute_flavors.vm.ids`.

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `terraform init`: `Failed to query available provider packages` | Нет `~/.terraformrc` с зеркалом | [Шаг 2 подготовки](#подготовка): `~/.terraformrc` |
| `No valid credential sources found` | Нет `SBC_ACCESS_KEY` / `SBC_SECRET_KEY` в этом окне терминала | `export …` в том же окне |
| `Invalid value for variable` (prefix) | Префикс с заглавными/кириллицей/пробелом | Только строчная латиница, цифры, дефис: `ivanov` |
| `Invalid reference … TODO_…` | Задание шага не выполнено | Замените TODO по подсказке в комментарии файла |
| `no such file` в `file(pathexpand(…))` | Нет SSH-ключа | `ssh-keygen -t ed25519` |
| `Your query returned no results` (образ / подсеть) | Другое имя образа или подсеть курса не создана | Спросить преподавателя; `image_name_regex`, `subnet_name` в tfvars |
| `Warning: Incomplete lock file information` при `init` | Провайдер скачан с зеркала, контрольные суммы посчитаны локально | Это не ошибка, можно продолжать |
| `already exists` / `name … is duplicated` | Такой префикс уже занят другим студентом | Взять другой префикс (например, `ivanov2`) |
| `quota` / `Insufficient …` | Кончились квоты общего проекта | Сказать преподавателю, работать в паре |
| `ssh: Connection timed out` | ВМ ещё грузится / правило SSH не с вашего IP | Подождать 1–2 мин; проверить `allowed_ssh_cidr` и `curl -s ifconfig.me` |
| `Permission denied (publickey)` | Не тот ключ / не тот пользователь | `ssh -i ~/.ssh/id_ed25519 root@<IP>`; ключ из шага 3 должен быть ваш |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | ВМ пересоздана на том же IP | `ssh-keygen -R <IP>` |
| Страница nginx не открывается | cloud-init ещё работает / нет правила для порта 80 / `user_data` добавили к уже работающей ВМ | Подождать 2 мин; скопирован ли `05-http.tf`? `terraform apply -replace=sbercloud_compute_instance.vm`; на ВМ: `cloud-init status` |

## ⛔ Главное правило: ВМ не оставляем включённой

Ресурсы облака **стоят денег каждую минуту**, пока существуют, а проект у нас общий на всю группу.

- Закончили работу (на занятии или дома) — **сразу `terraform destroy`**, в тот же день. Ни одна ВМ не остаётся на ночь.
- **Удалить, а не «выключить».** Остановленная в консоли ВМ всё равно тарифицируется: за диск и за публичный IP. Поэтому только `terraform destroy`.
- **Проверка после destroy**, каждый раз:
  ```bash
  terraform destroy          # в конце: "Destroy complete! Resources: N destroyed."
  terraform state list       # пусто — Terraform больше ничем не управляет
  ```
  и в консоли cloud.ru: нет ВМ и публичных IP (EIP) с вашим префиксом.
- **Не удаляйте папку с `terraform.tfstate`**, пока не сделали `destroy`. Без state Terraform «забудет» ваши ресурсы, и они останутся висеть в облаке.
- Ресурсы, оставленные без хозяина, преподаватель удалит вручную, а задание с ними не будет засчитано.

## Домашнее задание

**Срок — до следующего занятия.** Как сдавать: заполните шаблон [HOMEWORK.md](HOMEWORK.md) (скопируйте, назовите `ДЗ-10-фамилия.md`) и отправьте файлом в чат группы.

Работаете в том же общем проекте и с теми же ключами доступа. Для ДЗ используйте префикс **`<фамилия>-hw`**, например `ivanov-hw`, чтобы не пересечься с ресурсами занятия.

> ⛔ Каждую сессию ДЗ заканчивайте `terraform destroy` + `terraform state list` (пусто). См. раздел «Главное правило» выше.

1. **Соберите ВМ с нуля, без подсказок.** Создайте папку `lesson10/hw` и скопируйте в неё только `versions.tf`, `variables.tf` и `terraform.tfvars.example` из `practice`. Файл `main.tf` напишите **сами**, не копируя `steps/`. Нужны:
   - data-источники: образ, тип ВМ, общая сеть;
   - группа безопасности с правилом для SSH;
   - ваш ключ;
   - ВМ и публичный IP;
   - outputs `public_ip` и `ssh_command`.

   Сверяйтесь с [документацией провайдера](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs/resources), а не с готовым решением. Сделайте `apply` и войдите по SSH.
2. **Свой пользователь через cloud-init.** Добавьте через `user_data` пользователя `student` с вашим ключом и правом `sudo`. Шаблон `cloud-init.yaml.tftpl`:
   ```yaml
   #cloud-config
   users:
     - default
     - name: student
       shell: /bin/bash
       sudo: ALL=(ALL) NOPASSWD:ALL
       ssh_authorized_keys:
         - ${ssh_key}
   ```
   В ресурсе ВМ:
   ```hcl
   user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
     ssh_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
   })
   ```
   Если ВМ уже создана, обычного `apply` мало: объясните почему и примените через `terraform apply -replace=sbercloud_compute_instance.vm`. После — `ssh student@<IP>`, затем `whoami` и `sudo whoami`.
3. **Вход одной командой.** Добавьте output, который печатает готовый блок для `~/.ssh/config`:
   ```hcl
   output "ssh_config" {
     value = <<-EOT
       Host hse-hw
         HostName ${sbercloud_vpc_eip.ip.address}
         User student
         IdentityFile ~/.ssh/id_ed25519
     EOT
   }
   ```
   Выполните `terraform output -raw ssh_config >> ~/.ssh/config` и проверьте вход командой `ssh hse-hw`. Учтите: после `destroy` и нового `apply` IP изменится, и блок придётся обновить.
4. **Предскажите план.** Для каждого изменения **сначала запишите прогноз** (`~` на месте или `-/+` пересоздание), потом проверьте его командой `terraform plan`:
   - `vm_disk_size` на 10 ГБ больше текущего размера диска;
   - новый тег `homework = "10"`;
   - другой порт в правиле SSH, например 2222. Применять не нужно: верните 22.

   Прогноз и фактический результат сведите в табличку.
5. **Вопросы (письменно, коротко):**
   - Почему ВМ нужно удалять, а не просто останавливать?
   - Что случится, если удалить `terraform.tfstate` до `destroy`, а потом снова сделать `apply` с тем же префиксом?
   - Почему ключи доступа к облаку нельзя класть в `terraform.tfvars`, даже если он в `.gitignore`?
   - Чем `data` отличается от `resource`?

**Что сдать** — всё по шаблону [HOMEWORK.md](HOMEWORK.md):
- `main.tf`, `outputs.tf`, `cloud-init.yaml.tftpl` — текстом в шаблон. **Без** `terraform.tfstate`, `terraform.tfvars` и ключей;
- вывод `ssh hse-hw` с `hostname`, `whoami`, `sudo whoami`;
- табличку прогнозов из задания 4 и ответы на вопросы;
- **обязательно**: вывод финального `terraform destroy` («Destroy complete!») и пустой `terraform state list`. Без этого ДЗ не принимается.

## Документация: если хочется поиграться

### Провайдер sbercloud (главное)
Репозиторий провайдера на GitHub — там вся документация и примеры. Сайт `registry.terraform.io` из России не открывается, а GitHub открывается.

- [Документация провайдера](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs): настройка и способы авторизации — `index.md`.
- [Ресурсы](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs/resources) (`resource "sbercloud_…"`) и [data sources](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs/data-sources) (`data "sbercloud_…"`). Имя файла — это имя ресурса без префикса: `sbercloud_compute_instance` → `compute_instance.md`.
- [Примеры](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/examples): готовые конфигурации для ВМ, сетей, балансировщиков, баз данных, Kubernetes (CCE), хранилища OBS.

На каждой странице ресурса есть пример, список аргументов (*Argument Reference*) и атрибутов (*Attribute Reference*). Ищите там пометку **Changing this creates a new …**: она значит, что изменение аргумента пересоздаст ресурс (`-/+`).

Ресурсы, которые мы использовали на занятии:

| Что | Ресурс / data source |
|---|---|
| ВМ | [`sbercloud_compute_instance`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/compute_instance.md) |
| SSH-ключ | [`sbercloud_kps_keypair`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/kps_keypair.md) |
| Группа безопасности и правила | [`sbercloud_networking_secgroup`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/networking_secgroup.md), [`sbercloud_networking_secgroup_rule`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/networking_secgroup_rule.md) |
| Публичный IP | [`sbercloud_vpc_eip`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/vpc_eip.md), [`sbercloud_compute_eip_associate`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/compute_eip_associate.md) |
| Сеть и подсеть | [`sbercloud_vpc`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/vpc.md), [`sbercloud_vpc_subnet`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/vpc_subnet.md) |
| Образ, тип ВМ, зоны | [`images_image`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/data-sources/images_image.md), [`compute_flavors`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/data-sources/compute_flavors.md), [`availability_zones`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/data-sources/availability_zones.md) |

### Документация cloud.ru
- [Terraform для Advanced: обзор](https://cloud.ru/docs/terraform/ug/index.html) и [установка и настройка провайдера](https://cloud.ru/docs/terraform/ug/topics/guides__configuring-terraform-provider).
- [Зеркало Terraform cloud.ru](https://cloud.ru/docs/terraform/ug/topics/guides__mirrors.html) — откуда мы берём сам Terraform и провайдеры.
- [Как создать ключи доступа AK/SK](https://cloud.ru/docs/advanced/overview/faq/create-access-keys) — для своего аккаунта.
- [Подключиться к Linux ECS по ключу](https://cloud.ru/docs/ecs/ug/topics/guides__connection__linux-ecs__key-pair).

В документации cloud.ru две платформы: **Advanced** (наш провайдер `sbercloud`, регион `ru-moscow-1`) и **Evolution** (другой провайдер и другие ресурсы). Смотрите разделы для Advanced.

### Сам Terraform
- [Документация OpenTofu](https://opentofu.org/docs/) — открытый форк Terraform. Язык и команды те же, сайт открывается из России. Особенно полезны разделы про язык: `variable`, `output`, `count`/`for_each`, функции.
- Справка прямо в терминале: `terraform -help`, `terraform plan -help`. Попробовать выражения: `terraform console`.

### Что попробовать самому
Идеи по возрастанию сложности. Ищите нужный ресурс в документации провайдера.
1. **Две ВМ вместо одной** через `count` или `for_each`. Output со списком IP.
2. **Дополнительный диск.** [`sbercloud_evs_volume`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/evs_volume.md) + [`sbercloud_compute_volume_attach`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/compute_volume_attach.md). На ВМ найдите его через `lsblk`, отформатируйте и смонтируйте.
3. **Стек занятия 9 на ВМ.** Через cloud-init поставьте Docker, склонируйте `devops-lab` и поднимите `lesson09` командой `docker compose up -d`.
4. **Балансировщик перед двумя ВМ.** [`sbercloud_lb_loadbalancer`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/lb_loadbalancer.md) и связанные ресурсы. Это тот же reverse proxy, что nginx на занятии 9, только облачный.
5. **State в облаке.** Бакет [`sbercloud_obs_bucket`](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/obs_bucket.md) и руководство [remote state backend](https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/guides/remote-state-backend.md). Так команда работает с одним state.

> **Правила песочницы в общем проекте курса.** Только свой префикс в именах и теги `course`/`owner`. Ничего не трогайте руками у других. Балансировщики, базы данных и Kubernetes стоят заметно дороже ВМ — сначала спросите преподавателя. И в конце **всегда `terraform destroy`**. Хотите экспериментировать без ограничений — заведите свой аккаунт cloud.ru и свои ключи.
