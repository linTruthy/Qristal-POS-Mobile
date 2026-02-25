"use client";

import { useAuth } from "@/context/AuthContext";
import { useEffect, useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

const SERVER_URL = "https://qristal-pos-api.onrender.com";
const REFRESH_MS = 12000;
const COLORS = ["#2563eb", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6"];

type SalesDataPoint = { date: string; total: number };
type TopItem = { name: string; quantity: number };
type PaymentPoint = { method: string; _sum: { amount: number } };
type InventoryItem = { id: string; currentStock: number; minimumStock: number };

export default function AnalyticsPage() {
  const { token } = useAuth();
  const [salesData, setSalesData] = useState<SalesDataPoint[]>([]);
  const [topItems, setTopItems] = useState<TopItem[]>([]);
  const [paymentData, setPaymentData] = useState<PaymentPoint[]>([]);
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  useEffect(() => {
    if (!token) return;

    const headers = { Authorization: `Bearer ${token}` };

    const fetchData = async () => {
      try {
        const [salesRes, topItemsRes, paymentsRes, inventoryRes] = await Promise.all([
          fetch(`${SERVER_URL}/reports/sales`, { headers }),
          fetch(`${SERVER_URL}/reports/top-items`, { headers }),
          fetch(`${SERVER_URL}/reports/payments`, { headers }),
          fetch(`${SERVER_URL}/inventory`, { headers }),
        ]);

        const salesRaw = await salesRes.json();
        setSalesData(
          (salesRaw ?? []).map((item: SalesDataPoint) => ({
            ...item,
            date: new Date(item.date).toLocaleDateString(),
            total: Number(item.total || 0),
          })),
        );

        setTopItems(await topItemsRes.json());
        setPaymentData(await paymentsRes.json());
        setInventory(await inventoryRes.json());
        setLastUpdated(new Date());
      } catch (error) {
        console.error("Failed to fetch analytics", error);
      } finally {
        setLoading(false);
      }
    };

    void fetchData();
    const interval = setInterval(() => void fetchData(), REFRESH_MS);
    return () => clearInterval(interval);
  }, [token]);

  const summary = useMemo(() => {
    const revenue = salesData.reduce((sum, item) => sum + item.total, 0);
    const days = salesData.length;
    const avgPerDay = days ? revenue / days : 0;
    const lowStockCount = inventory.filter(
      (item) => Number(item.currentStock) <= Number(item.minimumStock),
    ).length;

    const paymentTotal = paymentData.reduce(
      (sum, item) => sum + Number(item?._sum?.amount ?? 0),
      0,
    );

    const highestPaymentMethod = paymentData
      .map((item) => ({ method: item.method, amount: Number(item?._sum?.amount ?? 0) }))
      .sort((a, b) => b.amount - a.amount)[0];

    return { revenue, avgPerDay, lowStockCount, paymentTotal, highestPaymentMethod };
  }, [salesData, paymentData, inventory]);

  if (loading) {
    return <div className="text-gray-600">Loading analytics...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Business Analytics</h1>
          <p className="text-sm text-gray-500 mt-1">
            Real-time performance pulse for sales, product demand, and payment mix.
          </p>
        </div>
        <p className="text-xs text-gray-500">
          Live refresh every {REFRESH_MS / 1000}s{lastUpdated ? ` • Last update ${lastUpdated.toLocaleTimeString()}` : ""}
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        <SummaryCard label="Revenue (loaded period)" value={`UGX ${summary.revenue.toFixed(0)}`} />
        <SummaryCard label="Average Daily Revenue" value={`UGX ${summary.avgPerDay.toFixed(0)}`} />
        <SummaryCard label="Low Stock Risk Items" value={summary.lowStockCount} />
        <SummaryCard
          label="Strongest Payment Channel"
          value={summary.highestPaymentMethod ? `${summary.highestPaymentMethod.method} (${summary.highestPaymentMethod.amount.toFixed(0)})` : "N/A"}
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <section className="bg-white p-5 rounded-xl border border-gray-100">
          <h2 className="text-lg font-semibold mb-4">Revenue Trend</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={salesData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="date" tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 12 }} />
                <Tooltip />
                <Area type="monotone" dataKey="total" stroke="#2563eb" fill="#bfdbfe" strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </section>

        <section className="bg-white p-5 rounded-xl border border-gray-100">
          <h2 className="text-lg font-semibold mb-4">Top Product Demand</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={topItems} layout="vertical" margin={{ left: 20 }}>
                <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                <XAxis type="number" />
                <YAxis dataKey="name" type="category" width={120} tick={{ fontSize: 12 }} />
                <Tooltip />
                <Bar dataKey="quantity" fill="#10b981" radius={[0, 6, 6, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </section>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <section className="bg-white p-5 rounded-xl border border-gray-100">
          <h2 className="text-lg font-semibold mb-4">Payment Mix</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={paymentData} dataKey="_sum.amount" nameKey="method" innerRadius={60} outerRadius={90} paddingAngle={3}>
                  {paymentData.map((_, idx) => (
                    <Cell key={idx} fill={COLORS[idx % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </section>

        <section className="bg-white p-5 rounded-xl border border-gray-100">
          <h2 className="text-lg font-semibold mb-4">Payment Throughput</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={paymentData.map((item) => ({
                  method: item.method,
                  amount: Number(item?._sum?.amount ?? 0),
                }))}
              >
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="method" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="amount" fill="#f59e0b" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
          <p className="text-xs text-gray-500 mt-2">Total across payment methods: UGX {summary.paymentTotal.toFixed(0)}</p>
        </section>
      </div>
    </div>
  );
}

function SummaryCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-white p-4 rounded-xl border border-gray-100">
      <p className="text-xs uppercase tracking-wide text-gray-500 font-semibold">{label}</p>
      <p className="text-2xl font-bold text-gray-900 mt-2">{value}</p>
    </div>
  );
}
