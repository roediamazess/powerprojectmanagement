import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, useForm } from '@inertiajs/react';
import { formatDateDdMmmYy, formatPickupWindowWib } from '@/utils/date';
import { useMemo, useState } from 'react';
import ArrangementTabs from './Partials/ArrangementTabs';

export default function Batches({ batches, publishSchedules, defaultPickupWindow, defaultRequirementPoints }) {
    const [showModal, setShowModal] = useState(false);
    const [editingId, setEditingId] = useState(null);
    const { data, setData, post, put, processing, errors, clearErrors } = useForm({
        name: '',
        min_requirement_points: 0,
        max_requirement_points: 0,
        pickup_start_at: '',
        pickup_end_at: '',
        schedule_ids: [],
    });
    const { post: postAction, processing: actionProcessing } = useForm();

    const publishList = useMemo(() => {
        if (Array.isArray(publishSchedules)) return publishSchedules;
        if (typeof publishSchedules === 'object' && publishSchedules !== null) {
            if (publishSchedules.data && Array.isArray(publishSchedules.data)) return publishSchedules.data;
            return Object.values(publishSchedules);
        }
        return [];
    }, [publishSchedules]);

    const toLocalInputValue = (value) => {
        if (!value) return '';
        const raw = String(value).trim();
        const normalized = raw.replace(/([+-]\d{2}):(\d{2})$/, '$1$2').replace(/\+00:00$/, 'Z');
        const d = new Date(normalized);
        if (Number.isNaN(d.getTime())) return '';
        const parts = new Intl.DateTimeFormat('en-US', {
            timeZone: 'Asia/Jakarta',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            hour12: false,
        }).formatToParts(d);
        const byType = Object.fromEntries(parts.map((p) => [p.type, p.value]));
        const yyyy = byType.year ?? '';
        const mm = byType.month ?? '';
        const dd = byType.day ?? '';
        const hh = byType.hour ?? '';
        const mi = byType.minute ?? '';
        if (!yyyy || !mm || !dd || !hh || !mi) return '';
        return `${yyyy}-${mm}-${dd}T${hh}:${mi}`;
    };

    const openNew = () => {
        setEditingId(null);
        clearErrors();
        setData({
            name: '',
            min_requirement_points: defaultRequirementPoints?.min ?? 0,
            max_requirement_points: defaultRequirementPoints?.max ?? 0,
            pickup_start_at: defaultPickupWindow?.start ?? '',
            pickup_end_at: defaultPickupWindow?.end ?? '',
            schedule_ids: [],
        });
        setShowModal(true);
    };

    const openEdit = (b) => {
        if ((b.status ?? 'Open') === 'Approved') return;
        setEditingId(b.id);
        clearErrors();
        setData({
            name: b.name ?? '',
            min_requirement_points: b.min_requirement_points ?? 0,
            max_requirement_points: b.max_requirement_points || b.requirement_points || 0,
            pickup_start_at: toLocalInputValue(b.pickup_start_at),
            pickup_end_at: toLocalInputValue(b.pickup_end_at),
            schedule_ids: publishList.filter((s) => s.batch_id === b.id).map((s) => s.id),
        });
        setShowModal(true);
    };

    const closeModal = () => {
        setShowModal(false);
        setEditingId(null);
        clearErrors();
    };

    const toggleSchedule = (id) => {
        setData('schedule_ids', data.schedule_ids.includes(id) ? data.schedule_ids.filter((x) => x !== id) : [...data.schedule_ids, id]);
    };

    const submit = (e) => {
        e.preventDefault();
        const payload = {
            ...data,
            min_requirement_points: Number(data.min_requirement_points),
            max_requirement_points: Number(data.max_requirement_points),
        };

        if (editingId) {
            put(route('arrangements.batches.update', { batch: editingId }, false), { preserveScroll: true, data: payload, onSuccess: closeModal });
            return;
        }

        post(route('arrangements.batches.store', {}, false), { preserveScroll: true, data: payload, onSuccess: closeModal });
    };

    const getStatusMatch = (status) => {
        if (!status) return false;
        const s = String(status).toLowerCase();
        return s === 'open' || s === 'publish';
    };

    const filteredList = useMemo(() => {
        return publishList.filter((s) => getStatusMatch(s.status) || (editingId && s.batch_id === editingId));
    }, [publishList, editingId]);

    const approveBatch = (batchId) => {
        postAction(route('arrangements.batches.approve', { batch: batchId }, false), { preserveScroll: true });
    };

    const reopenBatch = (batchId) => {
        postAction(route('arrangements.batches.reopen', { batch: batchId }, false), { preserveScroll: true });
    };

    return (
        <AuthenticatedLayout header={<h2 className="text-xl font-semibold leading-tight text-gray-800">Arrangement — Batches</h2>}>
            <Head title="Arrangement Batches" />

            <div className="row">
                <div className="col-12">
                    <div className="card">
                        <div className="card-header d-flex flex-wrap align-items-center justify-content-between pb-2">
                            <div className="d-flex align-items-center flex-grow-1">
                                <ArrangementTabs isManager />
                            </div>
                            <div className="d-flex align-items-center gap-3">
                                <h4 className="card-title mb-0 d-none d-sm-block">Batches</h4>
                                <button type="button" className="btn btn-primary" onClick={openNew}>
                                    New
                                </button>
                            </div>
                        </div>
                        <div className="card-body">
                            <div className="table-responsive">
                                <table className="table table-responsive-md mb-0">
                                    <thead>
                                        <tr>
                                            <th>Name</th>
                                            <th>Status</th>
                                            <th className="text-end">Min Points</th>
                                            <th className="text-end">Max Points</th>
                                            <th>Pick Up Window (WIB)</th>
                                            <th>Schedules</th>
                                            <th className="text-end">Action</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {(batches?.data ?? []).map((b) => (
                                            <tr key={b.id}>
                                                <td className="fw-semibold">{b.name}</td>
                                                <td>
                                                    <span className={`badge ${(b.status ?? 'Open') === 'Approved' ? 'bg-success' : 'bg-info'}`}>
                                                        {b.status ?? 'Open'}
                                                    </span>
                                                </td>
                                                <td className="text-end">{b.min_requirement_points ?? 0}</td>
                                                <td className="text-end">{b.max_requirement_points || b.requirement_points || 0}</td>
                                                <td className="white-space-nowrap">
                                                    {b.pickup_start_at && b.pickup_end_at ? (
                                                        formatPickupWindowWib(b.pickup_start_at, b.pickup_end_at)
                                                    ) : (
                                                        <span className="text-muted">-</span>
                                                    )}
                                                </td>
                                                <td>{b.schedules_count ?? 0}</td>
                                                <td className="text-end">
                                                    {(b.status ?? 'Open') === 'Approved' ? (
                                                        <button
                                                            type="button"
                                                            className="btn btn-sm btn-outline-warning"
                                                            onClick={() => reopenBatch(b.id)}
                                                            disabled={actionProcessing}
                                                        >
                                                            Reopen
                                                        </button>
                                                    ) : (
                                                        <div className="d-inline-flex gap-2">
                                                            <button
                                                                type="button"
                                                                className="btn btn-sm btn-outline-primary"
                                                                onClick={() => openEdit(b)}
                                                                disabled={processing || actionProcessing}
                                                            >
                                                                Edit
                                                            </button>
                                                            <button
                                                                type="button"
                                                                className="btn btn-sm btn-success"
                                                                onClick={() => approveBatch(b.id)}
                                                                disabled={actionProcessing}
                                                            >
                                                                Approve
                                                            </button>
                                                        </div>
                                                    )}
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>

                            <hr className="my-4" />

                            <h4 className="card-title mb-3">
                                Available & Batched Schedules ({publishList.length} total)
                            </h4>
                            <div className="table-responsive">
                                <table className="table table-responsive-md mb-0">
                                    <thead>
                                        <tr>
                                            <th>Schedule</th>
                                            <th>Range</th>
                                            <th>Count</th>
                                            <th>Status</th>
                                            <th>Batch ID</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {publishList.length ? (
                                            publishList.map((s) => (
                                                <tr key={s.id}>
                                                    <td>{s.schedule_type}</td>
                                                    <td>
                                                        {formatDateDdMmmYy(s.start_date)} – {formatDateDdMmmYy(s.end_date)}
                                                    </td>
                                                    <td>{s.count}</td>
                                                    <td>
                                                        <span className={`badge ${getStatusMatch(s.status) ? 'bg-primary' : 'bg-info'}`}>{s.status}</span>
                                                    </td>
                                                    <td>{s.batch_id ? s.batch_id.slice(0, 8) + '...' : '-'}</td>
                                                </tr>
                                            ))
                                        ) : (
                                            <tr>
                                                <td colSpan={7} className="text-center text-muted py-4">
                                                    No publish schedules found.
                                                </td>
                                            </tr>
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {showModal && (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered modal-lg" role="document">
                            <div className="modal-content">
                                <div className="modal-header">
                                    <h5 className="modal-title">{editingId ? 'Edit Batch' : 'New Batch'}</h5>
                                    <button type="button" className="btn-close" onClick={closeModal} aria-label="Close" />
                                </div>
                                <form onSubmit={submit}>
                                    <div className="modal-body">
                                        <div className="row g-3">
                                            <div className="col-md-6">
                                                <label className="form-label">Batch Name</label>
                                                <input type="text" className="form-control" value={data.name} onChange={(e) => setData('name', e.target.value)} />
                                                {errors.name && <div className="text-danger fs-12 mt-1">{errors.name}</div>}
                                            </div>
                                            <div className="col-md-3">
                                                <label className="form-label">Min Requirement Points</label>
                                                <input
                                                    type="number"
                                                    min={0}
                                                    className="form-control"
                                                    value={data.min_requirement_points}
                                                    onChange={(e) => setData('min_requirement_points', e.target.value)}
                                                />
                                                {errors.min_requirement_points && <div className="text-danger fs-12 mt-1">{errors.min_requirement_points}</div>}
                                            </div>
                                            <div className="col-md-3">
                                                <label className="form-label">Max Requirement Points</label>
                                                <input
                                                    type="number"
                                                    min={0}
                                                    className="form-control"
                                                    value={data.max_requirement_points}
                                                    onChange={(e) => setData('max_requirement_points', e.target.value)}
                                                />
                                                {errors.max_requirement_points && <div className="text-danger fs-12 mt-1">{errors.max_requirement_points}</div>}
                                            </div>
                                            <div className="col-md-6">
                                                <label className="form-label">Validation Pick Up Start (WIB)</label>
                                                <input
                                                    type="datetime-local"
                                                    className="form-control"
                                                    value={data.pickup_start_at}
                                                    onChange={(e) => setData('pickup_start_at', e.target.value)}
                                                />
                                                <div className="text-muted fs-12 mt-1">Input dianggap WIB (UTC+7).</div>
                                                {errors.pickup_start_at && <div className="text-danger fs-12 mt-1">{errors.pickup_start_at}</div>}
                                            </div>
                                            <div className="col-md-6">
                                                <label className="form-label">Validation Pick Up End (WIB)</label>
                                                <input
                                                    type="datetime-local"
                                                    className="form-control"
                                                    value={data.pickup_end_at}
                                                    onChange={(e) => setData('pickup_end_at', e.target.value)}
                                                />
                                                <div className="text-muted fs-12 mt-1">Input dianggap WIB (UTC+7).</div>
                                                {errors.pickup_end_at && <div className="text-danger fs-12 mt-1">{errors.pickup_end_at}</div>}
                                            </div>
                                            <div className="col-12">
                                                <label className="form-label">
                                                    Available Schedules (Open / Publish) - {filteredList.length} filtered
                                                </label>
                                                <div className="list-group" style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                                    {filteredList.map((s) => {
                                                            const checked = data.schedule_ids.includes(s.id);
                                                            return (
                                                                <label key={s.id} className="list-group-item d-flex align-items-center gap-2">
                                                                    <input type="checkbox" checked={checked} onChange={() => toggleSchedule(s.id)} />
                                                                    <span className="flex-grow-1">
                                                                        {s.schedule_type} — {formatDateDdMmmYy(s.start_date)} – {formatDateDdMmmYy(s.end_date)}{' '}
                                                                        (Count: {s.count}) — [Status: {s.status}]
                                                                    </span>
                                                                </label>
                                                            );
                                                        })}
                                                    {filteredList.length === 0 ? (
                                                        <div className="p-3 text-center text-muted border rounded">
                                                            No open/publish schedules available (Total schedules: {publishList.length}).
                                                        </div>
                                                    ) : null}
                                                </div>
                                                {errors.schedule_ids && <div className="text-danger fs-12 mt-1">{errors.schedule_ids}</div>}
                                            </div>
                                        </div>
                                    </div>
                                    <div className="modal-footer">
                                        <button type="submit" className="btn btn-primary" disabled={processing}>
                                            {editingId ? 'Update' : 'Save'}
                                        </button>
                                        <button type="button" className="btn btn-outline-secondary" onClick={closeModal}>
                                            Cancel
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    <div className="modal-backdrop fade show" onClick={closeModal} />
                </>
            )}
        </AuthenticatedLayout>
    );
}
