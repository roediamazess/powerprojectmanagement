from __future__ import annotations
from sqlalchemy import text
from app.db.session import LaravelSessionLocal

def check_source_roles():
    if LaravelSessionLocal is None:
        print("ERROR: LaravelSessionLocal is None")
        return
    
    src = LaravelSessionLocal()
    try:
        # Check all roles in source
        roles = src.execute(text("SELECT id, name FROM roles")).mappings().all()
        print(f"Source Roles: {roles}")
        
        # Check counts per role
        counts = src.execute(text("""
            SELECT r.name, COUNT(*) 
            FROM model_has_roles mhr 
            JOIN roles r ON r.id = mhr.role_id 
            GROUP BY r.name
        """)).mappings().all()
        print(f"Source Role Counts: {counts}")
        
        # Check model_types
        types = src.execute(text("SELECT DISTINCT model_type FROM model_has_roles")).scalars().all()
        print(f"Source Model Types: {types}")
        
    finally:
        src.close()

if __name__ == "__main__":
    check_source_roles()
