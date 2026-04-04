import { Link, usePage } from '@inertiajs/react';

export default function ArrangementTabs({ isManager }) {
    const url = usePage().url ?? '';
    const isPickUp = url === '/arrangements';
    const isJobsheet = url.startsWith('/arrangements/jobsheet');
    const isSchedules = url.startsWith('/arrangements/schedules');
    const isBatches = url.startsWith('/arrangements/batches');

    return (
        <div className="card-tabs mt-sm-0">
            <ul className="nav nav-tabs" role="tablist">
                <li className="nav-item">
                    <Link className={`nav-link${isPickUp ? ' active' : ''}`} href={route('arrangements.index', {}, false)}>
                        <i className="fas fa-truck-loading me-2"></i>
                        Pick Up
                    </Link>
                </li>
                <li className="nav-item">
                    <Link className={`nav-link${isJobsheet ? ' active' : ''}`} href={route('arrangements.jobsheet', {}, false)}>
                        <i className="fas fa-clipboard-list me-2"></i>
                        Jobsheet
                    </Link>
                </li>
                {isManager ? (
                    <>
                        <li className="nav-item">
                            <Link className={`nav-link${isSchedules ? ' active' : ''}`} href={route('arrangements.schedules.index', {}, false)}>
                                <i className="fas fa-calendar-alt me-2"></i>
                                Manage Schedules
                            </Link>
                        </li>
                        <li className="nav-item">
                            <Link className={`nav-link${isBatches ? ' active' : ''}`} href={route('arrangements.batches.index', {}, false)}>
                                <i className="fas fa-layer-group me-2"></i>
                                Manage Batches
                            </Link>
                        </li>
                    </>
                ) : null}
            </ul>
        </div>
    );
}
