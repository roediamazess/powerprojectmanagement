from __future__ import annotations

import argparse
import re

from sqlalchemy import select, text

from app.db.session import LaravelSessionLocal, SessionLocal
from app.models.lookup import LookupCategory, LookupValue
from app.models.partners import Partner, PartnerContact


def _norm_value(raw: str) -> str:
    v = raw.strip().upper()
    v = re.sub(r"[^A-Z0-9]+", "_", v)
    v = re.sub(r"_+", "_", v).strip("_")
    return v or "UNKNOWN"


def _get_or_create_category(db, key: str) -> LookupCategory:
    row = db.execute(select(LookupCategory).where(LookupCategory.key == key)).scalar_one_or_none()
    if row:
        return row
    row = LookupCategory(key=key)
    db.add(row)
    db.flush()
    return row


def _get_or_create_value(db, category: LookupCategory, raw: str) -> LookupValue:
    value = _norm_value(raw)
    row = (
        db.execute(
            select(LookupValue)
            .where(LookupValue.category_id == category.id)
            .where(LookupValue.value == value)
        )
        .scalar_one_or_none()
    )
    if row:
        return row
    row = LookupValue(category_id=category.id, value=value, label=raw.strip(), sort_order=0)
    db.add(row)
    db.flush()
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    if LaravelSessionLocal is None:
        raise RuntimeError("LARAVEL_DATABASE_URL is required to import from Laravel DB")

    src = LaravelSessionLocal()
    dst = SessionLocal()
    try:
        sql = """
            SELECT
              id,
              cnc_id,
              name,
              star,
              room,
              outlet,
              status,
              system_live,
              address,
              area,
              sub_area,
              implementation_type,
              system_version,
              type,
              "group",
              gm_email,
              fc_email,
              ca_email,
              cc_email,
              ia_email,
              it_email,
              hrd_email,
              fom_email,
              dos_email,
              ehk_email,
              fbm_email,
              last_visit,
              last_visit_type,
              last_project,
              last_project_type,
              created_at,
              updated_at
            FROM partners
            ORDER BY id ASC
        """
        if args.limit and args.limit > 0:
            sql += " LIMIT :limit"
            rows = src.execute(text(sql), {"limit": args.limit}).mappings().all()
        else:
            rows = src.execute(text(sql)).mappings().all()

        cat_status = _get_or_create_category(dst, "partner.status")
        cat_impl = _get_or_create_category(dst, "partner.implementation_type")
        cat_sysver = _get_or_create_category(dst, "partner.system_version")
        cat_type = _get_or_create_category(dst, "partner.type")
        cat_group = _get_or_create_category(dst, "partner.group")

        email_cols = [
            ("GM", "gm_email"),
            ("FC", "fc_email"),
            ("CA", "ca_email"),
            ("CC", "cc_email"),
            ("IA", "ia_email"),
            ("IT", "it_email"),
            ("HRD", "hrd_email"),
            ("FOM", "fom_email"),
            ("DOS", "dos_email"),
            ("EHK", "ehk_email"),
            ("FBM", "fbm_email"),
        ]

        imported = 0
        for r in rows:
            cnc_id = (r.get("cnc_id") or "").strip()
            name = (r.get("name") or "").strip()
            if not cnc_id or not name:
                continue

            partner = dst.execute(select(Partner).where(Partner.cnc_id == cnc_id)).scalar_one_or_none()
            if not partner:
                partner = Partner(cnc_id=cnc_id, name=name)
                dst.add(partner)
                dst.flush()
            else:
                partner.name = name

            partner.star = r.get("star")
            partner.room = r.get("room")
            partner.outlet = r.get("outlet")
            partner.system_live = r.get("system_live")
            partner.address = r.get("address")
            partner.area = r.get("area")
            partner.sub_area = r.get("sub_area")
            partner.last_visit = r.get("last_visit")
            partner.last_visit_type = r.get("last_visit_type")
            partner.last_project = r.get("last_project")
            partner.last_project_type = r.get("last_project_type")

            status_raw = (r.get("status") or "").strip()
            if status_raw:
                mapped = status_raw
                if status_raw.lower() == "active":
                    mapped = "ACTIVE"
                elif status_raw.lower() == "inactive":
                    mapped = "INACTIVE"
                partner.status_id = _get_or_create_value(dst, cat_status, mapped).id

            impl_raw = (r.get("implementation_type") or "").strip()
            if impl_raw:
                partner.implementation_type_id = _get_or_create_value(dst, cat_impl, impl_raw).id

            sysver_raw = (r.get("system_version") or "").strip()
            if sysver_raw:
                partner.system_version_id = _get_or_create_value(dst, cat_sysver, sysver_raw).id

            type_raw = (r.get("type") or "").strip()
            if type_raw:
                partner.partner_type_id = _get_or_create_value(dst, cat_type, type_raw).id

            group_raw = (r.get("group") or "").strip()
            if group_raw:
                partner.partner_group_id = _get_or_create_value(dst, cat_group, group_raw).id

            for role_key, col in email_cols:
                email = (r.get(col) or "").strip()
                if not email:
                    continue
                contact = (
                    dst.execute(
                        select(PartnerContact)
                        .where(PartnerContact.partner_id == partner.id)
                        .where(PartnerContact.role_key == role_key)
                    )
                    .scalar_one_or_none()
                )
                if not contact:
                    contact = PartnerContact(partner_id=partner.id, role_key=role_key, email=email, is_primary=(role_key == "GM"))
                    dst.add(contact)
                else:
                    contact.email = email

            created_at = r.get("created_at")
            updated_at = r.get("updated_at")
            if created_at is not None:
                partner.created_at = created_at
            if updated_at is not None:
                partner.updated_at = updated_at

            imported += 1
            if imported % 200 == 0:
                dst.commit()

        dst.commit()
        print(f"Imported partners: {imported}")
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    main()

