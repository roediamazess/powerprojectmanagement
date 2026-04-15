import uuid
from sqlalchemy import select, delete
from app.db.session import SessionLocal
from app.models.lookup import LookupCategory, LookupValue

def fix_lookups():
    db = SessionLocal()
    try:
        # 1. Fix Statuses
        cat_status = db.execute(select(LookupCategory).where(LookupCategory.key == "time_boxing.status")).scalar_one_or_none()
        if not cat_status:
            cat_status = LookupCategory(id=str(uuid.uuid4()), key="time_boxing.status")
            db.add(cat_status)
            db.flush()
        
        # Clear existing values for this category to ensure consistency
        db.execute(delete(LookupValue).where(LookupValue.category_id == cat_status.id))
        
        statuses = [
            ("Brain Dump", "Brain Dump", 0),
            ("Priority List", "Priority List", 1),
            ("Time Boxing", "Time Boxing", 2),
            ("Completed", "Completed", 3),
        ]
        for val, label, order in statuses:
            db.add(LookupValue(
                id=str(uuid.uuid4()),
                category_id=cat_status.id,
                value=val,
                label=label,
                sort_order=order,
                is_active=True
            ))

        # 2. Fix Priorities
        cat_prio = db.execute(select(LookupCategory).where(LookupCategory.key == "time_boxing.priority")).scalar_one_or_none()
        if not cat_prio:
            cat_prio = LookupCategory(id=str(uuid.uuid4()), key="time_boxing.priority")
            db.add(cat_prio)
            db.flush()
        
        db.execute(delete(LookupValue).where(LookupValue.category_id == cat_prio.id))
        
        priorities = [
            ("Normal", "Normal", 0),
            ("High", "High", 1),
            ("Urgent", "Urgent", 2),
        ]
        for val, label, order in priorities:
            db.add(LookupValue(
                id=str(uuid.uuid4()),
                category_id=cat_prio.id,
                value=val,
                label=label,
                sort_order=order,
                is_active=True
            ))

        db.commit()
        print("Time Boxing lookups fixed successfully.")
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    fix_lookups()
