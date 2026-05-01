# Лабораторні роботи з Деплойменту

**Студент:** Іван Євсєєв

```
lab1/   — Лаб. 1: розгортання через systemd (Spring Boot + Nginx + PostgreSQL)
lab2/   — Лаб. 2: Dockerfile-и для дослідницької частини (Python, Golang)
lab3/   — Лаб. 3: CI/CD (GitHub Actions, self-hosted runner, автодеплой)
```

---

## Лабораторна робота №1 — Розгортання через Systemd

Простий REST-сервіс інвентаризації на Spring Boot 21 і PostgreSQL.

**Варіант:** N=5, V2=2, V3=3, V5=1 — Simple Inventory, конфіг `/etc/mywebapp/config.yaml`, порт 8080 за nginx на порту 80.

### API

| Метод | Шлях | Опис |
|-------|------|------|
| GET | `/` | HTML-список ендпоінтів |
| GET | `/items` | список всіх елементів |
| POST | `/items?name=&quantity=` | створити елемент |
| GET | `/items/{id}` | отримати елемент за id |
| GET | `/health/alive` | liveness check |
| GET | `/health/ready` | readiness check (перевіряє БД) |

Бізнес-ендпоінти підтримують `Accept: application/json` і `Accept: text/html`. Health-ендпоінти внутрішні — nginx їх не проксує.

### Розгортання (Ubuntu 24.04)

```bash
cd lab1
./gradlew bootJar
sudo bash deploy/install.sh
```

Скрипт створює системних користувачів, налаштовує PostgreSQL, nginx, systemd і запускає сервіс.

### Створені користувачі

| Користувач | Пароль | Роль |
|------------|--------|------|
| student | 12345678 | sudo |
| teacher | 12345678 | sudo, змінити пароль при першому вході |
| operator | 12345678 | керування сервісом mywebapp і reload nginx |
| mywebapp | — | системний користувач, запускає застосунок |

### Перевірка

```bash
systemctl status mywebapp nginx

curl http://<ip>/items
curl -X POST "http://<ip>/items?name=Monitor&quantity=2"

# health (тільки зсередини сервера)
curl http://127.0.0.1:8080/health/ready
```

---

## Лабораторна робота №2 — Контейнеризація

### Швидкий старт (Docker Compose)

Піднімає всі три сервіси в контейнерах — попередньо збирати JAR не потрібно:

```bash
cd lab1
docker compose up -d
```

Застосунок доступний на `http://localhost`.

- **app** — Spring Boot, multi-stage build (`eclipse-temurin:21-jdk-alpine` → `21-jre-alpine`)
- **db** — PostgreSQL 16, дані в named volume `db_data`
- **nginx** — Alpine reverse proxy на порту 80
- **мережа** — custom bridge `lab2_net`, default network не використовується

Дані переживають `docker compose down` і перезавантаження системи. Для повного видалення БД: `docker compose down -v`.

---

### Дослідницька частина

---

## Частина 1. Python-застосунок

**Проект:** `lab2/python-app/` (FastAPI + uvicorn)

### Що робили

Збирали образи на основі одного й того самого застосунку, змінюючи щоразу одну змінну: порядок COPY-інструкцій, базовий образ, набір залежностей. Час збірки вимірювали за умови, що базовий образ вже завантажений (`docker pull` виконувався окремо).

Три Dockerfile-и відповідають трьом етапам: наївна збірка → оптимізовані шари → менший базовий образ. Numpy додано на третьому етапі (крок 5 завдання), тому всі Dockerfile-и містять numpy у фінальному образі. Вимірювання рядків 1–2 зроблені до додавання numpy (для ізоляції змінної "порядок шарів"), рядка 3 — після.

### Результати

| Dockerfile | База | Розмір | Холодна збірка | Після зміни коду |
|:-----------|:-----|:-------|:---------------|:-----------------|
| `Dockerfile.simple` (без numpy) | python:3.12 | 1.18 GB | 44 s | 76 s |
| `Dockerfile.optimized` (без numpy) | python:3.12 | 1.18 GB | 41 s | 2.1 s |
| `Dockerfile.alpine` (з numpy) | python:3.12-alpine | 196 MB | 78 s | 2.2 s |
| `Dockerfile.optimized` (з numpy) | python:3.12 | 1.26 GB | 78 s | 2.5 s |

> Рядки "без numpy" — виміри зроблені на версії коду до кроку 5, коли numpy ще не було в залежностях. Поточні Dockerfile-и встановлюють numpy (відповідає поточному стану `spaceship/routers/api.py`).

Відтворення:

```bash
cd lab2/python-app
docker pull python:3.12 && docker pull python:3.12-alpine

time docker build --no-cache -f Dockerfile.simple     -t spaceship:simple     .
time docker build --no-cache -f Dockerfile.optimized  -t spaceship:optimized  .
time docker build --no-cache -f Dockerfile.alpine     -t spaceship:alpine     .

# Повторна збірка після зміни коду (без --no-cache):
time docker build -f Dockerfile.simple    -t spaceship:simple    .
time docker build -f Dockerfile.optimized -t spaceship:optimized .
```

### Труднощі та їх причини

**Проблема з кешем у `Dockerfile.simple`:**
```dockerfile
COPY . .
RUN pip install -r requirements/backend.in
```
Docker інвалідує шар із `pip install` щоразу, коли змінюється будь-який файл у контексті (навіть коментар у `.py`). Тому повторна збірка займає 76 s — стільки ж, скільки холодна: pip перевстановлює всі залежності заново.

**Непіновані залежності:**
`backend.in` містить `pydantic>=2.0` без фіксованої версії — дві збірки в різні дні можуть встановити різні версії. Для відтворюваних образів потрібен `pip freeze` або `pip-compile`. Результат — `requirements/backend.txt` з зафіксованими версіями всіх транзитивних залежностей.

**numpy на Alpine:**
Очікували, що встановлення numpy на Alpine потребуватиме компіляції (Alpine використовує musl, і раніше бінарні wheels для musl не публікувалися). Але pip знайшов musllinux-wheel для numpy 2.2.1 і встановив без компіляції. Час збірки з numpy (78 s) однаковий для обох базових образів.

### Висновки

Найбільше здивувала різниця між `Dockerfile.simple` і `Dockerfile.optimized`: **розмір образу однаковий (1.18 GB), але час повторної збірки відрізняється в 36 разів (76 s → 2.1 s)**. Причина — тільки порядок двох рядків у Dockerfile. Це найдешевша оптимізація з усіх розглянутих.

Перехід на Alpine дав зменшення в ~6.4× (1.26 GB → 196 MB) після додавання numpy. Alpine залишається суттєво меншим навіть із важкими бібліотеками.

---

## Частина 2. Musl (Alpine) vs glibc (Debian/Ubuntu)

### Що робили

Перевіряли різницю в поведінці DNS-резолвера між контейнерами на основі glibc (Ubuntu) і musl (Alpine) при використанні search domain.

### Відтворення

```bash
docker network create dns-lab

# DNS-сервер з кастомним доменом
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  dnsmasq -k --log-queries --log-facility=-"

# Ubuntu (glibc)
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" ubuntu:latest getent hosts myservice.internal

# Alpine (musl)
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" alpine:latest getent hosts myservice.internal
```

### Результати

| Контейнер | Результат | Що відбулось |
|:----------|:----------|:-------------|
| Ubuntu (glibc) | `10.0.0.50` — успіх | Надіслав запит `myservice.internal.corp` |
| Alpine (musl) | `not found` — помилка | Надіслав запит `myservice.internal` без домену |

В логах dnsmasq видно: Ubuntu робить запит `myservice.internal.corp`, Alpine — `myservice.internal`.

### Труднощі та причини

musl не додає search domain до імен, що **вже містять крапку** — вважаючи їх "достатньо кваліфікованими". glibc додає search domain до всіх імен, де кількість крапок менша за `ndots` (за замовчуванням 1 у Docker).

`myservice.internal` містить крапку → musl вважає його FQDN → не чіпає search domain → DNS-запит іде без `.corp` → запис не знайдено.

### Висновки

Якщо перевести один сервіс кластеру на Alpine, а решта залишаться на Debian/Ubuntu, частина з'єднань за внутрішніми іменами типу `service.namespace` або `api.internal` може починати мовчки падати тільки на Alpine-контейнерах. Без розуміння різниці musl/glibc такий баг дуже важко діагностувати.

Рішення: використовувати повні FQDN (`myservice.internal.corp.`), або `ndots:0` у `resolv.conf`, або `dns_opt: ["ndots:5"]` у Docker Compose.

---

## Частина 3. Golang та Multi-stage builds

**Проект:** `lab2/golang-app/` (FizzBuzz CLI + HTTP server на Cobra)

### Що робили

Поступово зменшували розмір образу: single-stage → multi-stage зі scratch → multi-stage з distroless.

### Відтворення

```bash
cd lab2/golang-app

time docker build --no-cache -f Dockerfile.single     -t fizzbuzz:single     .
time docker build --no-cache -f Dockerfile.scratch     -t fizzbuzz:scratch     .
time docker build --no-cache -f Dockerfile.distroless  -t fizzbuzz:distroless  .

docker images | grep fizzbuzz
```

### Результати

| Dockerfile | Фінальний образ | Розмір | Вміст |
|:-----------|:----------------|:-------|:------|
| `Dockerfile.single` | golang:1.17 | 945 MB | Go SDK, компілятор, вихідний код, кеш модулів |
| `Dockerfile.scratch` | scratch | 11.1 MB | Статичний бінарник + `templates/` |
| `Dockerfile.distroless` | distroless/static-debian12 | 13.1 MB | Бінарник + CA-сертифікати + timezone |

### Труднощі та причини

**Scratch: `no such file or directory`**

Перша спроба multi-stage зі scratch завершилась помилкою при запуску:
```
standard_init_linux.go: exec user process caused: no such file or directory
```
`go build` за замовчуванням будує динамічно скомпонований бінарник, який шукає `/lib/x86_64-linux-gnu/libc.so.6` при старті. У scratch цього файлу немає — Linux не може навіть розпочати виконання процесу, помилка виникає ще до `main()`.

Рішення: `CGO_ENABLED=0 go build -a`. `CGO_ENABLED=0` вимикає CGo і змушує компілятор використовувати чисту Go-реалізацію stdlib. `-a` перезбирає всі пакети з новими налаштуваннями (без нього частина може залишитись зкешованою у динамічній версії). Результат — повністю статичний ELF.

**Scratch і distroless: відсутній шелл**

`docker exec -it <container> sh` повертає помилку — немає `/bin/sh`. Для дебагу: `docker cp` або `:debug`-тег distroless (`gcr.io/distroless/static-debian12:debug` додає busybox).

### Висновки

Різниця між single-stage (945 MB) і scratch (11.1 MB) — **85×**. Час збірки обох однаковий (~3-4 хв), бо компіляція займає однаковий час — змінюється лише те, що потрапляє в фінальний шар.

Між scratch (11.1 MB) і distroless (13.1 MB) різниця лише 2 MB, але distroless дає CA-сертифікати, timezone-дані і ненульовий UID. Для продакшн-сервісу це суттєво. Scratch має сенс лише якщо потрібно мінімізувати attack surface до абсолюту і ці можливості точно не потрібні.

---

## Частина 4. Практична частина: контейнеризація Лаб. 1

**Файли:** `lab1/Dockerfile`, `lab1/docker-compose.yml`

### Що робили

Контейнеризували три сервіси з Лаб. 1: Spring Boot, PostgreSQL, Nginx. Задача: `docker compose up -d` підіймає всю систему без ручних кроків, дані БД зберігаються після перезапуску.

### Dockerfile (multi-stage)

```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY gradlew build.gradle settings.gradle ./
COPY gradle/ gradle/
RUN ./gradlew dependencies --no-daemon
COPY src/ src/
RUN ./gradlew bootJar --no-daemon -x test

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.config.location=/etc/mywebapp/config.yaml"]
```

Перший варіант Dockerfile копіював вже зібраний JAR (`COPY build/libs/...`), що вимагало запускати `./gradlew bootJar` вручну перед `docker compose up`. Multi-stage build вирішує це: Docker сам збирає JAR всередині builder-контейнера.

Шар `RUN ./gradlew dependencies` завантажує всі Maven-залежності до того, як копіюється `src/`. Зміна у Java-коді не тригерить повторне завантаження 200+ бібліотек.

### docker-compose.yml: race condition

Перший варіант `depends_on: [db]` чекав лише запуску **контейнера** db, але не готовності PostgreSQL. Spring Boot стартував раніше, ніж PostgreSQL ініціалізував базу, і падав з `Connection refused`.

Рішення — healthcheck + `condition: service_healthy`:
```yaml
db:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U mywebapp -d mywebapp"]
    interval: 10s
    timeout: 5s
    retries: 5

app:
  depends_on:
    db:
      condition: service_healthy
```

---

## Загальні висновки

Найцікавіший результат — **порядок інструкцій у Dockerfile має більший вплив на час збірки, ніж вибір базового образу**. Переставити два рядки (`COPY requirements.txt` до `COPY .`) дало 36× прискорення повторних збірок при нульовій зміні розміру. Це найвигідніша оптимізація, доступна абсолютно безкоштовно.

Вибір Alpine vs Debian критично важливий для розміру, але треба тестувати: musl libc веде себе інакше в DNS, і якщо є внутрішня DNS-зона з іменами, що містять крапки, Alpine-контейнери можуть мовчки не з'єднуватись з іншими сервісами.

Multi-stage build для скомпільованих мов (Go, Java) — не опціональна оптимізація, а базова гігієна: тримати SDK в продакшн-образі немає сенсу.

Distroless — розумний компроміс між scratch (мінімальний розмір) і Alpine (є шелл). Різниця в 2 MB між ними не варта відмови від CA-сертифікатів і timezone.

---

## Лабораторна робота №3 — CI/CD

### Пайплайни

| Workflow | Файл | Тригер |
|----------|------|--------|
| CI | `.github/workflows/ci.yml` | push до `main`, анотовані теги `v*.*.*`, PR до `main` |
| CD | `.github/workflows/cd.yml` | успішне завершення CI на анотованому тезі |

**CI jobs:** `lint` → `test` → `build`

- **lint**: Hadolint (Dockerfile), Shellcheck (shell-скрипти), Yamllint (YAML), Checkstyle (Java)
- **test**: JUnit + JaCoCo, мінімальне покриття 40%; coverage-report завантажується як артефакт
- **build**: multi-stage Docker image → GHCR (`ghcr.io/aligheri/deployment-lab1`)
  - branch commit: `latest`, `sha-<full-hash>`
  - анотований тег: `stable`, `<tag>`

**CD jobs:** `deploy` → `verify` (запускаються на self-hosted runner з міткою `deploy`)

### Структура lab3/

```
lab3/
  setup-runner.sh       # встановлення self-hosted runner (Ubuntu 24.04)
  setup-target.sh       # початкове налаштування target node
  verify.sh             # верифікація після розгортання
  deploy/
    deploy.sh           # скрипт розгортання (виконується на target node)
    mywebapp.service    # systemd unit для керування контейнером
    nginx/
      mywebapp.conf     # nginx конфіг для контейнерного розгортання
```

### Необхідні GitHub Secrets

| Secret | Опис |
|--------|------|
| `TARGET_HOST` | IP або hostname target node |
| `TARGET_USER` | SSH-користувач на target node (потрібен docker group + sudo systemctl) |
| `TARGET_SSH_KEY` | Приватний SSH-ключ runner-а (`~/.ssh/target_key`) |
| `CR_PAT` | GitHub PAT зі scope `read:packages` для pull з GHCR |

### Налаштування self-hosted runner

```bash
# 1. На runner VM (Ubuntu 24.04):
sudo bash lab3/setup-runner.sh

# 2. Зареєструвати вручну (токен з GitHub → Settings → Actions → Runners):
cd /opt/actions-runner
sudo -u runner ./config.sh \
  --url https://github.com/Aligheri/deployment-lab1 \
  --token <TOKEN> \
  --labels deploy --name deploy-runner --unattended
/opt/actions-runner/svc.sh install runner
/opt/actions-runner/svc.sh start
```

### Налаштування target node

```bash
# На target VM (Ubuntu 24.04):
sudo bash lab3/setup-target.sh

# Після першого деплою:
sudo systemctl start mywebapp
```

### Branch protection

У GitHub → Settings → Branches → `main`:
- Require status checks: `Lint`, `Test`
- Require branches to be up to date before merging
