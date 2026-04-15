import os
import re
from datetime import datetime

from fastapi import APIRouter, Request, Header
from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.time_boxing import TimeBoxing

router = APIRouter()

# Note: Ideally this uses dependency injection for auth but Telegram sends its own token in headers or query
def get_telegram_chat_id() -> str:
    return os.getenv("TELEGRAM_CHAT_ID", "")

def get_telegram_secret() -> str:
    return os.getenv("TELEGRAM_WEBHOOK_SECRET", "")

def get_telegram_bot_token() -> str:
    return os.getenv("TELEGRAM_BOT_TOKEN", "")

def send_telegram_message(text: str, chat_id: str):
    token = get_telegram_bot_token()
    if not token or not chat_id:
        return
    import urllib.request
    import urllib.parse
    import json
    
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    req_data = json.dumps({
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML"
    }).encode("utf-8")
    
    req = urllib.request.Request(
        url,
        data=req_data,
        headers={"Content-Type": "application/json"}
    )
    
    try:
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"Telegram webhook send error: {e}")


@router.post("/webhook")
async def telegram_webhook(request: Request, x_telegram_bot_api_secret_token: str | None = Header(None)):
    secret = get_telegram_secret()
    if secret and secret != x_telegram_bot_api_secret_token:
        # Ignore bad secrets without returning error
        return {"ok": True}

    try:
        update = await request.json()
    except Exception:
        return {"ok": True}

    msg = update.get('message') or update.get('edited_message')
    if not isinstance(msg, dict):
        return {"ok": True}
        
    chat = msg.get('chat', {})
    chat_id = str(chat.get('id', ''))
    
    allowed_chat = get_telegram_chat_id()
    if allowed_chat and chat_id != allowed_chat:
        return {"ok": True}
        
    text = str(msg.get('text', '')).strip()
    if not text:
        return {"ok": True}

    # Simulate basic text parsing
    reply = handle_telegram_text(text)
    if reply:
        send_telegram_message(reply, chat_id)
        
    return {"ok": True}


def handle_telegram_text(text: str) -> str | None:
    t = text.lower()
    
    if re.search(r'^\/(start|help)\b', t):
        return "Perintah Time Boxing:\n/tb list [active|completed|all]\n/tb get <no>\n/tb delete <no>\n/tb create desc=<text>\n/tb update <no> status=completed"

    if re.search(r'^\/(tb|timeboxing)\b', t):
        parts = t.split()
        if len(parts) > 1:
            cmd = parts[1]
            if cmd == "list":
                return tb_list(parts[2:])
            elif cmd == "get" and len(parts) > 2:
                return tb_get(parts[2])
            elif cmd == "delete" and len(parts) > 2:
                return tb_delete(parts[2])
        return "Format salah, cek /help."

    if re.search(r'\boverdue\b|\bterlambat\b', t):
        return tb_list(["overdue"])

    if "time boxing" in t or "timeboxing" in t or re.search(r'\btb\b', t):
        if re.search(r'\bdaftar\b|\blist\b|\bsemua\b', t):
            if "completed" in t or "selesai" in t:
                return tb_list(["completed"])
            elif "all" in t or "semua" in t:
                return tb_list(["all"])
            return tb_list(["active"])
            
        m = re.search(r'(detail|liat|cek|get)\s+(\d+)', t)
        if m:
            return tb_get(m.group(2))
            
        m = re.search(r'(hapus|delete)\s+(\d+)', t)
        if m:
            return tb_delete(m.group(2))
            
        return "Instruksi dipahami: Ini adalah simulasi dari Telegram Bot NLP. Belum implementasi command NLP spesifik untuk mengubah status di FastAPI. Gunakan /tb untuk saat ini."
        
    return None

def tb_list(args: list[str]) -> str:
    scope = args[0] if args else "active"
    user_id = os.getenv("TIME_BOXING_IMPORT_USER_ID", "1")
    
    with SessionLocal() as db:
        q = select(TimeBoxing).where(TimeBoxing.user_id == user_id)
        
        if scope == "completed":
            q = q.where(TimeBoxing.status == "Completed")
        elif scope == "overdue":
            q = q.where(TimeBoxing.due_date < datetime.now().date()).where(TimeBoxing.status != "Completed")
        elif scope != "all":
            q = q.where(TimeBoxing.status != "Completed")
            
        items = db.execute(q.order_by(TimeBoxing.no.desc()).limit(10)).scalars().all()
        
        if not items:
            return f"Time Boxing kosong ({scope})"
            
        lines = [f"Time Boxing ({scope}):"]
        for t in items:
            line = f"#{t.no} [{t.status}] {t.type or ''} {t.priority or ''}"
            if t.due_date:
                line += f" due {t.due_date}"
            if t.description:
                line += f" — {t.description[:60]}"
            lines.append(line)
            
        return "\n".join(lines)

def tb_get(no_str: str) -> str:
    try:
        no = int(no_str)
    except (TypeError, ValueError):
        return "Nomor tidak valid"
        
    user_id = os.getenv("TIME_BOXING_IMPORT_USER_ID", "1")
    with SessionLocal() as db:
        t = db.execute(select(TimeBoxing).where(TimeBoxing.user_id == user_id).where(TimeBoxing.no == no)).scalar_one_or_none()
        if not t:
            return f"Time Boxing #{no} tidak ditemukan."
            
        lines = [
            f"Time Boxing #{t.no}",
            f"Type: {t.type}",
            f"Priority: {t.priority}",
            f"Status: {t.status}"
        ]
        if t.due_date:
            lines.append(f"Due: {t.due_date}")
        if t.description:
            lines.append(f"Desc: {t.description}")
        return "\n".join(lines)

def tb_delete(no_str: str) -> str:
    try:
        no = int(no_str)
    except (TypeError, ValueError):
        return "Nomor tidak valid"
        
    user_id = os.getenv("TIME_BOXING_IMPORT_USER_ID", "1")
    with SessionLocal() as db:
        t = db.execute(select(TimeBoxing).where(TimeBoxing.user_id == user_id).where(TimeBoxing.no == no)).scalar_one_or_none()
        if not t:
            return f"Time Boxing #{no} tidak ditemukan."
            
        db.delete(t)
        db.commit()
        return f"Deleted Time Boxing #{no}"
