const colorValues = Array.from({ length: 15 }, (_, i) => `color_${i + 1}`);

function ColorGroup({
  title,
  name,
  idPrefix,
}: {
  title: string;
  name: string;
  idPrefix: string;
}) {
  return (
    <div>
      <p>{title}</p>
      <div>
        {colorValues.flatMap((value, idx) => {
          const id = `${idPrefix}_${idx + 1}`;
          return [
            <input key={`${id}_i`} type="radio" name={name} value={value} id={id} />,
            <label key={`${id}_l`} htmlFor={id}></label>,
          ];
        })}
      </div>
    </div>
  );
}

export default function SettingsPanel() {
  return (
    <div className="sidebar-right">
      <div className="bg-overlay"></div>
      <a className="sidebar-right-trigger" href="#">
        <span>
          <i className="fas fa-cog"></i>
        </span>
      </a>
      <a className="sidebar-close-trigger" href="#">
        <i className="las la-times"></i>
      </a>
      <div className="sidebar-right-inner">
        <div className="d-flex align-items-center justify-content-between mb-3">
          <h4 className="mb-0">Pick your style</h4>
          <button className="btn btn-primary btn-sm" id="deleteAllCookie">
            Delete All Cookie
          </button>
        </div>

        <div className="card-tabs">
          <ul className="nav nav-tabs" role="tablist">
            <li className="nav-item">
              <a
                className="nav-link active"
                data-bs-toggle="tab"
                href="#theme-tab"
                role="tab"
              >
                Theme
              </a>
            </li>
            <li className="nav-item">
              <a
                className="nav-link"
                data-bs-toggle="tab"
                href="#header-tab"
                role="tab"
              >
                Header
              </a>
            </li>
            <li className="nav-item">
              <a
                className="nav-link"
                data-bs-toggle="tab"
                href="#content-tab"
                role="tab"
              >
                Content
              </a>
            </li>
          </ul>
        </div>

        <div className="tab-content">
          <div className="tab-pane fade active show" id="theme-tab" role="tabpanel">
            <div className="admin-settings">
              <div className="row">
                <div className="col-12">
                  <p>Background</p>
                  <select className="default-select form-control wide" id="theme_version">
                    <option value="light">Light</option>
                    <option value="dark">Dark</option>
                    <option value="transparent">Transparent</option>
                  </select>
                </div>

                <div className="col-lg-6 mt-4">
                  <ColorGroup title="Primary Color" name="primary_color" idPrefix="primary_color" />
                </div>
                <div className="col-lg-6 mt-4">
                  <ColorGroup
                    title="Navigation Header"
                    name="nav_header_color"
                    idPrefix="nav_header_color"
                  />
                </div>
                <div className="col-lg-6 mt-4">
                  <ColorGroup title="Header" name="header_color" idPrefix="header_color" />
                </div>
                <div className="col-lg-6 mt-4">
                  <ColorGroup title="Sidebar" name="sidebar_color" idPrefix="sidebar_color" />
                </div>
              </div>
            </div>
          </div>

          <div className="tab-pane fade" id="header-tab" role="tabpanel">
            <div className="admin-settings">
              <div className="row">
                <div className="col-lg-6">
                  <p>Layout</p>
                  <select className="default-select form-control wide" id="theme_layout">
                    <option value="vertical">Vertical</option>
                    <option value="horizontal">Horizontal</option>
                  </select>
                </div>
                <div className="col-lg-6">
                  <p>Header position</p>
                  <select className="default-select form-control wide" id="header_position">
                    <option value="fixed">Fixed</option>
                    <option value="static">Static</option>
                  </select>
                </div>
                <div className="col-lg-6 mt-4">
                  <p>Sidebar</p>
                  <select className="default-select form-control wide" id="sidebar_style">
                    <option value="full">Full</option>
                    <option value="mini">Mini</option>
                    <option value="compact">Compact</option>
                    <option value="modern">Modern</option>
                    <option value="icon-hover">Icon Hover</option>
                    <option value="overlay">Overlay</option>
                  </select>
                </div>
                <div className="col-lg-6 mt-4">
                  <p>Sidebar position</p>
                  <select className="default-select form-control wide" id="sidebar_position">
                    <option value="fixed">Fixed</option>
                    <option value="static">Static</option>
                  </select>
                </div>
              </div>
            </div>
          </div>

          <div className="tab-pane fade" id="content-tab" role="tabpanel">
            <div className="admin-settings">
              <div className="row">
                <div className="col-lg-6">
                  <p>Container</p>
                  <select className="default-select form-control wide" id="container_layout">
                    <option value="full">Full</option>
                    <option value="boxed">Boxed</option>
                    <option value="wide-boxed">Wide Boxed</option>
                  </select>
                </div>
                <div className="col-lg-6">
                  <p>Body Font</p>
                  <select className="default-select form-control wide" id="theme_typography">
                    <option value="poppins">Poppins</option>
                    <option value="roboto">Roboto</option>
                    <option value="opensans">Open Sans</option>
                    <option value="helvetica">Helvetica</option>
                  </select>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="note-text">Theme &amp; layout settings</div>
    </div>
  );
}
