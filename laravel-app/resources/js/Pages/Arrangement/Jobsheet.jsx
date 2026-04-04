import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, router, useForm } from '@inertiajs/react';
import { formatDateDdMmmYy } from '@/utils/date';
import ArrangementTabs from './Partials/ArrangementTabs';
import { useMemo, useState } from 'react';

export default function Jobsheet({ isManager, pics, holidays, periods, selectedPeriod }) {
    const [showCreate, setShowCreate] = useState(false);
    const { data, setData, post, processing, errors, reset } = useForm({
        name: '',
        start_date: '',
        end_date: '',
    });

    const days = useMemo(() => {
        if (!selectedPeriod?.start_date || !selectedPeriod?.end_date) return [];
        const s = new Date(`${selectedPeriod.start_date}T00:00:00+07:00`);
        const e = new Date(`${selectedPeriod.end_date}T00:00:00+07:00`);
        if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime()) || s > e) return [];
        const out = [];
        const cur = new Date(s);
        while (cur <= e) {
            out.push(new Date(cur));
            cur.setDate(cur.getDate() + 1);
        }
        return out;
    }, [selectedPeriod?.start_date, selectedPeriod?.end_date]);

    const formatDayHeader = (d) => {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const dd = String(d.getDate()).padStart(2, '0');
        return { mmm: months[d.getMonth()] ?? '', dd };
    };

    const holidaySet = useMemo(() => new Set((holidays ?? []).map((x) => String(x).trim()).filter(Boolean)), [holidays]);

    const ymd = (d) => {
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    };

    const getDayStyle = (d, isHeader) => {
        const key = ymd(d);
        const dow = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Jakarta', weekday: 'short' }).format(d);
        const isSun = dow === 'Sun';
        const isSat = dow === 'Sat';
        const isHoliday = holidaySet.has(key);

        if (isHoliday) {
            return { background: '#d1d5db', color: '#111827' };
        }
        if (isSun) {
            return { background: '#ef4444', color: '#111827' };
        }
        if (isSat) {
            return { background: '#d946ef', color: '#111827' };
        }
        if (isHeader) {
            return { background: 'rgba(255,255,255,0.02)' };
        }
        return undefined;
    };

    const periodeSummary = useMemo(() => {
        if (!selectedPeriod) return null;
        return {
            id: selectedPeriod.id,
            name: selectedPeriod.name,
            startText: selectedPeriod.start_date ? formatDateDdMmmYy(selectedPeriod.start_date) : '-',
            endText: selectedPeriod.end_date ? formatDateDdMmmYy(selectedPeriod.end_date) : '-',
        };
    }, [selectedPeriod]);

    const selectPeriod = (id) => {
        if (!id) return;
        router.get(route('arrangements.jobsheet', { period: id }, false), {}, { preserveScroll: true, preserveState: true });
    };

    const openCreate = () => {
        reset();
        setShowCreate(true);
    };

    const closeCreate = () => {
        if (processing) return;
        setShowCreate(false);
    };

    const submitCreate = (e) => {
        e.preventDefault();
        post(route('arrangements.jobsheet.store', {}, false), {
            preserveScroll: true,
            onSuccess: () => {
                setShowCreate(false);
                reset();
            },
        });
    };

    const stickyPicHeaderStyle = {
        minWidth: 180,
        position: 'sticky',
        left: 0,
        zIndex: 3,
        background: 'var(--bs-body-bg)',
    };

    const stickyPicCellStyle = {
        position: 'sticky',
        left: 0,
        zIndex: 2,
        background: 'var(--bs-body-bg)',
    };

    return (
        <AuthenticatedLayout header={<h2 className="text-xl font-semibold leading-tight text-gray-800">Arrangement — Jobsheet</h2>}>
            <Head title="Arrangement Jobsheet" />

            <div className="row">
                <div className="col-12">
                    <div className="card">
                        <div className="card-header d-flex flex-wrap align-items-center justify-content-between pb-2">
                            <div className="d-flex align-items-center flex-grow-1">
                                <ArrangementTabs isManager={isManager} />
                            </div>
                            <div className="d-flex align-items-center gap-2">
                                <div style={{ minWidth: 280 }}>
                                    <div className="input-group">
                                        <span className="input-group-text">
                                            <svg
                                                xmlns="http://www.w3.org/2000/svg"
                                                width="18"
                                                height="18"
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth="2"
                                                strokeLinecap="round"
                                                strokeLinejoin="round"
                                            >
                                                <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                                                <line x1="16" y1="2" x2="16" y2="6" />
                                                <line x1="8" y1="2" x2="8" y2="6" />
                                                <line x1="3" y1="10" x2="21" y2="10" />
                                            </svg>
                                        </span>
                                        <select
                                            className="form-select"
                                            value={periodeSummary?.id ?? ''}
                                            onChange={(e) => selectPeriod(e.target.value)}
                                        >
                                            <option value="">Pilih Periode...</option>
                                            {(periods ?? []).map((p) => (
                                                <option key={p.id} value={p.id}>
                                                    {p.name} ({p.start_date ? formatDateDdMmmYy(p.start_date) : '-'} – {p.end_date ? formatDateDdMmmYy(p.end_date) : '-'})
                                                </option>
                                            ))}
                                        </select>
                                    </div>
                                </div>
                                <button type="button" className="btn btn-primary" onClick={openCreate}>
                                    Create Periode
                                </button>
                            </div>
                        </div>
                        <div className="card-body">
                            {days.length ? (
                                <div className="table-responsive">
                                    <table className="table table-bordered align-middle mb-0">
                                        <thead>
                                            <tr>
                                                <th style={stickyPicHeaderStyle}>PIC</th>
                                                {days.map((d) => (
                                                    <th
                                                        key={d.toISOString()}
                                                        className="text-center white-space-nowrap"
                                                        style={{ minWidth: 90, ...getDayStyle(d, true) }}
                                                    >
                                                        <div className="text-muted fs-12">{formatDayHeader(d).mmm}</div>
                                                        <div className="fw-semibold">{formatDayHeader(d).dd}</div>
                                                    </th>
                                                ))}
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {(pics ?? []).length
                                                ? pics.map((p) => (
                                                      <tr key={p.id}>
                                                          <td className="fw-semibold" style={stickyPicCellStyle}>
                                                              {p.name}
                                                          </td>
                                                          {days.map((d) => (
                                                              <td key={d.toISOString()} className="text-center" style={getDayStyle(d, false)}>
                                                                  -
                                                              </td>
                                                          ))}
                                                      </tr>
                                                  ))
                                                : null}
                                        </tbody>
                                    </table>
                                </div>
                            ) : (
                                <div className="text-muted">Pilih periode untuk menampilkan Jobsheet.</div>
                            )}
                        </div>
                    </div>
                </div>
            </div>

            {showCreate ? (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered" role="document">
                            <div className="modal-content border-0 shadow-lg overflow-hidden">
                                <div className="modal-header">
                                    <h5 className="modal-title mb-0">Create Periode</h5>
                                    <button type="button" className="btn-close" onClick={closeCreate} disabled={processing} />
                                </div>
                                <form onSubmit={submitCreate}>
                                    <div className="modal-body">
                                        <div className="row g-3">
                                            <div className="col-12">
                                                <label className="form-label">Periode Name</label>
                                                <input type="text" className="form-control" value={data.name} onChange={(e) => setData('name', e.target.value)} />
                                                {errors.name ? <div className="text-danger fs-12 mt-1">{errors.name}</div> : null}
                                            </div>
                                            <div className="col-6">
                                                <label className="form-label">Start Periode</label>
                                                <input
                                                    type="date"
                                                    className="form-control"
                                                    value={data.start_date}
                                                    onChange={(e) => setData('start_date', e.target.value)}
                                                />
                                                {errors.start_date ? <div className="text-danger fs-12 mt-1">{errors.start_date}</div> : null}
                                            </div>
                                            <div className="col-6">
                                                <label className="form-label">End Periode</label>
                                                <input type="date" className="form-control" value={data.end_date} onChange={(e) => setData('end_date', e.target.value)} />
                                                {errors.end_date ? <div className="text-danger fs-12 mt-1">{errors.end_date}</div> : null}
                                            </div>
                                        </div>
                                    </div>
                                    <div className="modal-footer">
                                        <button
                                            type="submit"
                                            className="btn btn-primary"
                                            disabled={processing || !data.name || !data.start_date || !data.end_date}
                                        >
                                            Create
                                        </button>
                                        <button type="button" className="btn btn-outline-secondary" onClick={closeCreate} disabled={processing}>
                                            Cancel
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    <div className="modal-backdrop fade show" onClick={closeCreate} />
                </>
            ) : null}
        </AuthenticatedLayout>
    );
}
