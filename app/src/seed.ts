export interface OrderRow {
  id: string;
  item: string;
  amount: number;
  status: "paid" | "pending";
}

export interface PaymentRow {
  id: string;
  orderId: string;
  method: "card" | "upi" | "cod";
  amount: number;
  paidAt: string;
}

const ORDERS: OrderRow[] = [
  { id: "ord_001", item: "mech-keyboard", amount: 129.99, status: "paid" },
  { id: "ord_002", item: "gpu-riser", amount: 24.5, status: "paid" },
  { id: "ord_003", item: "nvme-2tb", amount: 149.0, status: "paid" },
  { id: "ord_004", item: "webcam-4k", amount: 89.9, status: "pending" },
];

const PAYMENTS: PaymentRow[] = [
  { id: "pay_001", orderId: "ord_001", method: "card", amount: 129.99, paidAt: "2026-08-20T10:14:00Z" },
  { id: "pay_002", orderId: "ord_002", method: "upi", amount: 24.5, paidAt: "2026-08-21T18:03:00Z" },
  { id: "pay_003", orderId: "ord_003", method: "card", amount: 149.0, paidAt: "2026-08-22T09:41:00Z" },
];

export function seedOrders(): OrderRow[] {
  return ORDERS.map((o) => ({ ...o }));
}

export function seedPayments(): PaymentRow[] {
  return PAYMENTS.map((p) => ({ ...p }));
}
