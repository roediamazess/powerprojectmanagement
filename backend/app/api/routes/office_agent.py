import uuid
import json
import asyncio
import os
import urllib.request
from datetime import datetime
from typing import Any, AsyncGenerator

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.rbac import User
from app.models.time_boxing import TimeBoxing
from app.models.lookup import LookupValue, LookupCategory

router = APIRouter(dependencies=[Depends(csrf_protect)])

# Shared storage for runs (memory-based for now, Redis is better but this mimics Cache::put)
runs_cache = {}

class StoreRunPayload(BaseModel):
    prompt: str

@router.post("/store-run")
def store_run(payload: StoreRunPayload, user: User = Depends(get_current_user)):
    run_id = str(uuid.uuid4())
    runs_cache[f"{user.id}:{run_id}"] = {
        "prompt": payload.prompt,
        "created_at": datetime.utcnow().isoformat()
    }
    return {"data": {"run_id": run_id}}

async def generate_agent_stream(prompt: str, user: User, types: list[str]) -> AsyncGenerator[str, None]:
    def send_event(event: str, payload: dict):
        return f"event: {event}\ndata: {json.dumps(payload)}\n\n"

    yield send_event("status", {"state": "listening", "at": datetime.utcnow().isoformat()})
    await asyncio.sleep(0.5)
    yield send_event("status", {"state": "thinking", "at": datetime.utcnow().isoformat()})
    
    # Fake LLM logic / LLM logic
    api_key = os.getenv("OFFICE_AGENT_LLM_API_KEY", "")
    if not api_key:
        yield send_event("status", {"state": "acting", "at": datetime.utcnow().isoformat()})
        msg = "LLM belum dikonfigurasi. Backend tidak memiliki OFFICE_AGENT_LLM_API_KEY."
        for i in range(0, len(msg), 48):
            yield send_event("message_chunk", {"text": msg[i:i+48]})
            await asyncio.sleep(0.05)
        yield send_event("status", {"state": "done", "at": datetime.utcnow().isoformat()})
        yield send_event("done", {"at": datetime.utcnow().isoformat()})
        return

    # To implement exactly like Laravel, we would make a urllib request here.
    # We will simulate a fake response or fallback if api_key exists.
    # LLM request logic:
    sys_prompt = f"Kamu adalah Office Agent. User: {user.name}. Jawab pendek menggunakan bahasa indonesia."
    req_data = json.dumps({
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": prompt}
        ]
    }).encode("utf-8")
    
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=req_data,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    )
    
    try:
        response = urllib.request.urlopen(req, timeout=30)
        res_body = json.loads(response.read().decode("utf-8"))
        ans = res_body.get('choices', [{}])[0].get('message', {}).get('content', 'Tidak ada jawaban.')
    except Exception as e:
        ans = f"Gagal API: {e}"

    yield send_event("status", {"state": "acting", "at": datetime.utcnow().isoformat()})

    for i in range(0, len(ans), 48):
        yield send_event("message_chunk", {"text": ans[i:i+48]})
        await asyncio.sleep(0.05)

    yield send_event("status", {"state": "done", "at": datetime.utcnow().isoformat()})
    yield send_event("done", {"at": datetime.utcnow().isoformat()})


@router.get("/stream-run/{run_id}")
async def stream_run(run_id: str, request: Request, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    cache_key = f"{user.id}:{run_id}"
    if cache_key not in runs_cache:
        raise HTTPException(404, "Run not found")
        
    run_data = runs_cache.pop(cache_key)
    
    # Get Timeboxing types
    type_category = db.execute(select(LookupCategory).where(LookupCategory.key == "time_boxing.type")).scalar_one_or_none()
    types = []
    if type_category:
        types_val = db.execute(select(LookupValue).where(LookupValue.category_id == type_category.id)).scalars().all()
        types = [t.value for t in types_val]

    return StreamingResponse(
        generate_agent_stream(run_data["prompt"], user, types),
        media_type="text/event-stream"
    )

@router.get("/activity")
def get_activity(since: str | None = None, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    q = select(TimeBoxing).where(TimeBoxing.user_id == str(user.id)).order_by(TimeBoxing.updated_at.desc()).limit(15)
    items = db.execute(q).scalars().all()
    
    res = []
    for t in items:
        res.append({
            "at": t.updated_at.isoformat() if t.updated_at else datetime.utcnow().isoformat(),
            "message": f"#{t.no} · {t.type} · {t.status}",
            "detail": "{}"
        })
    
    return {
        "now": datetime.utcnow().isoformat(),
        "items": res
    }

@router.get("/logger-events")
def get_logger_events(since: str | None = None):
    # Dummy until implemented
    return {"now": datetime.utcnow().isoformat(), "items": []}

@router.get("/security-events")
def get_security_events(since: str | None = None):
    # Dummy until implemented
    return {"now": datetime.utcnow().isoformat(), "items": []}

