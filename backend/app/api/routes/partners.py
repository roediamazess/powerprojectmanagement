from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.partners import Partner
from app.models.rbac import User
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class ContactSchema(BaseModel):
    id: str | None = None
    role_key: str = "main"
    name: str | None = None
    email: str | None = None
    phone: str | None = None
    is_primary: bool = False


class PartnerCreate(BaseModel):
    cnc_id: str
    name: str
    star: int | None = None
    room: int | None = None
    outlet: str | None = None
    address: str | None = None
    system_live: str | None = None
    area: str | None = None
    sub_area: str | None = None
    status_id: str | None = None
    implementation_type_id: str | None = None
    system_version_id: str | None = None
    partner_type_id: str | None = None
    partner_group_id: str | None = None
    contacts: list[ContactSchema] | None = None
    last_visit: str | None = None
    last_visit_type: str | None = None
    last_project: str | None = None
    last_project_type: str | None = None


@router.get("")
def list_partners(
    q: str | None = None,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.view")),
) -> dict:
    from app.models.lookup import LookupValue

    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": Partner.created_at, "cnc_id": Partner.cnc_id, "name": Partner.name}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid sort")

    where = []
    if q:
        qq = f"%{q.strip()}%"
        where.append(or_(Partner.cnc_id.ilike(qq), Partner.name.ilike(qq)))

    total = db.execute(select(func.count()).select_from(Partner).where(*where)).scalar_one()
    
    # Query with join for status label
    stmt = (
        select(Partner, LookupValue.label.label("status_label"))
        .outerjoin(LookupValue, Partner.status_id == LookupValue.id)
        .where(*where)
        .order_by(col.desc() if desc else col.asc())
        .limit(page_size)
        .offset((page - 1) * page_size)
    )
    
    rows = db.execute(stmt).all()
    data = [
        {
            "id": r.Partner.id,
            "cnc_id": r.Partner.cnc_id,
            "name": r.Partner.name,
            "star": r.Partner.star,
            "room": r.Partner.room,
            "outlet": r.Partner.outlet,
            "area": r.Partner.area,
            "sub_area": r.Partner.sub_area,
            "status_id": r.Partner.status_id,
            "status_label": r.status_label,
        }
        for r in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.get("/{id}")
def get_partner(
    id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.view")),
) -> dict:
    from app.models.lookup import LookupValue
    
    stmt = (
        select(Partner, LookupValue.label.label("status_label"))
        .outerjoin(LookupValue, Partner.status_id == LookupValue.id)
        .where(Partner.id == id)
    )
    r = db.execute(stmt).first()
    if not r:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Partner not found")
    
    row = r.Partner
    return {
        "id": row.id,
        "cnc_id": row.cnc_id,
        "name": row.name,
        "star": row.star,
        "room": row.room,
        "outlet": row.outlet,
        "address": row.address,
        "system_live": row.system_live.isoformat() if row.system_live else None,
        "area": row.area,
        "sub_area": row.sub_area,
        "status_id": row.status_id,
        "status_label": r.status_label,
        "implementation_type_id": row.implementation_type_id,
        "system_version_id": row.system_version_id,
        "partner_type_id": row.partner_type_id,
        "partner_group_id": row.partner_group_id,
        "last_visit": row.last_visit.isoformat() if row.last_visit else None,
        "last_visit_type": row.last_visit_type,
        "last_project": row.last_project,
        "last_project_type": row.last_project_type,
        "contacts": [
            {
                "id": c.id,
                "role_key": c.role_key,
                "name": c.name,
                "email": c.email,
                "phone": c.phone,
                "is_primary": c.is_primary,
            }
            for c in row.contacts
        ],
    }


class PartnerUpdate(BaseModel):
    cnc_id: str | None = None
    name: str | None = None
    star: int | None = None
    room: int | None = None
    outlet: str | None = None
    address: str | None = None
    system_live: str | None = None
    area: str | None = None
    sub_area: str | None = None
    status_id: str | None = None
    implementation_type_id: str | None = None
    system_version_id: str | None = None
    partner_type_id: str | None = None
    partner_group_id: str | None = None
    contacts: list[ContactSchema] | None = None
    last_visit: str | None = None
    last_visit_type: str | None = None
    last_project: str | None = None
    last_project_type: str | None = None


@router.post("")
def create_partner(
    payload: PartnerCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.create")),
) -> dict:
    cnc = payload.cnc_id.strip()
    if not cnc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="cnc_id is required")
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="name is required")

    existing = db.execute(select(Partner.id).where(Partner.cnc_id == cnc)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="cnc_id already exists")

    data = payload.model_dump(exclude_unset=True)
    data["cnc_id"] = cnc
    data["name"] = name

    if "system_live" in data and data["system_live"]:
        from datetime import date

        data["system_live"] = date.fromisoformat(str(data["system_live"]).split("T")[0])
    if "last_visit" in data and data["last_visit"]:
        from datetime import date

        data["last_visit"] = date.fromisoformat(str(data["last_visit"]).split("T")[0])

    contacts_payload = data.pop("contacts", None)

    row = Partner(**data)
    db.add(row)
    db.flush()

    if contacts_payload is not None:
        from app.models.partners import PartnerContact

        for c_data in contacts_payload:
            new_c = PartnerContact(
                partner_id=row.id,
                role_key=c_data.role_key,
                name=c_data.name,
                email=c_data.email,
                phone=c_data.phone,
                is_primary=c_data.is_primary,
            )
            db.add(new_c)

    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="partner",
        entity_id=row.id,
        after={
            "cnc_id": row.cnc_id,
            "name": row.name,
            "star": row.star,
            "room": row.room,
            "outlet": row.outlet,
            "address": row.address,
            "system_live": row.system_live.isoformat() if row.system_live else None,
            "area": row.area,
            "sub_area": row.sub_area,
            "status_id": row.status_id,
            "implementation_type_id": row.implementation_type_id,
            "system_version_id": row.system_version_id,
            "partner_type_id": row.partner_type_id,
            "partner_group_id": row.partner_group_id,
            "last_visit": row.last_visit.isoformat() if row.last_visit else None,
            "last_visit_type": row.last_visit_type,
            "last_project": row.last_project,
            "last_project_type": row.last_project_type,
        },
    )
    db.commit()
    return {"id": row.id}


@router.put("/{id}")
def update_partner(
    id: str,
    payload: PartnerUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.update")),
) -> dict:
    row = db.get(Partner, id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Partner not found")

    before = {
        "cnc_id": row.cnc_id,
        "name": row.name,
        "star": row.star,
        "room": row.room,
        "outlet": row.outlet,
        "address": row.address,
        "system_live": row.system_live.isoformat() if row.system_live else None,
        "area": row.area,
        "sub_area": row.sub_area,
        "status_id": row.status_id,
        "implementation_type_id": row.implementation_type_id,
        "partner_group_id": row.partner_group_id,
        "last_visit": row.last_visit.isoformat() if row.last_visit else None,
        "last_visit_type": row.last_visit_type,
        "last_project": row.last_project,
        "last_project_type": row.last_project_type,
    }

    data = payload.model_dump(exclude_unset=True)
    if "system_live" in data and data["system_live"]:
        from datetime import date
        data["system_live"] = date.fromisoformat(data["system_live"].split('T')[0])
    
    if "last_visit" in data and data["last_visit"]:
        from datetime import date
        data["last_visit"] = date.fromisoformat(data["last_visit"].split('T')[0])
    
    contacts_payload = data.pop("contacts", None)

    for k, v in data.items():
        setattr(row, k, v)
    
    # Sync contacts
    if contacts_payload is not None:
        from app.models.partners import PartnerContact
        
        # Keep track of IDs present in payload
        payload_ids = {c.id for c in contacts_payload if c.id}
        
        # Remove contacts not in payload
        for c in list(row.contacts):
            if c.id not in payload_ids:
                db.delete(c)
        
        # Update or add contacts
        for c_data in contacts_payload:
            if c_data.id:
                # Update existing
                contact = next((c for c in row.contacts if c.id == c_data.id), None)
                if contact:
                    contact.role_key = c_data.role_key
                    contact.name = c_data.name
                    contact.email = c_data.email
                    contact.phone = c_data.phone
                    contact.is_primary = c_data.is_primary
            else:
                # Add new
                new_c = PartnerContact(
                    partner_id=row.id,
                    role_key=c_data.role_key,
                    name=c_data.name,
                    email=c_data.email,
                    phone=c_data.phone,
                    is_primary=c_data.is_primary
                )
                db.add(new_c)

    db.flush()
    after = {
        "cnc_id": row.cnc_id,
        "name": row.name,
        "star": row.star,
        "room": row.room,
        "outlet": row.outlet,
        "address": row.address,
        "system_live": row.system_live.isoformat() if row.system_live else None,
        "area": row.area,
        "sub_area": row.sub_area,
        "status_id": row.status_id,
        "implementation_type_id": row.implementation_type_id,
        "partner_group_id": row.partner_group_id,
        "last_visit": row.last_visit.isoformat() if row.last_visit else None,
        "last_visit_type": row.last_visit_type,
        "last_project": row.last_project,
        "last_project_type": row.last_project_type,
    }

    write_audit_log(
        db,
        actor_user_id=user.id,
        action="update",
        entity_type="partner",
        entity_id=row.id,
        before=before,
        after=after,
    )
    db.commit()
    return {"id": row.id}
