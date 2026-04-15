import os

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.rbac import Role, User, user_roles
from app.security.password import hash_password

def run():
    email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    password = os.getenv("ADMIN_PASSWORD", "")
    name = os.getenv("ADMIN_NAME", "Administrator").strip() or "Administrator"
    if not email or not password:
        raise RuntimeError("ADMIN_EMAIL and ADMIN_PASSWORD are required")

    db = SessionLocal()
    try:
        user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
        admin_role = db.execute(select(Role).where(Role.name == "Administrator")).scalar_one_or_none()

        if user:
            user.name = name
            user.password_hash = hash_password(password)
            user.is_active = True
        else:
            user = User(email=email, name=name, password_hash=hash_password(password), is_active=True)
            db.add(user)
            db.flush()

        if admin_role:
            exists = db.execute(
                select(user_roles.c.role_id).where(user_roles.c.user_id == user.id).where(user_roles.c.role_id == admin_role.id)
            ).scalar_one_or_none()
            if not exists:
                db.execute(user_roles.insert().values(user_id=user.id, role_id=admin_role.id))

        db.commit()
    finally:
        db.close()

if __name__ == "__main__":
    run()
