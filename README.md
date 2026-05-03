# Лабораторні роботи з Деплойменту

**Студент:** Іван Євсєєв | [GitHub репозиторій](https://github.com/Aligheri/deployment-labs)

## Зміст

- [Лаб. 1 — Systemd](#лабораторна-робота-1--розгортання-через-systemd)
- [Лаб. 2 — Контейнеризація](#лабораторна-робота-2--контейнеризація)
- [Лаб. 3 — CI/CD](#лабораторна-робота-3--cicd)

---

## Лабораторна робота 1 — Розгортання через Systemd

REST-сервіс інвентаризації на Spring Boot 3 / Java 21 / PostgreSQL. Nginx reverse proxy, systemd socket activation.

**Варіант:** N=5, V2=2, V3=3, V5=1 — Simple Inventory, конфіг `/etc/mywebapp/config.yaml`, порт 8080 за nginx на 80.

### API

| Метод | Шлях | Опис |
|-------|------|------|
| GET | `/` | HTML-список ендпоінтів |
| GET | `/items` | список елементів (JSON або HTML) |
| POST | `/items?name=&quantity=` | створити елемент |
| GET | `/items/{id}` | елемент за id |
| GET | `/health/alive` | liveness check |
| GET | `/health/ready` | readiness check (перевіряє БД) |

Nginx проксує лише `/` та `/items*`. Health-ендпоінти доступні тільки зсередини сервера.

### Розгортання

```bash
cd lab1
./gradlew bootJar
sudo bash deploy/install.sh
```

### Користувачі

| Користувач | Пароль | Роль |
|------------|--------|------|
| student | 12345678 | sudo |
| teacher | 12345678 | sudo |
| operator | 12345678 | керування mywebapp і reload nginx |
| mywebapp | — | системний, запускає застосунок |

### Перевірка

```bash
systemctl status mywebapp nginx
curl http://<ip>/items
curl -X POST "http://<ip>/items?name=Monitor&quantity=2"
curl http://127.0.0.1:8080/health/ready   # тільки зсередини
```

---

## Лабораторна робота 2 — Контейнеризація

### Практична частина — Docker Compose (lab1/)

```bash
cd lab1
docker compose up -d
```

Застосунок доступний на `http://localhost`.

| Сервіс | Образ | Опис |
|--------|-------|------|
| app | multi-stage `eclipse-temurin:21-jdk-alpine` → `21-jre-alpine` | Spring Boot |
| db | postgres:16-alpine | дані в named volume `db_data` |
| nginx | nginx:alpine | reverse proxy, порт 80 |

Дані переживають `docker compose down`. Видалити БД: `docker compose down -v`.

---

### Дослідницька частина

#### Частина 1 — Python-застосунок (`lab2/python-app/`)

FastAPI + uvicorn. Досліджували вплив порядку COPY-інструкцій і базового образу на час збірки.

| Dockerfile | База | Розмір | Повторна збірка після зміни коду |
|:-----------|:-----|:-------|:---------------------------------|
| `Dockerfile.simple` | python:3.12 | 1.18 GB | 76 s |
| `Dockerfile.optimized` | python:3.12 | 1.18 GB | 2.1 s |
| `Dockerfile.alpine` | python:3.12-alpine | 196 MB | 2.2 s |

```bash
cd lab2/python-app
docker pull python:3.12 && docker pull python:3.12-alpine
time docker build --no-cache -f Dockerfile.simple    -t spaceship:simple    .
time docker build --no-cache -f Dockerfile.optimized -t spaceship:optimized .
time docker build --no-cache -f Dockerfile.alpine    -t spaceship:alpine    .
```

**Ключовий висновок:** порядок двох рядків у Dockerfile (`COPY requirements.txt` перед `COPY .`) дав **36× прискорення** повторної збірки при нульовій зміні розміру образу.

**Проблема з непінованими залежностями:** `backend.in` містить `pydantic>=2.0` — дві збірки в різні дні можуть дати різні версії. Зафіксовані версії у `requirements/backend.txt` (`pip-compile`).

---

#### Частина 2 — musl (Alpine) vs glibc (Debian)

Перевіряли різницю в поведінці DNS-резолвера при використанні search domain.

```bash
docker network create dns-lab

# DNS-сервер з кастомним доменом
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  dnsmasq -k --log-queries"

# Ubuntu (glibc)
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" ubuntu:latest getent hosts myservice.internal

# Alpine (musl)
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" alpine:latest getent hosts myservice.internal
```

| Контейнер | Результат | Що сталося |
|:----------|:----------|:-----------|
| Ubuntu (glibc) | `10.0.0.50` — успіх | запит `myservice.internal.corp` |
| Alpine (musl) | `not found` | запит `myservice.internal` (без домену) |

**Причина:** musl не додає search domain до імен, що вже містять крапку. glibc додає до всіх імен з кількістю крапок менше `ndots` (за замовчуванням 1 у Docker).

**Рішення:** повні FQDN (`myservice.internal.corp.`), або `ndots:0`, або `dns_opt: ["ndots:5"]` у Compose.

---

#### Частина 3 — Golang та Multi-stage builds (`lab2/golang-app/`)

FizzBuzz CLI + HTTP server на Cobra. Зменшували розмір образу поетапно.

| Dockerfile | Фінальний образ | Розмір |
|:-----------|:----------------|:-------|
| `Dockerfile.single` | golang:1.17 | 945 MB |
| `Dockerfile.scratch` | scratch | 11.1 MB |
| `Dockerfile.distroless` | distroless/static-debian12 | 13.1 MB |

```bash
cd lab2/golang-app
time docker build --no-cache -f Dockerfile.single     -t fizzbuzz:single     .
time docker build --no-cache -f Dockerfile.scratch     -t fizzbuzz:scratch     .
time docker build --no-cache -f Dockerfile.distroless  -t fizzbuzz:distroless  .
```

**Проблема scratch:** `go build` за замовчуванням будує динамічний бінарник. Рішення: `CGO_ENABLED=0 go build -a` — повністю статичний ELF.

**Scratch vs distroless:** різниця 2 MB, але distroless дає CA-сертифікати, timezone і ненульовий UID. Для продакшну — distroless.

---

## Лабораторна робота 3 — CI/CD

### Пайплайни

| Workflow | Тригер |
|----------|--------|
| **CI** `.github/workflows/ci.yml` | push до `main`, анотовані теги `v*.*.*`, PR до `main` |
| **CD** `.github/workflows/cd.yml` | успішне CI на анотованому тезі |

**CI:** `lint` → `test` → `build`
- **lint:** Hadolint, Shellcheck, Yamllint, Checkstyle
- **test:** JUnit + JaCoCo ≥ 40%; coverage-report як артефакт
- **build:** multi-platform image (`linux/amd64,linux/arm64`) → GHCR
  - гілка: `latest`, `sha-<hash>`
  - тег: `stable`, `<tag>`

**CD:** `deploy` → `verify` (self-hosted runner, мітка `deploy`)

### Структура lab3/

```
lab3/
  setup-runner.sh       # встановлення self-hosted runner (Ubuntu 24.04)
  setup-target.sh       # налаштування target node
  verify.sh             # верифікація після деплою (6 перевірок)
  deploy/
    deploy.sh           # скрипт деплою на target node
    mywebapp.service    # systemd unit для керування контейнером
    nginx/mywebapp.conf # nginx конфіг
```

### GitHub Secrets

| Secret | Опис |
|--------|------|
| `TARGET_HOST` | IP target node |
| `TARGET_PORT` | SSH порт |
| `TARGET_USER` | SSH-користувач (docker group + sudo systemctl) |
| `TARGET_SSH_KEY` | Приватний SSH-ключ runner-а |
| `CR_PAT` | GitHub PAT зі scope `read:packages` |

### Налаштування runner VM

```bash
# 1. Встановити залежності
sudo bash lab3/setup-runner.sh

# 2. Зареєструвати (токен: GitHub → Settings → Actions → Runners)
cd /opt/actions-runner
sudo -u runner ./config.sh \
  --url https://github.com/Aligheri/deployment-labs \
  --token <TOKEN> --labels deploy --name deploy-runner --unattended
sudo ./svc.sh install runner && sudo ./svc.sh start
```

### Налаштування target node

```bash
sudo bash lab3/setup-target.sh
# після першого деплою:
sudo systemctl start mywebapp
```

### Branch protection

GitHub → Settings → Branches → `main`: require `Lint` + `Test` before merge.
