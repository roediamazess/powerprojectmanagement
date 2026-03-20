import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, useForm } from '@inertiajs/react';
import { formatDateDdMmmYy } from '@/utils/date';
import { useEffect, useMemo, useState } from 'react';
import { filterByQuery } from '@/utils/smartSearch';

export default function UserManagementIndex({ users, roles, tiers, statuses, permissionGroups, rolePermissions, canManageAccessControl, currentUserRole, pageSearchQuery }) {
    const [showModal, setShowModal] = useState(false);
    const [showRightsModal, setShowRightsModal] = useState(false);
    const [editingId, setEditingId] = useState(null);

    const editingUser = useMemo(() => {
        if (!editingId) return null;
        return (users ?? []).find((u) => u.id === editingId) ?? null;
    }, [editingId, users]);

    const filteredUsers = useMemo(() => {
        return filterByQuery(users ?? [], pageSearchQuery, (u) => [
            u.id,
            u.name,
            u.full_name,
            u.email,
            u.start_work,
            u.birthday,
            u.tier,
            u.status,
            u.role,
        ]);
    }, [users, pageSearchQuery]);

    const {
        data,
        setData,
        post,
        put,
        processing,
        errors,
        reset,
        clearErrors,
    } = useForm({
        name: '',
        full_name: '',
        email: '',
        password: '',
        start_work: '',
        birthday: '',
        tier: tiers?.[0] ?? '',
        status: statuses?.[0] ?? 'Active',
        role: roles?.[0] ?? 'User',
    });

    const initialRole = (roles ?? [])[0] ?? 'Administrator';
    const [selectedRole, setSelectedRole] = useState(initialRole);

    const {
        data: permData,
        setData: setPermData,
        post: postPerm,
        processing: permProcessing,
    } = useForm({
        role: initialRole,
        permissions: (rolePermissions?.[initialRole] ?? []).slice(),
    });

    useEffect(() => {
        const nextRole = (roles ?? [])[0] ?? 'Administrator';
        setSelectedRole(nextRole);
        setPermData({
            role: nextRole,
            permissions: (rolePermissions?.[nextRole] ?? []).slice(),
        });
    }, [roles]);

    useEffect(() => {
        if (!selectedRole) return;
        setPermData({
            role: selectedRole,
            permissions: (rolePermissions?.[selectedRole] ?? []).slice(),
        });
    }, [selectedRole, rolePermissions]);

    const togglePermission = (key) => {
        const current = new Set(permData.permissions ?? []);
        if (current.has(key)) current.delete(key);
        else current.add(key);
        setPermData('permissions', Array.from(current));
    };

    const saveRolePermissions = (e) => {
        e.preventDefault();
        postPerm(route('tables.user-management.permissions'), {
            preserveScroll: true,
            data: {
                role: permData.role,
                permissions: permData.permissions ?? [],
            },
        });
    };    useEffect(() => {
        if (!showModal && !showRightsModal) return;
        const onKeyDown = (e) => {
            if (e.key !== 'Escape') return;
            if (showModal) closeModal();
            else closeRightsModal();
        };
        window.addEventListener('keydown', onKeyDown);
        return () => window.removeEventListener('keydown', onKeyDown);
    }, [showModal, showRightsModal]);

    const openCreate = () => {
        setEditingId(null);
        clearErrors();
        reset();
        setData({
            name: '',
            full_name: '',
            email: '',
            password: '',
            start_work: '',
            birthday: '',
            tier: tiers?.[0] ?? '',
            status: statuses?.[0] ?? 'Active',
            role: roles?.[0] ?? 'User',
        });
        setShowModal(true);
    };

    const openRightsModal = () => {
        setShowRightsModal(true);
    };

    const closeRightsModal = () => {
        setShowRightsModal(false);
    };

    const openEdit = (user) => {
        setEditingId(user.id);
        clearErrors();
        setData({
            name: user.name ?? '',
            full_name: user.full_name ?? '',
            email: user.email ?? '',
            password: '',
            start_work: user.start_work ?? '',
            birthday: user.birthday ?? '',
            tier: user.tier ?? (tiers?.[0] ?? ''),
            status: user.status ?? (statuses?.[0] ?? 'Active'),
            role: user.role ?? (roles?.[0] ?? 'User'),
        });
        setShowModal(true);
    };

    const closeModal = () => {
        setShowModal(false);
        setEditingId(null);
        clearErrors();
        reset('password');
    };

    const submit = (e) => {
        e.preventDefault();

        if (editingId) {
            put(route('tables.user-management.update', { user: editingId }), {
                preserveScroll: true,
                onSuccess: () => closeModal(),
                onFinish: () => reset('password'),
            });
            return;
        }

        post(route('tables.user-management.store'), {
            preserveScroll: true,
            onSuccess: () => closeModal(),
            onFinish: () => reset('password'),
        });
    };

    return (
        <>
            <Head title="User Management" />

            <div className="row">
                <div className="col-xl-12">
                    <div className="card">
                        <div className="card-header">
                            <div>
                                <h4 className="card-title mb-0">Tables &gt; User Management</h4>
                                <p className="mb-0 text-muted">Total users: {filteredUsers.length}</p>
                            </div>
                            <div className="d-flex gap-2">
                                <button type="button" className="btn btn-primary" onClick={openCreate}>
                                    New
                                </button>
                                <button type="button" className="btn btn-outline-secondary" onClick={openRightsModal}>
                                    User Rights
                                </button>
                            </div>
                        </div>
                        <div className="card-body">
                            <div className="table-responsive">
                                <table className="table table-striped table-responsive-md">
                                    <thead>
                                        <tr>
                                            <th style={{ width: 80 }}>ID</th>
                                            <th>Name</th>
                                            <th>Full Name</th>
                                            <th>Email</th>
                                            <th>Start Work</th>
                                            <th>Birthday</th>
                                            <th>Tier</th>
                                            <th>Status</th>
                                            <th>Role</th>
                                            <th style={{ width: 140 }} />
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {filteredUsers.length === 0 ? (
                                            <tr>
                                                <td colSpan={10} className="text-center text-muted">
                                                    No users found
                                                </td>
                                            </tr>
                                        ) : null}
                                        {filteredUsers.map((u) => (
                                            <tr key={u.id}>
                                                <td>{u.id}</td>
                                                <td>{u.name}</td>
                                                <td>{u.full_name ?? '-'}</td>
                                                <td>{u.email}</td>
                                                <td>{formatDateDdMmmYy(u.start_work)}</td>
                                                <td>{formatDateDdMmmYy(u.birthday)}</td>
                                                <td>{u.tier ?? '-'}</td>
                                                <td>
                                                    <span className={`badge ${u.status === 'Inactive' ? 'bg-secondary' : 'bg-success'}`}>
                                                        {u.status ?? '-'}
                                                    </span>
                                                </td>
                                                <td>{u.role ?? '-'}</td>
                                                <td className="text-end">
                                                    <button type="button" className="btn btn-sm btn-outline-primary" onClick={() => openEdit(u)}>
                                                        Edit
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>


            {showRightsModal ? (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered modal-xl" role="document">
                            <div className="modal-content" id="user-rights-modal">
                                <div className="modal-header">
                                    <div>
                                        <h5 className="modal-title">User Rights</h5>
                                        <small className="text-muted">Atur otoritas Insert/Update/Delete per Roles.</small>
                                    </div>
                                    <button type="button" className="btn-close" onClick={closeRightsModal} />
                                </div>

                                <div className="modal-body">
                                    {canManageAccessControl ? null : (
                                        <div className="alert alert-warning">Kamu tidak punya akses untuk mengubah permission.</div>
                                    )}

                                    <form onSubmit={saveRolePermissions}>
                                        <div className="row align-items-end">
                                            <div className="col-lg-4">
                                                <label className="text-black font-w600 form-label">Role</label>
                                                <select
                                                    className="form-select"
                                                    value={selectedRole}
                                                    disabled={!canManageAccessControl}
                                                    onChange={(e) => setSelectedRole(e.target.value)}
                                                >
                                                    {(roles ?? []).map((r) => (
                                                        <option key={r} value={r}>
                                                            {r}
                                                        </option>
                                                    ))}
                                                </select>
                                            </div>
                                            <div className="col-lg-8 d-flex justify-content-end gap-2">
                                                <button type="submit" className="btn btn-primary" disabled={permProcessing || !canManageAccessControl}>
                                                    Save
                                                </button>
                                            </div>
                                        </div>

                                        <div className="mt-4">
                                            {(permissionGroups ?? []).map((g) => (
                                                <div key={g.key} className="mb-4">
                                                    <h6 className="mb-3">{g.label}</h6>
                                                    <div className="row">
                                                        {(g.items ?? []).map((p) => {
                                                            const checked = (permData.permissions ?? []).includes(p.key);
                                                            return (
                                                                <div key={p.key} className="col-lg-3 col-md-4 col-6">
                                                                    <div className="form-check mb-2">
                                                                        <input
                                                                            className="form-check-input"
                                                                            type="checkbox"
                                                                            id={`perm-${g.key}-${p.key}`}
                                                                            checked={checked}
                                                                            disabled={!canManageAccessControl}
                                                                            onChange={() => togglePermission(p.key)}
                                                                        />
                                                                        <label className="form-check-label" htmlFor={`perm-${g.key}-${p.key}`}>
                                                                            {p.label}
                                                                        </label>
                                                                    </div>
                                                                </div>
                                                            );
                                                        })}
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="modal-backdrop fade show" onClick={closeRightsModal} />
                </>
            ) : null}


            {showModal ? (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered modal-lg" role="document">
                            <div className="modal-content">
                                <div className="modal-header">
                                    <div>
                                        <h5 className="modal-title">{editingId ? 'Edit User' : 'New User'}</h5>
                                        {editingUser?.email ? <small className="text-muted">{editingUser.email}</small> : null}
                                    </div>
                                    <button type="button" className="btn-close" onClick={closeModal} />
                                </div>

                                <form onSubmit={submit}>
                                    <div className="modal-body">
                                        <div className="row">
                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label required">Name</label>
                                                    <input
                                                        type="text"
                                                        className={`form-control ${errors.name ? 'is-invalid' : ''}`}
                                                        value={data.name}
                                                        onChange={(e) => setData('name', e.target.value)}
                                                    />
                                                    {errors.name ? <div className="invalid-feedback">{errors.name}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label">Full Name</label>
                                                    <input
                                                        type="text"
                                                        className={`form-control ${errors.full_name ? 'is-invalid' : ''}`}
                                                        value={data.full_name}
                                                        onChange={(e) => setData('full_name', e.target.value)}
                                                    />
                                                    {errors.full_name ? <div className="invalid-feedback">{errors.full_name}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label required">Email</label>
                                                    <input
                                                        type="email"
                                                        className={`form-control ${errors.email ? 'is-invalid' : ''}`}
                                                        value={data.email}
                                                        onChange={(e) => setData('email', e.target.value)}
                                                    />
                                                    {errors.email ? <div className="invalid-feedback">{errors.email}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label">Password {editingId ? '(optional)' : ''}</label>
                                                    <input
                                                        type="password"
                                                        className={`form-control ${errors.password ? 'is-invalid' : ''}`}
                                                        value={data.password}
                                                        onChange={(e) => setData('password', e.target.value)}
                                                    />
                                                    {errors.password ? <div className="invalid-feedback">{errors.password}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label">Start Work</label>
                                                    <input
                                                        type="date"
                                                        className={`form-control ${errors.start_work ? 'is-invalid' : ''}`}
                                                        value={data.start_work}
                                                        onChange={(e) => setData('start_work', e.target.value)}
                                                    />
                                                    {errors.start_work ? <div className="invalid-feedback">{errors.start_work}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-6">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label">Birthday</label>
                                                    <input
                                                        type="date"
                                                        className={`form-control ${errors.birthday ? 'is-invalid' : ''}`}
                                                        value={data.birthday}
                                                        onChange={(e) => setData('birthday', e.target.value)}
                                                    />
                                                    {errors.birthday ? <div className="invalid-feedback">{errors.birthday}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-4">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label">Tier</label>
                                                    <select
                                                        className={`form-select ${errors.tier ? 'is-invalid' : ''}`}
                                                        value={data.tier}
                                                        onChange={(e) => setData('tier', e.target.value)}
                                                    >
                                                        <option value="">-</option>
                                                        {(tiers ?? []).map((t) => (
                                                            <option key={t} value={t}>
                                                                {t}
                                                            </option>
                                                        ))}
                                                    </select>
                                                    {errors.tier ? <div className="invalid-feedback">{errors.tier}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-4">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label required">Status</label>
                                                    <select
                                                        className={`form-select ${errors.status ? 'is-invalid' : ''}`}
                                                        value={data.status}
                                                        onChange={(e) => setData('status', e.target.value)}
                                                    >
                                                        {(statuses ?? []).map((s) => (
                                                            <option key={s} value={s}>
                                                                {s}
                                                            </option>
                                                        ))}
                                                    </select>
                                                    {errors.status ? <div className="invalid-feedback">{errors.status}</div> : null}
                                                </div>
                                            </div>

                                            <div className="col-lg-4">
                                                <div className="mb-3">
                                                    <label className="text-black font-w600 form-label required">Roles</label>
                                                    <select
                                                        className={`form-select ${errors.role ? 'is-invalid' : ''}`}
                                                        value={data.role}
                                                        onChange={(e) => setData('role', e.target.value)}
                                                    >
                                                        {(roles ?? []).map((r) => (
                                                            <option key={r} value={r}>
                                                                {r}
                                                            </option>
                                                        ))}
                                                    </select>
                                                    {errors.role ? <div className="invalid-feedback">{errors.role}</div> : null}
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="modal-footer">
                                        <button type="submit" className="btn btn-primary" disabled={processing}>
                                            {editingId ? 'Update' : 'Create'}
                                        </button>
                                        <button type="button" className="btn btn-outline-secondary" onClick={closeModal} disabled={processing}>
                                            Cancel
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    <div className="modal-backdrop fade show" onClick={closeModal} />
                </>
            ) : null}
        </>
    );
}

UserManagementIndex.layout = (page) => <AuthenticatedLayout header="User Management">{page}</AuthenticatedLayout>;
