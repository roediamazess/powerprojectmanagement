# Deploy ke VPS (Docker)

## Build & Run (Production)

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Buka:

- http://IP_VPS:3000

## Update versi terbaru

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --build
```

## Lihat log

```bash
docker compose -f docker-compose.prod.yml logs -f web
```

## Stop

```bash
docker compose -f docker-compose.prod.yml down
```
