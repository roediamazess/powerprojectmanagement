from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.partners import Partner
from app.models.time_boxing import TimeBoxing
from app.models.health_score import HealthScoreSurvey
from app.models.rbac import User
from app.models.lookup import LookupCategory, LookupValue

router = APIRouter(dependencies=[Depends(csrf_protect)])

@router.get("/partners")
def partners_dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    total_partners = db.execute(select(func.count(Partner.id))).scalar_one()

    def get_breakdown(category_key: str, attr):
        return (
            db.execute(
                select(LookupValue.label, func.count(Partner.id))
                .join(LookupValue, attr == LookupValue.id)
                .join(LookupCategory)
                .where(LookupCategory.key == category_key)
                .group_by(LookupValue.label)
            )
            .all()
        )

    status_bd = get_breakdown("partner.status", Partner.status_id)
    type_bd = get_breakdown("partner.type", Partner.partner_type_id)
    group_bd = get_breakdown("partner.group", Partner.partner_group_id)
    impl_bd = get_breakdown("partner.implementation_type", Partner.implementation_type_id)
    version_bd = get_breakdown("partner.system_version", Partner.system_version_id)

    area_bd = db.execute(select(Partner.area, func.count(Partner.id)).group_by(Partner.area)).all()
    star_bd = db.execute(select(Partner.star, func.count(Partner.id)).group_by(Partner.star)).all()

    # Needs Attention (No visit or > 1 Year ago)
    # Using a simple one year threshold for demo
    from datetime import date, timedelta
    one_year_ago = date.today() - timedelta(days=365)
    needs_attention = db.execute(
        select(Partner)
        .where(or_(Partner.last_visit.is_(None), Partner.last_visit < one_year_ago))
        .limit(10)
    ).scalars().all()

    # Recently Visited
    recently_visited = db.execute(
        select(Partner)
        .where(Partner.last_visit.is_not(None))
        .order_by(Partner.last_visit.desc())
        .limit(10)
    ).scalars().all()

    return {
        "data": {
            "kpi": {
                "total": total_partners,
                "active": sum(c[1] for c in status_bd if c[0].upper() == "ACTIVE"),
                "freeze": sum(c[1] for c in status_bd if c[0].upper() == "FREEZE"),
                "inactive": sum(c[1] for c in status_bd if c[0].upper() == "INACTIVE"),
            },
            "status_breakdown": {c[0]: c[1] for c in status_bd},
            "type_breakdown": [{"label": c[0], "value": c[1]} for c in type_bd],
            "area_breakdown": [{"label": c[0] or "Unknown", "value": c[1]} for c in area_bd],
            "version_breakdown": [{"label": c[0], "value": c[1]} for c in version_bd],
            "star_breakdown": [{"label": f"{c[0]} Star", "value": c[1]} for c in star_bd if c[0] is not None],
            "group_breakdown": [{"label": c[0], "value": c[1]} for c in group_bd],
            "impl_breakdown": [{"label": c[0], "value": c[1]} for c in impl_bd],
            "needs_attention": [
                {"id": p.id, "cnc_id": p.cnc_id, "name": p.name, "area": p.area, "last_visit": p.last_visit.isoformat() if p.last_visit else None}
                for p in needs_attention
            ],
            "recently_visited": [
                {"id": p.id, "cnc_id": p.cnc_id, "name": p.name, "area": p.area, "last_visit": p.last_visit.isoformat() if p.last_visit else None, "last_visit_type": p.last_visit_type}
                for p in recently_visited
            ],
        },
        "meta": None,
        "error": None,
    }

@router.get("/time-boxing")
def time_boxing_dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    total = db.execute(select(func.count(TimeBoxing.id))).scalar_one()
    # Join with LookupValue to get status labels
    by_status = db.execute(
        select(LookupValue.label, func.count(TimeBoxing.id))
        .join(LookupValue, TimeBoxing.status_id == LookupValue.id)
        .group_by(LookupValue.label)
    ).all()

    return {
        "data": {
            "total_records": total,
            "status_distribution": [{"status": c[0], "count": c[1]} for c in by_status]
        },
        "meta": None,
        "error": None
    }

@router.get("/health-score")
def health_score_dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    total_surveys = db.execute(select(func.count(HealthScoreSurvey.id))).scalar_one()
    
    avg_score = db.execute(select(func.avg(HealthScoreSurvey.score_total))).scalar_one_or_none()
    
    by_status = db.execute(
        select(HealthScoreSurvey.status, func.count(HealthScoreSurvey.id))
        .group_by(HealthScoreSurvey.status)
    ).all()

    return {
        "data": {
            "total_surveys": total_surveys,
            "average_score": round(float(avg_score or 0), 2),
            "status_distribution": [{"status": c[0], "count": c[1]} for c in by_status]
        },
        "meta": None,
        "error": None
    }
