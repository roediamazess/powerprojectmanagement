from __future__ import annotations

import argparse

from sqlalchemy import select, text

from app.db.session import LaravelSessionLocal, SessionLocal
from app.models.rbac import Role, User, user_roles
from app.security.password import hash_password


def _get_or_create_role(db, name: str) -> Role:
    row = db.execute(select(Role).where(Role.name == name)).scalar_one_or_none()
    if row:
        return row
    row = Role(name=name)
    db.add(row)
    db.flush()
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", default="", help="Import single user by email (optional)")
    parser.add_argument(
        "--password-mode",
        choices=["copy", "set"],
        default="set",
        help="copy = copy bcrypt hash from Laravel; set = set password to --password",
    )
    parser.add_argument("--password", default="", help="New password to set when --password-mode=set")
    args = parser.parse_args()

    if LaravelSessionLocal is None:
        raise RuntimeError("LARAVEL_DATABASE_URL is required to import from Laravel DB")

    src = LaravelSessionLocal()
    dst = SessionLocal()
    try:
        where_sql = ""
        params: dict[str, object] = {}
        if args.email:
            where_sql = "WHERE lower(email) = lower(:email)"
            params["email"] = args.email.strip()

        users = src.execute(
            text(
                f"""
                SELECT id, name, email, password, created_at, updated_at
                FROM users
                {where_sql}
                ORDER BY id ASC
                """
            ),
            params,
        ).mappings().all()

        if not users:
            raise RuntimeError("No matching users found in Laravel DB")

        if args.password_mode == "set" and not args.password:
            raise RuntimeError("--password is required when --password-mode=set")

        imported = 0
        for u in users:
            email = (u.get("email") or "").strip().lower()
            name = (u.get("name") or "").strip() or email
            if not email:
                continue

            pwd_hash = hash_password(args.password) if args.password_mode == "set" else (u.get("password") or "").strip()
            if not pwd_hash:
                raise RuntimeError(f"Password hash missing for {email}")

            dst_user = dst.execute(select(User).where(User.email == email)).scalar_one_or_none()
            if not dst_user:
                dst_user = User(email=email, name=name, password_hash=pwd_hash, is_active=True)
                dst_user.created_at = u.get("created_at")
                dst.add(dst_user)
                dst.flush()
            else:
                # Update existing user
                dst_user.name = name
                dst_user.password_hash = pwd_hash
                dst_user.is_active = True
                dst.flush()

            roles = src.execute(
                text(
                    """
                    SELECT r.name
                    FROM model_has_roles mhr
                    JOIN roles r ON r.id = mhr.role_id
                    WHERE mhr.model_type = :model_type
                      AND mhr.model_id = :model_id
                    ORDER BY r.name ASC
                    """
                ),
                {"model_id": u["id"], "model_type": "App\\Models\\User"},
            ).scalars().all()

            for role_name in roles:
                role_name = (role_name or "").strip()
                if not role_name:
                    continue
                dst_role = _get_or_create_role(dst, role_name)
                exists = dst.execute(
                    select(user_roles.c.role_id)
                    .where(user_roles.c.user_id == dst_user.id)
                    .where(user_roles.c.role_id == dst_role.id)
                ).scalar_one_or_none()
                if not exists:
                    dst.execute(user_roles.insert().values(user_id=dst_user.id, role_id=dst_role.id))

            imported += 1

        dst.commit()
        print(f"Imported users: {imported}")
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    main()

