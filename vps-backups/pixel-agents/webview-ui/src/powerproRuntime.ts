import { dispatchMockMessages } from './browserMock.js';
import { isBrowserRuntime } from './runtime.js';

function isPowerproHost(): boolean {
  if (!isBrowserRuntime) return false;
  const p = window.location.pathname || '';
  return p.startsWith('/agent-working-space') || p.startsWith('/office-agent-ui');
}

function post(msg: unknown) {
  window.dispatchEvent(new MessageEvent('message', { data: msg }));
}

function agentCreated(id: number, name: string) {
  post({ type: 'agentCreated', id, folderName: name });
  post({ type: 'agentStatus', id, status: 'idle' });
}

function pulseAgent(id: number, status: string, toolPrefix: string, ms = 1600) {
  const toolId = `${toolPrefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  post({ type: 'agentStatus', id, status: 'active' });
  post({ type: 'agentToolStart', id, toolId, status });
  window.setTimeout(() => post({ type: 'agentToolDone', id, toolId }), Math.max(400, ms - 700));
  window.setTimeout(() => {
    post({ type: 'agentToolsClear', id });
    post({ type: 'agentStatus', id, status: 'idle' });
  }, ms);
}

type PollState = {
  secSince: string;
  logSince: string;
  tbSince: string;
};

async function fetchJson(url: string): Promise<any | null> {
  try {
    const res = await fetch(url, { headers: { 'X-Requested-With': 'XMLHttpRequest' }, credentials: 'include' });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

export function startPowerproRuntime() {
  if (!isPowerproHost()) return;
  const w = window as any;
  if (w.__POWERPRO_PIXEL_STARTED) return;
  w.__POWERPRO_PIXEL_STARTED = true;

  dispatchMockMessages();

  agentCreated(1, 'Guardian');
  agentCreated(2, 'Observer');
  agentCreated(3, 'Messenger');

  const state: PollState = {
    secSince: '',
    logSince: '',
    tbSince: '',
  };

  const tick = async () => {
    const secUrl = '/office-agent/security/events' + (state.secSince ? `?since=${encodeURIComponent(state.secSince)}` : '');
    const sec = await fetchJson(secUrl);
    if (sec?.now) state.secSince = String(sec.now);
    const secMsg = Array.isArray(sec?.items) && sec.items[0]?.message ? String(sec.items[0].message) : '';
    if (secMsg) pulseAgent(1, `Reading: ${secMsg}`, 'sec');

    const logUrl = '/office-agent/logger/events' + (state.logSince ? `?since=${encodeURIComponent(state.logSince)}` : '');
    const log = await fetchJson(logUrl);
    if (log?.now) state.logSince = String(log.now);
    const logMsg = Array.isArray(log?.items) && log.items[0]?.message ? String(log.items[0].message) : '';
    if (logMsg) pulseAgent(2, `Reading: ${logMsg}`, 'log');

    const tbUrl = '/office-agent/activity' + (state.tbSince ? `?since=${encodeURIComponent(state.tbSince)}` : '');
    const tb = await fetchJson(tbUrl);
    if (tb?.now) state.tbSince = String(tb.now);
    const tbMsg = Array.isArray(tb?.items) && tb.items[0]?.message ? String(tb.items[0].message) : '';
    if (tbMsg) pulseAgent(2, `Writing: ${tbMsg}`, 'tb');
  };

  tick();
  window.setInterval(tick, 4000);
}

