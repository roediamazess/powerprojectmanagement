import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, useForm } from '@inertiajs/react';

export default function Index({ auth, backups, diskStatuses }) {
    const { post, processing } = useForm();

    const runBackup = (type) => {
        if (confirm(`Apakah Anda yakin ingin menjalankan ${type === 'db' ? 'Backup Database' : 'Full Backup'}?`)) {
            post(route(type === 'db' ? 'backups.run-db' : 'backups.run-full'));
        }
    };

    return (
        <AuthenticatedLayout
            auth={auth}
            header={<h2 className="font-semibold text-xl text-gray-800 leading-tight">Backups</h2>}
        >
            <Head title="Backups" />

            <div className="py-12">
                <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
                    <div className="bg-white overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <div className="d-flex justify-content-between align-items-center mb-4">
                            <h4 className="card-title">Database & Website Backups</h4>
                            <div className="d-flex gap-2">
                                <button
                                    onClick={() => runBackup('db')}
                                    disabled={processing}
                                    className="btn btn-primary"
                                >
                                    <i className="fas fa-database me-2"></i>
                                    Backup Database
                                </button>
                                <button
                                    onClick={() => runBackup('full')}
                                    disabled={processing}
                                    className="btn btn-success"
                                >
                                    <i className="fas fa-file-archive me-2"></i>
                                    Full Backup (Web + DB)
                                </button>
                            </div>
                        </div>

                        <div className="mb-4">
                            <div className="d-flex flex-wrap gap-2">
                                {['local', 'google'].map((disk) => {
                                    const status = diskStatuses?.[disk];
                                    const ok = status?.ok ?? null;
                                    const label = disk === 'google' ? 'Google Drive' : 'Local';
                                    if (ok === true) {
                                        return (
                                            <span key={disk} className="badge bg-success">
                                                {label} connected
                                            </span>
                                        );
                                    }
                                    if (ok === false) {
                                        return (
                                            <span key={disk} className="badge bg-danger" title={status?.error || ''}>
                                                {label} error
                                            </span>
                                        );
                                    }
                                    return (
                                        <span key={disk} className="badge bg-secondary">
                                            {label} unknown
                                        </span>
                                    );
                                })}
                            </div>
                            {diskStatuses?.google?.ok === false ? (
                                <div className="alert alert-warning mt-3 mb-0">
                                    Google Drive belum terhubung. Cek konfigurasi <code>.env</code> dan log server. Detail: {diskStatuses.google.error}
                                </div>
                            ) : null}
                        </div>

                        <div className="table-responsive">
                            <table className="table table-hover table-striped">
                                <thead>
                                    <tr>
                                        <th>File Name</th>
                                        <th>Size</th>
                                        <th>Date</th>
                                        <th>Storage</th>
                                        <th className="text-end">Action</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {backups.length === 0 ? (
                                        <tr>
                                            <td colSpan="5" className="text-center text-muted py-4">
                                                No backup files found.
                                            </td>
                                        </tr>
                                    ) : (
                                        backups.map((backup, index) => (
                                            <tr key={index}>
                                                <td>{backup.name}</td>
                                                <td>{backup.size}</td>
                                                <td>{backup.date}</td>
                                                <td>
                                                    <span className={`badge ${backup.disk === 'google' ? 'bg-info' : 'bg-secondary'}`}>
                                                        {backup.disk === 'google' ? 'Google Drive' : 'Local'}
                                                    </span>
                                                </td>
                                                <td className="text-end">
                                                    <a
                                                        href={route('backups.download', { disk: backup.disk, path: btoa(backup.path) })}
                                                        className="btn btn-sm btn-outline-primary"
                                                    >
                                                        Download
                                                    </a>
                                                </td>
                                            </tr>
                                        ))
                                    )}
                                </tbody>
                            </table>
                        </div>

                        <div className="mt-4 p-4 bg-light rounded">
                            <h5 className="mb-3 text-warning">
                                <i className="fas fa-exclamation-triangle me-2"></i>
                                Penting (Google Drive Sync)
                            </h5>
                            <p className="small mb-0">
                                Pastikan variabel environment berikut sudah diatur di file <code>.env</code> server Anda agar sync ke Google Drive berfungsi:
                            </p>
                            <ul className="small mt-2">
                                <li><code>GOOGLE_DRIVE_CLIENT_ID</code></li>
                                <li><code>GOOGLE_DRIVE_CLIENT_SECRET</code></li>
                                <li><code>GOOGLE_DRIVE_REFRESH_TOKEN</code></li>
                                <li><code>GOOGLE_DRIVE_FOLDER</code></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
