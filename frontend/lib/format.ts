export function formatMoney(value: number | string | null | undefined) {
  return `${Number(value || 0).toLocaleString()} VND`;
}

export function formatDateTime(value?: string | null) {
  if (!value) return "—";
  return new Date(value).toLocaleString();
}

export function itemProgress(items: { status: string }[]) {
  if (!items.length) return 0;
  const delivered = items.filter((item) => item.status === "DELIVERED").length;
  return Math.round((delivered / items.length) * 100);
}
