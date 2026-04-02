import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head } from '@inertiajs/react';
import { useEffect, useMemo, useRef, useState } from 'react';
import OfficeScene from './components/OfficeScene';
import CommandDock from './components/CommandDock';

export default function OfficeAgent() {
    const [dockOpen, setDockOpen] = useState(false);
    const [isRunning, setIsRunning] = useState(false);
    const [chat, setChat] = useState([]);

    const [loggerStatus, setLoggerStatus] = useState('idle');
    const [loggerBubble, setLoggerBubble] = useState('');
    const [securityStatus, setSecurityStatus] = useState('idle');
    const [securityBubble, setSecurityBubble] = useState('');
    const [notifierStatus, setNotifierStatus] = useState('idle');
    const [notifierBubble, setNotifierBubble] = useState('');

    const loggerSinceRef = useRef('');
    const securitySinceRef = useRef('');
    const activitySinceRef = useRef('');
    const esRef = useRef(null);
    const assistantTextRef = useRef('');

    const csrfToken = useMemo(() => {
        const el = document.querySelector('meta[name="csrf-token"]');
        return el?.getAttribute('content') || '';
    }, []);

    const appendChat = (role, text) => {
        setChat((prev) => [
            ...prev,
            {
                role,
                text: String(text || ''),
                at: new Date().toISOString(),
            },
        ]);
    };

    const fetchJson = async (url) => {
        const resp = await fetch(url, {
            headers: {
                Accept: 'application/json',
            },
            credentials: 'same-origin',
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        return await resp.json();
    };

    const poll = async () => {
        try {
            const qs = (since) => (since ? `?since=${encodeURIComponent(since)}` : '');

            const [loggerResp, securityResp, activityResp] = await Promise.all([
                fetchJson(`/office-agent/logger/events${qs(loggerSinceRef.current)}`),
                fetchJson(`/office-agent/security/events${qs(securitySinceRef.current)}`),
                fetchJson(`/office-agent/activity${qs(activitySinceRef.current)}`),
            ]);

            loggerSinceRef.current = String(loggerResp?.now || '');
            securitySinceRef.current = String(securityResp?.now || '');
            activitySinceRef.current = String(activityResp?.now || '');

            const loggerItems = Array.isArray(loggerResp?.items) ? loggerResp.items : [];
            if (loggerItems.length) {
                setLoggerStatus('listening');
                setLoggerBubble(String(loggerItems[0]?.message || ''));
            }

            const securityItems = Array.isArray(securityResp?.items) ? securityResp.items : [];
            if (securityItems.length) {
                const first = securityItems[0] || {};
                const msg = String(first?.message || '');
                setSecurityBubble(msg);
                if (msg.toLowerCase().includes('high')) setSecurityStatus('error');
                else setSecurityStatus('listening');
            }

            const activityItems = Array.isArray(activityResp?.items) ? activityResp.items : [];
            if (activityItems.length && !isRunning) {
                setNotifierStatus('listening');
                setNotifierBubble(String(activityItems[0]?.message || ''));
            }

            if (!loggerItems.length && loggerStatus !== 'offline') setLoggerStatus('idle');
            if (!securityItems.length && securityStatus !== 'offline') setSecurityStatus('idle');
            if (!activityItems.length && !isRunning && notifierStatus !== 'offline') setNotifierStatus('idle');
        } catch {
            setLoggerStatus('offline');
            setSecurityStatus('offline');
            if (!isRunning) setNotifierStatus('offline');
        }
    };

    useEffect(() => {
        poll();
        const t = window.setInterval(poll, 8000);
        return () => window.clearInterval(t);
    }, []);

    useEffect(() => {
        return () => {
            if (esRef.current) {
                try {
                    esRef.current.close();
                } catch {}
                esRef.current = null;
            }
        };
    }, []);

    const onStartRun = async (prompt) => {
        const text = String(prompt || '').trim();
        if (!text || isRunning) return;

        setDockOpen(false);
        setIsRunning(true);
        assistantTextRef.current = '';
        appendChat('user', text);
        setNotifierStatus('thinking');
        setNotifierBubble('Thinking…');

        try {
            const resp = await fetch('/office-agent/runs', {
                method: 'POST',
                headers: {
                    Accept: 'application/json',
                    'Content-Type': 'application/json',
                    ...(csrfToken ? { 'X-CSRF-TOKEN': csrfToken } : {}),
                },
                credentials: 'same-origin',
                body: JSON.stringify({ prompt: text }),
            });
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const data = await resp.json();
            const runId = String(data?.run_id || '');
            if (!runId) throw new Error('run_id missing');

            const es = new EventSource(`/office-agent/runs/${encodeURIComponent(runId)}/stream`);
            esRef.current = es;

            es.addEventListener('status', (e) => {
                try {
                    const payload = JSON.parse(String(e.data || '{}'));
                    const state = String(payload?.state || 'idle');
                    setNotifierStatus(state);
                    setNotifierBubble(state.toUpperCase());
                } catch {}
            });

            es.addEventListener('message_chunk', (e) => {
                try {
                    const payload = JSON.parse(String(e.data || '{}'));
                    const chunk = String(payload?.text || '');
                    if (!chunk) return;
                    assistantTextRef.current = assistantTextRef.current + chunk;
                    const preview = assistantTextRef.current.slice(-140);
                    setNotifierBubble(preview);
                } catch {}
            });

            es.addEventListener('tool_call', (e) => {
                appendChat('tool', String(e.data || ''));
            });

            es.addEventListener('telegram', (e) => {
                appendChat('system', String(e.data || ''));
            });

            es.addEventListener('done', () => {
                if (assistantTextRef.current) appendChat('assistant', assistantTextRef.current);
                setIsRunning(false);
                setNotifierStatus('idle');
                setNotifierBubble('');
                try {
                    es.close();
                } catch {}
                esRef.current = null;
            });

            es.onerror = () => {
                if (assistantTextRef.current) appendChat('assistant', assistantTextRef.current);
                setIsRunning(false);
                setNotifierStatus('error');
                setNotifierBubble('Connection error');
                try {
                    es.close();
                } catch {}
                esRef.current = null;
            };
        } catch (err) {
            setIsRunning(false);
            setNotifierStatus('error');
            setNotifierBubble('Run failed');
            appendChat('system', err?.message ? String(err.message) : 'Run failed');
        }
    };

    const header = (
        <div>
            <div className="h5 mb-0">Office Agent</div>
            <div className="text-muted small">Pixel office · realtime events</div>
        </div>
    );

    const agents = useMemo(() => {
        return [
            { id: 'security', name: 'Security', status: securityStatus, bubbleText: securityBubble, bubbleKeyboard: false },
            { id: 'logger', name: 'Logger', status: loggerStatus, bubbleText: loggerBubble, bubbleKeyboard: false },
            { id: 'notifier', name: 'Notifier', status: notifierStatus, bubbleText: notifierBubble, bubbleKeyboard: isRunning },
        ];
    }, [securityStatus, securityBubble, loggerStatus, loggerBubble, notifierStatus, notifierBubble, isRunning]);

    return (
        <AuthenticatedLayout header={header}>
            <Head title="Office Agent" />
            <div className="container-fluid">
                <div className="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
                    <div className="text-muted small">Monitor security/logs/activity dan jalankan instruksi Office Agent.</div>
                    <div className="d-flex align-items-center gap-2">
                        <button type="button" className="btn btn-primary" onClick={() => setDockOpen(true)} disabled={isRunning}>
                            Run Command
                        </button>
                        <button type="button" className="btn btn-outline-secondary" onClick={poll}>
                            Refresh
                        </button>
                    </div>
                </div>

                <div className="card mb-3">
                    <div className="card-body p-2">
                        <OfficeScene agents={agents} onRunClick={() => setDockOpen(true)} />
                    </div>
                </div>

                <div className="card">
                    <div className="card-header d-flex align-items-center justify-content-between">
                        <div className="fw-semibold">Transcript</div>
                        <button type="button" className="btn btn-sm btn-outline-secondary" onClick={() => setChat([])} disabled={isRunning}>
                            Clear
                        </button>
                    </div>
                    <div className="card-body" style={{ whiteSpace: 'pre-wrap' }}>
                        {chat.length ? chat.slice(-30).map((m, idx) => (
                            <div key={idx} className="mb-2">
                                <div className="text-muted small">{String(m.role || '').toUpperCase()} · {m.at}</div>
                                <div>{String(m.text || '')}</div>
                            </div>
                        )) : <div className="text-muted">Belum ada transcript.</div>}
                    </div>
                </div>
            </div>

            <CommandDock
                open={dockOpen}
                onClose={() => setDockOpen(false)}
                onStartRun={onStartRun}
                isRunning={isRunning}
                chat={chat}
            />
        </AuthenticatedLayout>
    );
}
