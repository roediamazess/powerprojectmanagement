from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.partners import Partner
from app.models.projects import Project
from app.models.time_boxing import TimeBoxing
from app.models.health_score import Survey
from app.models.rbac import User

router = APIRouter(dependencies=[Depends(csrf_protect)])

@router.get("/partners")
def partners_dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    total_partners = db.execute(select(func.count(Partner.id))).scalar_one()
    by_category = db.execute(
        select(Partner.partner_category_value, func.count(Partner.id))
        .group_by(Partner.partner_category_value)
    ).all()
    
    total_projects = db.execute(select(func.count(Project.id))).scalar_one()
    
    return {
        "data": {
            "total_partners": total_partners,
            "total_projects": total_projects,
            "categories": [{"name": c[0] or "Uncategorized", "count": c[1]} for c in by_category]
        },
        "meta": None,
        "error": None
    }

@router.get("/time-boxing")
def time_boxing_dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    total = db.execute(select(func.count(TimeBoxing.id))).scalar_one()
    by_status = db.execute(
        select(TimeBoxing.status, func.count(TimeBoxing.id))
        .group_by(TimeBoxing.status)
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
    total_surveys = db.execute(select(func.count(Survey.id))).scalar_one()
    
    avg_score = db.execute(select(func.avg(Survey.health_score))).scalar_one_or_none()
    
    by_status = db.execute(
        select(Survey.status, func.count(Survey.id))
        .group_by(Survey.status)
    ).all()

    return {
        "data": {
            "total_surveys": total_surveys,
            "average_score": round(float(avg_score), 2) if avg_score else 0,
            "status_distribution": [{"status": c[0], "count": c[1]} for c in by_status]
        },
        "meta": None,
        "error": None
    }
