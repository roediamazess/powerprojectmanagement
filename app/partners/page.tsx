export const dynamic = "force-dynamic";

type PartnerRow = {
  id: string;
  cnc_id: string;
  name: string;
  star?: number | null;
};

export default async function PartnersPage() {
  const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

  if (!apiBaseUrl) {
    return (
      <div className="container-fluid">
        <div className="row">
          <div className="col-12">
            <div className="card">
              <div className="card-body">
                <h4 className="mb-2">Konfigurasi API belum ada</h4>
                <div>
                  Set env <code>API_BASE_URL</code> (atau <code>NEXT_PUBLIC_API_BASE_URL</code>) ke URL backend Python.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const res = await fetch(`${apiBaseUrl.replace(/\/$/, "")}/api/public/partners?page_size=50`, {
    cache: "no-store",
  });

  if (!res.ok) {
    return (
      <div className="container-fluid">
        <div className="row">
          <div className="col-12">
            <div className="card">
              <div className="card-body">
                <h4 className="mb-2">Gagal ambil data dari API Python</h4>
                <div>
                  Status: {res.status} {res.statusText}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const payload: unknown = await res.json();
  const partners =
    (payload as { data?: PartnerRow[] }).data?.filter((x): x is PartnerRow => Boolean(x && x.id)) ?? [];

  return (
    <div className="container-fluid">
      <div className="row page-titles mx-0">
        <div className="col-sm-6 p-md-0">
          <div className="welcome-text">
            <h4>Partners</h4>
            <span>Sumber data: Python API</span>
          </div>
        </div>
      </div>

      <div className="row">
        <div className="col-12">
          <div className="card">
            <div className="card-header">
              <h4 className="card-title">Daftar Partners (maks 50)</h4>
            </div>
            <div className="card-body">
              <div className="table-responsive">
                <table className="table table-striped">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>CNC ID</th>
                      <th>Star</th>
                      <th>ID</th>
                    </tr>
                  </thead>
                  <tbody>
                    {partners.map((row) => (
                      <tr key={row.id}>
                        <td>{row.name || "-"}</td>
                        <td>{row.cnc_id || "-"}</td>
                        <td>{row.star ?? "-"}</td>
                        <td style={{ maxWidth: 320, overflow: "hidden" }}>
                          {row.id}
                        </td>
                      </tr>
                    ))}
                    {partners.length === 0 ? (
                      <tr>
                        <td colSpan={4}>Tidak ada data.</td>
                      </tr>
                    ) : null}
                  </tbody>
                </table>
              </div>
              <div className="mt-2">
                <small>
                  API: {apiBaseUrl}
                </small>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
