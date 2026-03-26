import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link, useForm, usePage } from '@inertiajs/react';
import { useEffect, useMemo, useState } from 'react';
import { filterByQuery } from '@/utils/smartSearch';

export default function PartnerSetupIndex({ category, categories, options, areas, pageSearchQuery }) {
    const pageErrors = usePage().props.errors ?? {};
    const [showModal, setShowModal] = useState(false);
    const [editingId, setEditingId] = useState(null);

    const editingOption = useMemo(() => {
        if (!editingId) return null;
        return (options ?? []).find((o) => o.id === editingId) ?? null;
    }, [editingId, options]);

    const filteredOptions = useMemo(() => {
        return filterByQuery(options ?? [], pageSearchQuery, (o) => [o.id, o.name, o.category, o.parent_name]);
    }, [options, pageSearchQuery]);

    const { data, setData, post, put, delete: destroy, processing, errors, reset, clearErrors } = useForm({
        category: category ?? 'implementation_type',
        parent_name: '',
        name: '',
        status: 'Active',
    });

    useEffect(() => {
        setData('category', category ?? 'implementation_type');
    }, [category]);

    useEffect(() => {
        if (!showModal) return;
        const onKeyDown = (e) => {
            if (e.key === 'Escape') closeModal();
        };
        window.addEventListener('keydown', onKeyDown);
        return () => window.removeEventListener('keydown', onKeyDown);
    }, [showModal]);

    const openCreate = () => {
        setEditingId(null);
        clearErrors();
        reset();
        setData({ category: category ?? 'implementation_type', parent_name: '', name: '', status: 'Active' });
        setShowModal(true);
    };

    const openEdit = (o) => {
        setEditingId(o.id);
        clearErrors();
        setData({ category: o.category, parent_name: o.parent_name ?? '', name: o.name, status: o.status ?? 'Active' });
        setShowModal(true);
    };

    const closeModal = () => {
        setShowModal(false);
        setEditingId(null);
        clearErrors();
    };

    const submit = (e) => {
        e.preventDefault();
        if (editingId) {
            put(route('tables.partner-setup.update', { option: editingId }), {
                preserveScroll: true,
                onSuccess: () => closeModal(),
            });
            return;
        }

        post(route('tables.partner-setup.store'), {
            preserveScroll: true,
            onSuccess: () => closeModal(),
        });
    };

    const doDelete = async (o) => {
        const label = o.name;

        if (typeof window !== 'undefined' && window.Swal?.fire) {
            const result = await window.Swal.fire({
                title: 'Hapus option?',
                text: `Option: ${label}`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: 'Ya, hapus',
                cancelButtonText: 'Batal',
                confirmButtonColor: '#dc3545',
                cancelButtonColor: '#6c757d',
                reverseButtons: true,
                focusCancel: true,
            });
            if (!result.isConfirmed) return;
        } else {
            if (!window.confirm(`Delete option: ${label}?`)) return;
        }

        destroy(route('tables.partner-setup.destroy', { option: o.id }), {
            preserveScroll: true,
        });
    };

    const categoryLabel = (key) => (categories ?? []).find((c) => c.key === key)?.label ?? key;

    return (
        <>
            <Head title="Partner Setup" />

            <div className="row">
                <div className="col-xl-12">
                    <div className="card">
                        <div className="card-header">
                            <div>
                                <h4 className="card-title mb-0">Tables &gt; Partner Setup</h4>
                                <p className="mb-0 text-muted">Category: {categoryLabel(category)}</p>
                            </div>
                            <div className="d-flex gap-2">
                                <button type="button" className="btn btn-primary" onClick={openCreate}>
                                    New
                                </button>
                            </div>
                        </div>

                        <div className="card-body">
                            {pageErrors.delete ? (
                                <div className="alert alert-warning">{pageErrors.delete}</div>
                            ) : null}
                            <div className="d-flex flex-wrap gap-2 mb-3">
                                {(categories ?? []).map((c) => (
                                    <Link
                                        key={c.key}
                                        className={`btn btn-sm ${c.key === category ? 'btn-primary' : 'btn-outline-primary'}`}
                                        href={route('tables.partner-setup.index', { category: c.key })}
                                        preserveScroll
                                    >
                                        {c.label}
                                    </Link>
                                ))}
                            </div>

                            <div className="table-responsive">
                                <table className="table table-striped table-responsive-md">
                                    <thead>
                                        <tr>
                                            <th style={{ width: 80 }}>ID</th>
                                            {category === 'sub_area' ? <th style={{ width: 220 }}>Area</th> : null}
                                            <th>Name</th>
                                            <th style={{ width: 120 }}>Status</th>
                                            <th style={{ width: 160 }} />
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {filteredOptions.length === 0 ? (
                                            <tr>
                                                <td colSpan={category === "sub_area" ? 5 : 4} className="text-center text-muted">
                                                    No options found
                                                </td>
                                            </tr>
                                        ) : null}
                                        {filteredOptions.map((o) => (
                                            <tr key={o.id}>
                                                <td>{o.id}</td>
                                                {category === "sub_area" ? <td>{o.parent_name ?? "-"}</td> : null}
                                                <td>{o.name}</td>
                                                <td>
                                                    <span className={`badge ${o.status === 'Inactive' ? 'bg-secondary' : 'bg-success'}`}>{o.status ?? 'Active'}</span>
                                                </td>
                                                <td className="text-end">
                                                    <div className="d-flex gap-2 justify-content-end">
                                                        <button type="button" className="btn btn-sm btn-outline-primary" onClick={() => openEdit(o)}>
                                                            Edit
                                                        </button>
                                                        <button type="button" className="btn btn-sm btn-outline-danger" onClick={() => doDelete(o)} disabled={processing || o.in_use}>
                                                            Delete
                                                        </button>
                                                    </div>
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

            {showModal ? (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered" role="document">
                            <div className="modal-content">
                                <div className="modal-header">
                                    <h5 className="modal-title">{editingId ? 'Edit Option' : 'New Option'}</h5>
                                    <button type="button" className="btn-close" onClick={closeModal} />
                                </div>

                                <form onSubmit={submit}>
                                    <div className="modal-body">
                                        <div className="mb-3">
                                            <label className="text-black font-w600 form-label required">Category</label>
                                            <select
                                                className={`form-select ${errors.category ? 'is-invalid' : ''}`}
                                                value={data.category}
                                                onChange={(e) => setData('category', e.target.value)}
                                            >
                                                {(categories ?? []).map((c) => (
                                                    <option key={c.key} value={c.key}>
                                                        {c.label}
                                                    </option>
                                                ))}
                                            </select>
                                            {errors.category ? <div className="invalid-feedback">{errors.category}</div> : null}
                                        </div>

                                                                                {data.category === 'sub_area' ? (
                                            <div className="mb-3">
                                                <label className="text-black font-w600 form-label required">Area</label>
                                                <select
                                                    className={`form-select ${errors.parent_name ? 'is-invalid' : ''}`}
                                                    value={data.parent_name}
                                                    onChange={(e) => setData('parent_name', e.target.value)}
                                                >
                                                    <option value="">-</option>
                                                    {(areas ?? []).map((a) => (
                                                        <option key={a} value={a}>
                                                            {a}
                                                        </option>
                                                    ))}
                                                </select>
                                                {errors.parent_name ? <div className="invalid-feedback">{errors.parent_name}</div> : null}
                                            </div>
                                        ) : null}

<div className="mb-3">
                                            <label className="text-black font-w600 form-label required">Name</label>
                                            <input
                                                className={`form-control ${errors.name ? 'is-invalid' : ''}`}
                                                value={data.name}
                                                onChange={(e) => setData('name', e.target.value)}
                                            />
                                            {errors.name ? <div className="invalid-feedback">{errors.name}</div> : null}
                                        </div>

                                        <div className="mb-3">
                                            <label className="text-black font-w600 form-label required">Status</label>
                                            <select
                                                className={`form-select ${errors.status ? 'is-invalid' : ''}`}
                                                value={data.status}
                                                onChange={(e) => setData('status', e.target.value)}
                                            >
                                                <option value="Active">Active</option>
                                                <option value="Inactive">Inactive</option>
                                            </select>
                                            {errors.status ? <div className="invalid-feedback">{errors.status}</div> : null}
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

PartnerSetupIndex.layout = (page) => <AuthenticatedLayout header="Partner Setup">{page}</AuthenticatedLayout>;
