from __future__ import annotations

import os

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.health_score import (
    HealthScoreQuestion,
    HealthScoreQuestionOption,
    HealthScoreSection,
    HealthScoreTemplate,
)
from app.models.lookup import LookupCategory, LookupValue
from app.models.rbac import Permission, Role, User, role_permissions, user_roles
from app.security.password import hash_password


def main() -> None:
    db = SessionLocal()
    try:
        _seed_lookup(db)
        _seed_health_score(db)
        _seed_rbac(db)
        _seed_admin(db)
        db.commit()
    finally:
        db.close()


def _get_or_create_category(db, key: str) -> LookupCategory:
    row = db.execute(select(LookupCategory).where(LookupCategory.key == key)).scalar_one_or_none()
    if row:
        return row
    row = LookupCategory(key=key)
    db.add(row)
    db.flush()
    return row


def _get_or_create_value(db, category: LookupCategory, value: str, label: str, sort_order: int = 0) -> LookupValue:
    row = (
        db.execute(select(LookupValue).where(LookupValue.category_id == category.id).where(LookupValue.value == value))
        .scalar_one_or_none()
    )
    if row:
        return row
    row = LookupValue(category_id=category.id, value=value, label=label, sort_order=sort_order)
    db.add(row)
    db.flush()
    return row


def _seed_lookup(db) -> None:
    batch_status = _get_or_create_category(db, "arrangement.batch_status")
    _get_or_create_value(db, batch_status, "OPEN", "Open", 10)
    _get_or_create_value(db, batch_status, "APPROVED", "Approved", 20)
    _get_or_create_value(db, batch_status, "CLOSED", "Closed", 30)

    schedule_status = _get_or_create_category(db, "arrangement.schedule_status")
    _get_or_create_value(db, schedule_status, "OPEN", "Open", 10)
    _get_or_create_value(db, schedule_status, "CLOSED", "Closed", 20)

    pickup_status = _get_or_create_category(db, "arrangement.pickup_status")
    _get_or_create_value(db, pickup_status, "PICKED", "Picked", 10)
    _get_or_create_value(db, pickup_status, "APPROVED", "Approved", 20)
    _get_or_create_value(db, pickup_status, "CANCELLED", "Cancelled", 30)

    schedule_type = _get_or_create_category(db, "arrangement.schedule_type")
    _get_or_create_value(db, schedule_type, "IMPLEMENTATION", "Implementation", 10)
    _get_or_create_value(db, schedule_type, "VISIT", "Visit", 20)
    _get_or_create_value(db, schedule_type, "TRAINING", "Training", 30)
    _get_or_create_value(db, schedule_type, "SUPPORT", "Support", 40)
    _get_or_create_value(db, schedule_type, "OTHER", "Other", 50)

    jobsheet_code = _get_or_create_category(db, "arrangement.jobsheet_code")
    _get_or_create_value(db, jobsheet_code, "WFO", "WFO", 10)
    _get_or_create_value(db, jobsheet_code, "WFH", "WFH", 20)
    _get_or_create_value(db, jobsheet_code, "OFF", "OFF", 30)
    _get_or_create_value(db, jobsheet_code, "SICK", "SICK", 40)
    _get_or_create_value(db, jobsheet_code, "LEAVE", "LEAVE", 50)
    _get_or_create_value(db, jobsheet_code, "OTHER", "OTHER", 60)

    tb_type = _get_or_create_category(db, "time_boxing.type")
    _get_or_create_value(db, tb_type, "INCIDENT", "Incident", 10)
    _get_or_create_value(db, tb_type, "REQUEST", "Request", 20)
    _get_or_create_value(db, tb_type, "TASK", "Task", 30)

    tb_priority = _get_or_create_category(db, "time_boxing.priority")
    _get_or_create_value(db, tb_priority, "LOW", "Low", 10)
    _get_or_create_value(db, tb_priority, "MEDIUM", "Medium", 20)
    _get_or_create_value(db, tb_priority, "HIGH", "High", 30)
    _get_or_create_value(db, tb_priority, "URGENT", "Urgent", 40)

    tb_status = _get_or_create_category(db, "time_boxing.status")
    _get_or_create_value(db, tb_status, "OPEN", "Open", 10)
    _get_or_create_value(db, tb_status, "IN_PROGRESS", "In Progress", 20)
    _get_or_create_value(db, tb_status, "DONE", "Done", 30)

    partner_status = _get_or_create_category(db, "partner.status")
    _get_or_create_value(db, partner_status, "ACTIVE", "Active", 10)
    _get_or_create_value(db, partner_status, "INACTIVE", "Inactive", 20)

    _get_or_create_category(db, "partner.implementation_type")
    _get_or_create_category(db, "partner.system_version")
    _get_or_create_category(db, "partner.type")
    _get_or_create_category(db, "partner.group")
    _get_or_create_category(db, "partner.area")
    _get_or_create_category(db, "partner.sub_area")

    _get_or_create_category(db, "project.type")

    project_status = _get_or_create_category(db, "project.status")
    _get_or_create_value(db, project_status, "OPEN", "Open", 10)
    _get_or_create_value(db, project_status, "IN_PROGRESS", "In Progress", 20)
    _get_or_create_value(db, project_status, "DONE", "Done", 30)


def _seed_health_score(db) -> None:
    template = db.execute(select(HealthScoreTemplate).where(HealthScoreTemplate.name == "Compliance Template")).scalar_one_or_none()
    if not template:
        template = HealthScoreTemplate(name="Compliance Template", status="Active", version=1)
        db.add(template)
        db.flush()

    sections_spec: list[tuple[str, float, int]] = [
        ("Operations", 0.5, 10),
        ("Delivery", 0.5, 20),
    ]
    sections: dict[str, HealthScoreSection] = {}
    for name, weight, order in sections_spec:
        s = (
            db.execute(
                select(HealthScoreSection).where(HealthScoreSection.template_id == template.id).where(HealthScoreSection.name == name)
            )
            .scalar_one_or_none()
        )
        if not s:
            s = HealthScoreSection(template_id=template.id, name=name, weight=weight, sort_order=order)
            db.add(s)
            db.flush()
        sections[name] = s

    questions_spec: list[tuple[str, str, str, str | None, float, int, list[tuple[str, float, int]]]] = [
        (
            "Operations",
            "SLA response met?",
            "Support",
            "single_choice",
            1.0,
            10,
            [("Yes", 100, 10), ("Partially", 50, 20), ("No", 0, 30)],
        ),
        (
            "Operations",
            "System stability (incidents) under control?",
            "System",
            "single_choice",
            1.0,
            20,
            [("Stable", 100, 10), ("Minor issues", 70, 20), ("Frequent issues", 30, 30)],
        ),
        (
            "Delivery",
            "Milestones on track?",
            "Project",
            "single_choice",
            1.0,
            10,
            [("On track", 100, 10), ("Slight delay", 70, 20), ("Delayed", 30, 30)],
        ),
        (
            "Delivery",
            "Stakeholder satisfaction (latest quarter)",
            "Stakeholder",
            "single_choice",
            1.0,
            20,
            [("High", 100, 10), ("Medium", 70, 20), ("Low", 30, 30)],
        ),
    ]

    for section_name, question_text, module, answer_type, weight, order, options in questions_spec:
        section = sections[section_name]
        q = (
            db.execute(
                select(HealthScoreQuestion)
                .where(HealthScoreQuestion.section_id == section.id)
                .where(HealthScoreQuestion.question_text == question_text)
            )
            .scalar_one_or_none()
        )
        if not q:
            q = HealthScoreQuestion(
                section_id=section.id,
                module=module,
                question_text=question_text,
                answer_type=answer_type,
                scoring_rule=None,
                weight=weight,
                sort_order=order,
                required=True,
            )
            db.add(q)
            db.flush()

        for label, score_value, sort_order in options:
            opt = (
                db.execute(
                    select(HealthScoreQuestionOption)
                    .where(HealthScoreQuestionOption.question_id == q.id)
                    .where(HealthScoreQuestionOption.label == label)
                )
                .scalar_one_or_none()
            )
            if not opt:
                db.add(HealthScoreQuestionOption(question_id=q.id, label=label, score_value=score_value, sort_order=sort_order))


def _get_or_create_role(db, name: str) -> Role:
    row = db.execute(select(Role).where(Role.name == name)).scalar_one_or_none()
    if row:
        return row
    row = Role(name=name)
    db.add(row)
    db.flush()
    return row


def _get_or_create_permission(db, key: str, description: str | None = None) -> Permission:
    row = db.execute(select(Permission).where(Permission.key == key)).scalar_one_or_none()
    if row:
        return row
    row = Permission(key=key, description=description)
    db.add(row)
    db.flush()
    return row


def _assign_permission(db, role: Role, perm: Permission) -> None:
    exists = db.execute(
        select(role_permissions.c.permission_id)
        .where(role_permissions.c.role_id == role.id)
        .where(role_permissions.c.permission_id == perm.id)
    ).scalar_one_or_none()
    if exists:
        return
    db.execute(role_permissions.insert().values(role_id=role.id, permission_id=perm.id))


def _assign_role(db, user: User, role: Role) -> None:
    exists = db.execute(
        select(user_roles.c.role_id).where(user_roles.c.user_id == user.id).where(user_roles.c.role_id == role.id)
    ).scalar_one_or_none()
    if exists:
        return
    db.execute(user_roles.insert().values(user_id=user.id, role_id=role.id))


def _seed_rbac(db) -> None:
    administrator = _get_or_create_role(db, "Administrator")
    admin_officer = _get_or_create_role(db, "Admin Officer")
    _get_or_create_role(db, "Management")

    approve = _get_or_create_permission(db, "arrangements.pickup.approve", "Approve arrangement pickup")
    override_cancel = _get_or_create_permission(db, "arrangements.pickup.override_cancel", "Override cancel approved pickup")

    # User & Role Management
    u_view = _get_or_create_permission(db, "users.view", "View users list")
    u_create = _get_or_create_permission(db, "users.create", "Create new users")
    u_edit = _get_or_create_permission(db, "users.edit", "Edit existing users")
    u_delete = _get_or_create_permission(db, "users.delete", "Delete users")
    r_view = _get_or_create_permission(db, "roles.view", "View roles and permissions")
    r_edit = _get_or_create_permission(db, "roles.edit", "Manage roles and permissions")

    _assign_permission(db, administrator, approve)
    _assign_permission(db, administrator, override_cancel)
    _assign_permission(db, administrator, u_view)
    _assign_permission(db, administrator, u_create)
    _assign_permission(db, administrator, u_edit)
    _assign_permission(db, administrator, u_delete)
    _assign_permission(db, administrator, r_view)
    _assign_permission(db, administrator, r_edit)

    _assign_permission(db, admin_officer, approve)


def _seed_admin(db) -> None:
    email = os.getenv("ADMIN_EMAIL")
    password = os.getenv("ADMIN_PASSWORD")
    if not email or not password:
        return
    existing = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    administrator = db.execute(select(Role).where(Role.name == "Administrator")).scalar_one()
    if existing:
        # Don't overwrite existing user's name or password if they already exist
        # This is important for migrated users from Laravel
        existing.is_active = True
        _assign_role(db, existing, administrator)
        return

    user = User(email=email, name="Administrator", password_hash=hash_password(password), is_active=True)
    db.add(user)
    db.flush()
    _assign_role(db, user, administrator)


if __name__ == "__main__":
    main()
