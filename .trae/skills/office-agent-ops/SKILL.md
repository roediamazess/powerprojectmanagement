---
name: "office-agent-ops"
description: "Operates the Office Agent module (routes, SSE, Telegram, UI redirects). Invoke when /office-agent, /agent-working-space, or run streams fail."
---

# Office Agent Ops

Skill ini untuk modul Office Agent: UI route, endpoint run/stream, polling activity/logger/security, serta integrasi Telegram.

## Kapan Dipakai

- `/office-agent` tidak tampil / blank / error.
- `/agent-working-space/` 404 atau masih mengarah ke UI eksternal.
- Run tidak jalan: `/office-agent/runs` error, SSE stream putus, status tidak update.

## Endpoint Penting

- UI: `/office-agent`
- Run: `POST /office-agent/runs`
- Stream: `GET /office-agent/runs/{runId}/stream`
- Activity: `GET /office-agent/activity`
- Logger: `GET /office-agent/logger/events`
- Security: `GET /office-agent/security/events`

## Debug Cepat (Docker)

```bash
docker compose -f laravel-app/docker-compose.prod.yml ps
docker compose -f laravel-app/docker-compose.prod.yml logs --tail=200 --no-color app
curl -sS -I http://127.0.0.1:8080/office-agent | head -n 10
```

## Redirect Legacy Path

Jika user masih akses `/agent-working-space/`, pastikan Nginx redirect ke `/office-agent` agar tidak bergantung folder `public/office-agent-ui`.

