"use client";

import { useAuth } from "@/context/AuthContext";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

const SERVER_URL = "https://qristal-pos-api.onrender.com";
const REFRESH_MS = 10000;

type InventoryItem = {
  id: string;
  name: string;
  currentStock: number;
  minimumStock: number;
};

type KitchenOrder = {
  id: string;
  status: string;
};

type SalesPoint = {
  date: string;
  total: number;
};

export default function AdminHomePage() {
  const { token } = useAuth();
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [kitchenOrders, setKitchenOrders] = useState<KitchenOrder[]>([]);
  const [sales, setSales] = useState<SalesPoint[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token) return;

    const headers = { Authorization: `Bearer ${token}` };

    const fetchAll = async () => {
      try {
        const [inventoryRes, ordersRes, salesRes] = await Promise.all([
          fetch(`${SERVER_URL}/inventory`, { headers }),
          fetch(`${SERVER_URL}/orders/kitchen`, { headers }),
          fetch(`${SERVER_URL}/reports/sales`, { headers }),
        ]);

        setInventory((await inventoryRes.json()) ?? []);

        const ordersData = await ordersRes.json();
        const normalizedOrders = Array.isArray(ordersData)
          ? ordersData
          : Array.isArray(ordersData?.orders)
            ? ordersData.orders
            : [];
        setKitchenOrders(normalizedOrders);

        setSales((await salesRes.json()) ?? []);
      } catch (error) {
        console.error("Unable to load admin dashboard data", error);
      } finally {
        setLoading(false);
      }
    };

    void fetchAll();
    const interval = setInterval(() => void fetchAll(), REFRESH_MS);

    return () => clearInterval(interval);
  }, [token]);

  const kpis = useMemo(() => {
    const lowStock = inventory.filter(
      (item) => Number(item.currentStock) <= Number(item.minimumStock),
    ).length;

    const pendingKitchen = kitchenOrders.filter((order) =>
      ["KITCHEN", "PREPARING"].includes(order.status),
    ).length;

    const totalSales = sales.reduce((sum, item) => sum + Number(item.total || 0), 0);
    const avgDaily = sales.length ? totalSales / sales.length : 0;

    return { lowStock, pendingKitchen, totalSales, avgDaily };
  }, [inventory, kitchenOrders, sales]);

  if (loading) {
    return <div className="text-gray-600">Loading admin dashboard...</div>;
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">
          Real-time overview of stock, kitchen pressure, and sales performance.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        <StatCard label="Low Stock Items" value={kpis.lowStock} tone="red" />
        <StatCard label="Kitchen Queue" value={kpis.pendingKitchen} tone="amber" />
        <StatCard label="Sales (period loaded)" value={`UGX ${kpis.totalSales.toFixed(0)}`} tone="emerald" />
        <StatCard label="Average Daily Sales" value={`UGX ${kpis.avgDaily.toFixed(0)}`} tone="blue" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <QuickLink title="Business Analytics" description="View live revenue and payment trends." href="/admin/analytics" />
        <QuickLink title="Inventory & Recipes" description="Manage stock and map products to ingredient recipes." href="/admin/inventory" />
        <QuickLink title="Menu Management" description="Create categories and products sold at POS." href="/admin/menu" />
      </div>
    </div>
  );
}

function StatCard({ label, value, tone }: { label: string; value: string | number; tone: "red" | "amber" | "emerald" | "blue" }) {
  const toneClasses = {
    red: "border-red-100 bg-red-50 text-red-700",
    amber: "border-amber-100 bg-amber-50 text-amber-700",
    emerald: "border-emerald-100 bg-emerald-50 text-emerald-700",
    blue: "border-blue-100 bg-blue-50 text-blue-700",
  };

  return (
    <div className={`rounded-xl border p-4 ${toneClasses[tone]}`}>
      <p className="text-xs uppercase tracking-wide font-semibold">{label}</p>
      <p className="text-2xl font-bold mt-2">{value}</p>
    </div>
  );
}

function QuickLink({ title, description, href }: { title: string; description: string; href: string }) {
  return (
    <Link href={href} className="rounded-xl border border-gray-200 bg-white p-5 hover:shadow-sm transition-shadow">
      <p className="font-semibold text-gray-800">{title}</p>
      <p className="text-sm text-gray-500 mt-1">{description}</p>
    </Link>
  );
}
