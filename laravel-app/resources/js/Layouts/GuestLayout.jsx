import { Link } from '@inertiajs/react';

export default function GuestLayout({ children }) {
    return (
        <div className="fix-wrapper">
            <div className="container">
                <div className="row justify-content-center">
                    <div className="col-lg-5 col-md-6">
                        <div className="card mb-0 h-auto">
                            <div className="card-body">
                                <div className="text-center mb-3">
                                    <Link href={route('dashboard')} className="d-flex flex-column align-items-center text-decoration-none">
                                        <img className="logo-auth" src="/images/power-pro-logo-plain.png?v=20260326" alt="Power Pro Logo" style={{ maxWidth: '140px' }} />
                                    </Link>
                                </div>
                                {children}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}