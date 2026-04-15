import uuid
import os
from datetime import datetime
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import sessionmaker
from app.db.session import SessionLocal
from app.models.lookup import LookupCategory, LookupValue
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User
from app.models.time_boxing import TimeBoxing

def migrate():
    # 0. Source connection
    base_url = os.getenv("DATABASE_URL")
    if not base_url:
        print("DATABASE_URL not found")
        return
    source_url = base_url.rsplit('/', 1)[0] + '/laravel_migration'
    source_engine = create_engine(source_url)
    SourceSession = sessionmaker(bind=source_engine)
    source_db = SourceSession()
    
    target_db = SessionLocal()
    
    try:
        # Load mappings
        print("Loading mappings...")
        
        # 1. Users (email -> id)
        target_users = target_db.execute(select(User.id, User.email)).all()
        user_email_to_id = {u.email: u.id for u in target_users}
        
        source_users = source_db.execute(text("SELECT id, email FROM users")).all()
        user_map = {}
        for su_id, su_email in source_users:
            if su_email in user_email_to_id:
                user_map[su_id] = user_email_to_id[su_email]
        
        # 2. Partners (cnc_id -> id)
        target_partners = target_db.execute(select(Partner.id, Partner.cnc_id)).all()
        partner_map = {p.cnc_id: p.id for p in target_partners if p.cnc_id}
        
        source_partners = source_db.execute(text("SELECT id, cnc_id FROM partners")).all()
        source_partner_id_to_cnc = {p_id: cnc for p_id, cnc in source_partners}
        
        # 3. Projects (cnc_id -> id)
        target_projects = target_db.execute(select(Project.id, Project.cnc_id)).all()
        project_map = {p.cnc_id: p.id for p in target_projects if p.cnc_id}
        
        source_projects = source_db.execute(text("SELECT id, cnc_id FROM projects")).all()
        # Handle project_id as string/UUID
        source_project_id_to_cnc = {str(p_id): cnc for p_id, cnc in source_projects}
        
        # 4. Lookups
        def get_lookup_map(cat_key):
            res = target_db.execute(
                select(LookupValue.id, LookupValue.label)
                .join(LookupCategory)
                .where(LookupCategory.key == cat_key)
            ).all()
            return {label: vid for vid, label in res}

        type_map = get_lookup_map("time_boxing.type")
        priority_map = get_lookup_map("time_boxing.priority")
        status_map = get_lookup_map("time_boxing.status")

        print(f"User mapping: {len(user_map)} users")
        print(f"Partner mapping: {len(partner_map)} partners")
        print(f"Project mapping: {len(project_map)} projects")

        # 5. Read Time Boxings
        print("Reading source Time Boxings...")
        source_tb = source_db.execute(text("SELECT * FROM time_boxings")).all()
        
        # Clear target table
        target_db.execute(text("DELETE FROM time_boxings"))
        target_db.flush()

        count = 0
        for r in source_tb:
            target_user_id = user_map.get(r.user_id)
            if not target_user_id:
                target_user_id = user_email_to_id.get('admin@powerpro.cloud')
            
            target_partner_id = None
            if r.partner_id:
                cnc = source_partner_id_to_cnc.get(r.partner_id)
                if cnc:
                    target_partner_id = partner_map.get(cnc)
            
            target_project_id = None
            if r.project_id:
                cnc = source_project_id_to_cnc.get(str(r.project_id))
                if cnc:
                    target_project_id = project_map.get(cnc)

            tid = type_map.get(r.type, type_map.get('General'))
            pid = priority_map.get(r.priority, priority_map.get('Normal'))
            sid = status_map.get(r.status, status_map.get('Brain Dump'))

            if not (tid and pid and sid):
                continue

            tb = TimeBoxing(
                id=str(r.id) if r.id else str(uuid.uuid4()),
                no=r.no,
                information_date=r.information_date,
                type_id=tid,
                priority_id=pid,
                status_id=sid,
                user_id=target_user_id,
                user_position=r.user_position,
                partner_id=target_partner_id,
                project_id=target_project_id,
                description=r.description,
                action_solution=r.action_solution,
                due_date=r.due_date,
                completed_at=r.completed_at,
                created_at=r.created_at or datetime.utcnow(),
                updated_at=r.updated_at or datetime.utcnow()
            )
            target_db.add(tb)
            count += 1

        target_db.commit()
        print(f"Successfully migrated {count} Time Boxing records.")

    except Exception as e:
        target_db.rollback()
        print(f"Migration failed: {e}")
        import traceback
        traceback.print_exc()
    finally:
        source_db.close()
        target_db.close()

if __name__ == "__main__":
    migrate()
