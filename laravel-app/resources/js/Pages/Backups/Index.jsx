import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, router } from '@inertiajs/react';
import axios from 'axios';
import { useEffect, useMemo, useRef, useState } from 'react';
import { formatDateTimeDdMmmYyHms } from '@/utils/date';

export default function BackupsIndex({ root, items }) {
    const [showConfirm, setShowConfirm] = useState(false);
    const [confirmTitle, setConfirmTitle] = useState('Konfirmasi');
    const [confirmBody, setConfirmBody] = useState('');
    const [processing, setProcessing] = useState(false);

    const [runId, setRunId] = useState(null);
    const [progress, setProgress] = useState(0);
    const [message, setMessage] = useState('');
    const [error, setError] = useState('');
    const [done, setDone] = useState(false);

    const pollTimer = useRef(null);

    const openManualBackupConfirm = () => {
        setConfirmTitle('Backup & Sync ke Google Drive');
        setConfirmBody('Jalankan backup database + storage, lalu upload dan sync ke Google Drive?');
        setShowConfirm(true);
    };

    const closeConfirm = () => {
        if (processing) return;
        setShowConfirm(false);
    };

    const stopPolling = () => {
        if (pollTimer.current) window.clearInterval(pollTimer.current);
        pollTimer.current = null;
    };

    const applyStatusPayload = (payload) => {
        if (!payload || typeof payload !== 'object') {
            throw new Error('Invalid status payload');
        }
        setProgress(payload.progress ?? 0);
        setMessage(payload.message ?? '');
        setError(payload.error ?? '');
        const isDone = Boolean(payload.done);
        setDone(isDone);
        if (isDone) {
            stopPolling();
            try {
                window.localStorage.removeItem('powerpro_backup_run_id');
            } catch (_e) {
            }
            router.reload({ preserveScroll: true, preserveState: true });
        }
    };

    const startPolling = async (nextRunId) => {
        stopPolling();
        try {
            const res = await axios.get(route('backups.manual.status', { runId: nextRunId }));
            applyStatusPayload(res?.data);
        } catch (_e) {
            setError('Gagal mengambil status backup. Coba refresh halaman.');
            setDone(true);
            stopPolling();
            return;
        }

        pollTimer.current = window.setInterval(async () => {
            try {
                const res = await axios.get(route('backups.manual.status', { runId: nextRunId }));
                applyStatusPayload(res?.data);
            } catch (_e) {
                setError('Gagal mengambil status backup. Coba refresh halaman.');
                setDone(true);
                stopPolling();
            }
        }, 1500);
    };

    const runManualBackup = async () => {
        setProcessing(true);
        try {
            const res = await axios.post(route('backups.manual.run'));
            const payload = res?.data || {};
            const nextRunId = payload.runId || null;
            setShowConfirm(false);
            setRunId(nextRunId);
            setProgress(1);
            setMessage(payload.alreadyRunning ? 'Backup sedang berjalan...' : 'Memulai backup...');
            setError('');
            setDone(false);
            if (nextRunId) {
                try {
                    window.localStorage.setItem('powerpro_backup_run_id', String(nextRunId));
                } catch (_e) {
                }
                startPolling(nextRunId);
            } else {
                setDone(true);
                setError('Gagal memulai backup (runId kosong).');
            }
        } catch (e) {
            setShowConfirm(false);
            setRunId(null);
            setProgress(100);
            setMessage('Backup gagal');
            setError('Gagal memulai backup. Coba lagi.');
            setDone(true);
        } finally {
            setProcessing(false);
        }
    };

    useEffect(() => {
        try {
            const existing = window.localStorage.getItem('powerpro_backup_run_id');
            if (existing) {
                setRunId(existing);
                startPolling(existing);
            }
        } catch (_e) {
        }
        return () => {
            stopPolling();
        };
    }, []);

    const clearProgress = () => {
        if (!done) return;
        try {
            window.localStorage.removeItem('powerpro_backup_run_id');
        } catch (_e) {
        }
        setRunId(null);
        setProgress(0);
        setMessage('');
        setError('');
        setDone(false);
    };

    const rows = useMemo(() => items ?? [], [items]);

    return (
        <>
            <Head title="Backups" />

            <div className="row">
                <div className="col-12">
                    <div className="card">
                        <div className="card-header d-flex justify-content-between align-items-center">
                            <div className="flex-shrink-0">
                                <h4 className="card-title mb-0">Backups</h4>
                                {root ? <small className="text-muted">Root: {root}</small> : null}
                            </div>
                            {runId ? (
                                <div className="flex-grow-1 px-3" style={{ maxWidth: 720 }}>
                                    <div className={`alert ${error ? 'alert-danger' : done ? 'alert-success' : 'alert-info'} mb-0 py-2`}>
                                        <div className="d-flex justify-content-between align-items-center mb-1">
                                            <div className="text-muted small">{message || '...'}</div>
                                            <div className="d-flex align-items-center gap-2">
                                                <span className="text-muted small">Run ID: {runId}</span>
                                                <button type="button" className="btn-close" onClick={clearProgress} disabled={!done} />
                                            </div>
                                        </div>
                                        <div className="progress" style={{ height: 8 }}>
                                            <div
                                                className={`progress-bar ${error ? 'bg-danger' : 'bg-primary'}`}
                                                role="progressbar"
                                                style={{ width: `${Math.max(0, Math.min(100, progress))}%` }}
                                                aria-valuenow={progress}
                                                aria-valuemin="0"
                                                aria-valuemax="100"
                                            />
                                        </div>
                                        <div className="d-flex justify-content-between align-items-center mt-1">
                                            <div className="small">
                                                {error ? error : done ? 'Backup & sync berhasil.' : 'Sedang berjalan...'}
                                            </div>
                                            <div className="fw-bold small">{progress}%</div>
                                        </div>
                                    </div>
                                </div>
                            ) : (
                                <div className="flex-grow-1" />
                            )}
                            <div className="d-flex gap-2">
                                <button type="button" className="btn btn-primary" onClick={openManualBackupConfirm} disabled={processing}>
                                    <i className="fas fa-cloud-upload-alt me-2"></i>
                                    Backup & Sync
                                </button>
                            </div>
                        </div>
                        <div className="card-body">
                            <div className="table-responsive">
                                <table className="table table-hover table-striped">
                                    <thead>
                                        <tr>
                                            <th>File</th>
                                            <th>Type</th>
                                            <th>Modified</th>
                                            <th className="text-end">Size</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {rows.length === 0 ? (
                                            <tr>
                                                <td colSpan="4" className="text-center text-muted py-4">
                                                    Belum ada backup.
                                                </td>
                                            </tr>
                                        ) : (
                                            rows.map((it) => (
                                                <tr key={it.path}>
                                                    <td className="white-space-nowrap">{it.name}</td>
                                                    <td>
                                                        <span className={`badge ${it.type === 'db' ? 'bg-info' : 'bg-secondary'}`}>{it.type}</span>
                                                    </td>
                                                    <td className="white-space-nowrap">{formatDateTimeDdMmmYyHms(it.mtime)}</td>
                                                    <td className="text-end white-space-nowrap">
                                                        {typeof it.size === 'number' ? `${(it.size / 1024 / 1024).toFixed(2)} MB` : '-'}
                                                    </td>
                                                </tr>
                                            ))
                                        )}
                                    </tbody>
                                </table>
                            </div>
                            <div className="alert alert-light mb-0">
                                Backup manual ini melakukan dump database + tar storage, lalu sync ke Google Drive via rclone.
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {showConfirm ? (
                <>
                    <div className="modal fade show" style={{ display: 'block' }} role="dialog" aria-modal="true">
                        <div className="modal-dialog modal-dialog-centered" role="document">
                            <div className="modal-content">
                                <div className="modal-header">
                                    <h5 className="modal-title">{confirmTitle}</h5>
                                    <button type="button" className="btn-close" onClick={closeConfirm} disabled={processing} />
                                </div>
                                <div className="modal-body">
                                    <p className="mb-0">{confirmBody}</p>
                                </div>
                                <div className="modal-footer">
                                    <button type="button" className="btn btn-primary" onClick={runManualBackup} disabled={processing}>
                                        Jalankan
                                    </button>
                                    <button type="button" className="btn btn-outline-secondary" onClick={closeConfirm} disabled={processing}>
                                        Cancel
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="modal-backdrop fade show" onClick={closeConfirm} />
                </>
            ) : null}
        </>
    );
}

BackupsIndex.layout = (page) => <AuthenticatedLayout header="Backups">{page}</AuthenticatedLayout>;
