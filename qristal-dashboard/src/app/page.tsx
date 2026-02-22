"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";
import { io, Socket } from "socket.io-client";

const SERVER_URL = "https://qristal-pos-api.onrender.com";
const REFRESH_INTERVAL_MS = 10000;
const ORDER_ENDPOINTS = ["/orders", "/orders/kitchen", "/sync/pull?lastSyncTimestamp=1970-01-01T00:00:00.000Z"];

type InventoryItem = {
  id: string;
  name: string;
  sku?: string;
  unitOfMeasure: string;
  currentStock: number;
  minimumStock: number;
  costPerUnit: number;
};

type KitchenOrder = {
  id: string;
  receiptNumber: string;
  status: string;
  tableId?: string | null;
  createdAt: string;
  totalAmount: number;
};

type DashboardTab = "inventory" | "kds";

function normalizeKitchenOrders(payload: unknown): KitchenOrder[] {
  const body = payload as Record<string, unknown>;
  const list = Array.isArray(payload)
    ? payload
    : Array.isArray(body?.orders)
    ? body.orders
    : Array.isArray((body?.changes as Record<string, unknown> | undefined)?.orders)
    ? ((body?.changes as Record<string, unknown>).orders as unknown[])
    : [];

  return list
    .map((raw) => {
      const item = raw as Record<string, unknown>;
      return {
        id: String(item.id ?? ""),
        receiptNumber: String(item.receiptNumber ?? item.receipt_number ?? ""),
        status: String(item.status ?? ""),
        tableId: item.tableId ? String(item.tableId) : item.table_id ? String(item.table_id) : null,
        createdAt: String(item.createdAt ?? item.created_at ?? new Date().toISOString()),
        totalAmount: Number(item.totalAmount ?? item.total_amount ?? 0),
      } as KitchenOrder;
    })
    .filter((order) => order.id && ["KITCHEN", "PREPARING"].includes(order.status))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export default function Dashboard() {
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [kitchenOrders, setKitchenOrders] = useState<KitchenOrder[]>([]);
  const [activeTab, setActiveTab] = useState<DashboardTab>("inventory");
  const [loading, setLoading] = useState(true);

  const fetchInventory = useCallback(async () => {
    try {
      const response = await fetch(`${SERVER_URL}/inventory`, {
        cache: "no-store",
      });
      const data = await response.json();
      setInventory(data);
    } catch (error) {
      console.error("Error fetching inventory:", error);
    }
  }, []);

  const fetchKitchenOrders = useCallback(async () => {
    try {
      for (const endpoint of ORDER_ENDPOINTS) {
        const response = await fetch(`${SERVER_URL}${endpoint}`, {
          cache: "no-store",
        });
        if (!response.ok) continue;

        const data = await response.json();
        const normalized = normalizeKitchenOrders(data);
        if (normalized.length > 0 || endpoint === ORDER_ENDPOINTS[ORDER_ENDPOINTS.length - 1]) {
          setKitchenOrders(normalized);
          break;
        }
      }
    } catch (error) {
      console.error("Error fetching kitchen orders:", error);
      setKitchenOrders([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void Promise.all([fetchInventory(), fetchKitchenOrders()]);

    const socket: Socket = io(SERVER_URL, {
      transports: ["websocket", "polling"],
      reconnection: true,
    });

    socket.on("connect", () => {
      console.log("Dashboard connected to live server!");
    });

    socket.on("connect_error", (error) => {
      console.error(
        "Socket connection error, relying on polling fallback:",
        error.message,
      );
    });

    const handleInventoryUpdate = (updatedInventoryData: InventoryItem[]) => {
      setInventory(updatedInventoryData);
    };

    const refreshTimer = setInterval(() => {
      void fetchInventory();
      void fetchKitchenOrders();
    }, REFRESH_INTERVAL_MS);

    socket.on("inventoryUpdate", handleInventoryUpdate);
    socket.on("inventoryUpdated", handleInventoryUpdate);
    socket.on("newOrder", () => {
      void fetchKitchenOrders();
    });
    socket.on("orderUpdated", () => {
      void fetchKitchenOrders();
    });

    return () => {
      clearInterval(refreshTimer);
      socket.disconnect();
    };
  }, [fetchInventory, fetchKitchenOrders]);

  const kdsCounts = useMemo(() => {
    return {
      kitchen: kitchenOrders.filter((order) => order.status === "KITCHEN").length,
      preparing: kitchenOrders.filter((order) => order.status === "PREPARING").length,
    };
  }, [kitchenOrders]);

  if (loading) return <div className="p-8">Loading live data...</div>;

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">
        <header className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Qristal Dashboard</h1>
            <p className="text-gray-500">Owner portal with inventory and kitchen operations</p>
          </div>
          <div className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold shadow">
            Owner Portal
          </div>
        </header>

        <div className="mb-6 border-b border-gray-200">
          <nav className="-mb-px flex gap-6" aria-label="Dashboard sections">
            <button
              className={`pb-3 text-sm font-semibold border-b-2 ${
                activeTab === "inventory"
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
              onClick={() => setActiveTab("inventory")}
            >
              Inventory
            </button>
            <button
              className={`pb-3 text-sm font-semibold border-b-2 ${
                activeTab === "kds"
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
              onClick={() => setActiveTab("kds")}
            >
              Web KDS
            </button>
          </nav>
        </div>

        {activeTab === "inventory" ? (
          <>
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 mb-8">
              <h2 className="text-xl font-bold text-gray-800 mb-6">Current Stock Levels</h2>
              <div className="h-80 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={inventory} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="name" axisLine={false} tickLine={false} />
                    <YAxis axisLine={false} tickLine={false} />
                    <Tooltip cursor={{ fill: "#f3f4f6" }} />
                    <Legend />
                    <ReferenceLine y={20} label="Low Stock Warning" stroke="red" strokeDasharray="3 3" />
                    <Bar dataKey="currentStock" name="Current Stock" fill="#0EA5E9" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Item Name</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">SKU</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Unit</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Current Stock</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Unit Cost</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {inventory.map((item) => (
                    <tr key={item.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-4 whitespace-nowrap font-medium text-gray-900">{item.name}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-500">{item.sku || "N/A"}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-500">{item.unitOfMeasure}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">{item.currentStock}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-500">UGX {item.costPerUnit}</td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {item.currentStock > item.minimumStock ? (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                            In Stock
                          </span>
                        ) : (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">
                            Low Stock
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <section className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="bg-white border border-gray-100 rounded-xl p-4 shadow-sm">
                <p className="text-sm text-gray-500">Queued</p>
                <p className="text-3xl font-bold text-gray-900">{kdsCounts.kitchen}</p>
              </div>
              <div className="bg-white border border-gray-100 rounded-xl p-4 shadow-sm">
                <p className="text-sm text-gray-500">Preparing</p>
                <p className="text-3xl font-bold text-amber-600">{kdsCounts.preparing}</p>
              </div>
              <div className="bg-white border border-gray-100 rounded-xl p-4 shadow-sm">
                <p className="text-sm text-gray-500">Total Active</p>
                <p className="text-3xl font-bold text-blue-600">{kitchenOrders.length}</p>
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100">
                <h2 className="text-xl font-bold text-gray-800">Kitchen Display Queue</h2>
                <p className="text-sm text-gray-500 mt-1">Live view of KITCHEN and PREPARING orders</p>
              </div>
              {kitchenOrders.length === 0 ? (
                <div className="p-8 text-center text-gray-500">No active kitchen orders.</div>
              ) : (
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Order #</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Table</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {kitchenOrders.map((order) => (
                      <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap font-semibold text-gray-900">{order.receiptNumber}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-500">{order.tableId || "Takeaway/Retail"}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span
                            className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              order.status === "PREPARING"
                                ? "bg-amber-100 text-amber-800"
                                : "bg-blue-100 text-blue-800"
                            }`}
                          >
                            {order.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-700">UGX {order.totalAmount}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-500">
                          {new Date(order.createdAt).toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </section>
        )}
      </div>
    </main>
  );
}
