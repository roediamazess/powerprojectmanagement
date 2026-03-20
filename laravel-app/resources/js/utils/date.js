export function formatDateDdMmmYy(value) {
    if (!value) return '-';

    const text = String(value).trim();
    if (!text) return '-';

    let date;

    const m = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (m) {
        const year = Number(m[1]);
        const month = Number(m[2]);
        const day = Number(m[3]);
        date = new Date(Date.UTC(year, month - 1, day));
    } else {
        date = new Date(text);
    }

    if (Number.isNaN(date.getTime())) return text;

    return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit',
        month: 'short',
        year: '2-digit',
        timeZone: 'UTC',
    }).format(date);
}
