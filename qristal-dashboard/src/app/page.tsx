"use client";

import withAuth from "@/components/withAuth";
import { useAuth } from "@/context/AuthContext";
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
import Link from "next/link";

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

type KdsLane = "KITCHEN" | "BARISTA" | "BAR" | "RETAIL" | "OTHER";

const KDS_LANES: KdsLane[] = ["KITCHEN", "BARISTA", "BAR", "RETAIL", "OTHER"];

type KitchenOrderItem = {
  id: string;
  name: string;
  quantity: number;
  lane: KdsLane;
  modifiers: string[];
  sides: string[];
  notes: string;
};

type KitchenOrder = {
  id: string;
  receiptNumber: string;
  status: string;
  tableId?: string | null;
  createdAt: string;
  totalAmount: number;
  items: KitchenOrderItem[];
};

type DashboardTab = "inventory" | "kds" | "reports";

function asLane(value: unknown): KdsLane {
  if (typeof value !== "string") return "KITCHEN";
  return KDS_LANES.includes(value as KdsLane) ? (value as KdsLane) : "OTHER";
}

function asStringList(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((entry) => String(entry)).filter(Boolean);
  if (typeof value === "string") {
    return value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function parseOrderItems(value: unknown): KitchenOrderItem[] {
  if (!Array.isArray(value)) return [];

  return value.map((raw, index) => {
    const item = raw as Record<string, unknown>;
    const product = (item.product as Record<string, unknown> | undefined) || {};

    const lane = asLane(item.productionArea ?? item.production_area ?? product.productionArea ?? product.production_area);

    return {
      id: String(item.id ?? `item-${index}`),
      name: String(item.name ?? item.productName ?? item.product_name ?? product.name ?? "Unnamed item"),
      quantity: Number(item.quantity ?? 1),
      lane,
      modifiers: asStringList(item.modifiers ?? item.modifierGroups ?? item.modifier_groups),
      sides: asStringList(item.sides),
      notes: String(item.notes ?? ""),
    } as KitchenOrderItem;
  });
}

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
        items: parseOrderItems(item.items ?? item.orderItems ?? item.order_items),
      } as KitchenOrder;
    })
    .filter((order) => order.id && ["KITCHEN", "PREPARING"].includes(order.status))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

function formatAge(createdAt: string): string {
  const diffMs = Date.now() - new Date(createdAt).getTime();
  const minutes = Math.max(0, Math.floor(diffMs / 60000));
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return `${hours}h ${rem}m ago`;
}

function Dashboard() {
  const { token, logout, user } = useAuth();
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [kitchenOrders, setKitchenOrders] = useState<KitchenOrder[]>([]);
  const [activeTab, setActiveTab] = useState<DashboardTab>("inventory");
  const [activeLane, setActiveLane] = useState<KdsLane | "ALL">("ALL");
  const [loading, setLoading] = useState(true);

  const fetchInventory = useCallback(async () => {
    if (!token) return;
    try {
      const response = await fetch(`${SERVER_URL}/inventory`, {
        cache: "no-store",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      if (response.status === 401) {
        logout();
        return;
      }
      const data = await response.json();
      setInventory(data);
    } catch (error) {
      console.error("Error fetching inventory:", error);
    }
  }, [token, logout]);

  const fetchKitchenOrders = useCallback(async () => {
    if (!token) return;
    try {
      for (const endpoint of ORDER_ENDPOINTS) {
        const response = await fetch(`${SERVER_URL}${endpoint}`, {
          cache: "no-store",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        if (response.status === 401) {
          logout();
          return;
        }
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
  }, [token, logout]);

  useEffect(() => {
    if (!token) return;
    void Promise.all([fetchInventory(), fetchKitchenOrders()]);

    const socket: Socket = io(SERVER_URL, {
      transports: ["websocket", "polling"],
      auth: { token: token },
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
  }, [fetchInventory, fetchKitchenOrders, token]);

  const kdsCounts = useMemo(() => {
    const allItems = kitchenOrders.flatMap((order) => order.items || []);

    return {
      kitchen: kitchenOrders.filter((order) => order.status === "KITCHEN").length,
      preparing: kitchenOrders.filter((order) => order.status === "PREPARING").length,
      byLane: allItems.reduce<Record<KdsLane, number>>(
        (acc, item) => {
          acc[item.lane] += item.quantity;
          return acc;
        },
        { KITCHEN: 0, BARISTA: 0, BAR: 0, RETAIL: 0, OTHER: 0 },
      ),
      totalItems: allItems.reduce((sum, item) => sum + item.quantity, 0),
    };
  }, [kitchenOrders]);

  const visibleOrders = useMemo(() => {
    if (activeLane === "ALL") return kitchenOrders;
    return kitchenOrders.filter((order) => (order.items || []).some((item) => item.lane === activeLane));
  }, [activeLane, kitchenOrders]);

  const laneBoard = useMemo(() => {
    const seed: Record<KdsLane, Array<{ order: KitchenOrder; item: KitchenOrderItem }>> = {
      KITCHEN: [],
      BARISTA: [],
      BAR: [],
      RETAIL: [],
      OTHER: [],
    };

    for (const order of kitchenOrders) {
      for (const item of order.items || []) {
        seed[item.lane].push({ order, item });
      }
    }

    return seed;
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
          <div className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow-sm flex items-center gap-4">
            <span className="font-semibold">{user?.name || "User"}</span>
            <button onClick={logout} className="bg-white/20 hover:bg-white/30 px-3 py-1 rounded text-sm transition-colors">Logout</button>
          </div>
        </header>

        <div className="mb-8 border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            <button
              className={`pb-3 text-sm font-semibold border-b-2 ${activeTab === "inventory"
                ? "border-blue-500 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
                }`}
              onClick={() => setActiveTab("inventory")}
            >
              Inventory
            </button>
            <button
              className={`pb-3 text-sm font-semibold border-b-2 ${activeTab === "kds"
                ? "border-blue-500 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
                }`}
              onClick={() => setActiveTab("kds")}
            >
              Web KDS
            </button>
            <Link href="/reports" className="pb-3 text-sm font-semibold border-b-2 border-transparent text-gray-500 hover:text-gray-700">Reports</Link>
          </nav>
        </div>

        {activeTab === "inventory" ? (
          <>
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 mb-6">
              <h2 className="text-xl font-bold text-gray-800 mb-4">Live Stock Overview</h2>
              <div className="h-72">
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
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">In Stock</span>
                        ) : (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">Low Stock</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        ) : activeTab === "kds" ? (
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
                <p className="text-sm text-gray-500">Total Active Items</p>
                <p className="text-3xl font-bold text-blue-600">{kdsCounts.totalItems}</p>
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
              <p className="text-sm text-gray-500 mb-3">Production lane routing (items)</p>
              <div className="flex flex-wrap gap-2">
                <button
                  onClick={() => setActiveLane("ALL")}
                  className={`px-3 py-1.5 rounded-full text-xs font-semibold border ${
                    activeLane === "ALL" ? "bg-blue-600 text-white border-blue-600" : "bg-white text-gray-600 border-gray-200"
                  }`}
                >
                  ALL ({kdsCounts.totalItems})
                </button>
                {KDS_LANES.map((lane) => (
                  <button
                    key={lane}
                    onClick={() => setActiveLane(lane)}
                    className={`px-3 py-1.5 rounded-full text-xs font-semibold border ${
                      activeLane === lane ? "bg-blue-600 text-white border-blue-600" : "bg-white text-gray-600 border-gray-200"
                    }`}
                  >
                    {lane} ({kdsCounts.byLane[lane]})
                  </button>
                ))}
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
              <h3 className="text-sm font-semibold text-gray-700 mb-3">Lane board (item tickets)</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-3">
                {KDS_LANES.map((lane) => {
                  const entries = laneBoard[lane];
                  return (
                    <div key={lane} className="border border-gray-100 rounded-lg p-3 bg-gray-50 min-h-[12rem]">
                      <div className="flex items-center justify-between mb-2">
                        <p className="font-semibold text-sm text-gray-800">{lane}</p>
                        <span className="text-xs px-2 py-0.5 rounded bg-white border border-gray-200 text-gray-600">{entries.length}</span>
                      </div>
                      <div className="space-y-2">
                        {entries.slice(0, 5).map(({ order, item }) => (
                          <div key={`${order.id}-${item.id}`} className="rounded border border-gray-200 bg-white p-2 text-xs">
                            <p className="font-semibold text-gray-800">#{order.receiptNumber}</p>
                            <p className="text-gray-700 mt-1">{item.quantity}x {item.name}</p>
                            <p className="text-gray-500 mt-1">{formatAge(order.createdAt)}</p>
                          </div>
                        ))}
                        {entries.length > 5 && (
                          <p className="text-xs text-gray-500">+{entries.length - 5} more</p>
                        )}
                        {entries.length === 0 && <p className="text-xs text-gray-400">No items</p>}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100">
                <h2 className="text-xl font-bold text-gray-800">Kitchen Display Queue</h2>
                <p className="text-sm text-gray-500 mt-1">Live view with station routing, modifiers, and sides when present in payload.</p>
              </div>
              {visibleOrders.length === 0 ? (
                <div className="p-8 text-center text-gray-500">No active orders for the selected lane.</div>
              ) : (
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Order #</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Table</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Routing Details</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {visibleOrders.map((order) => {
                      const displayItems = activeLane === "ALL" ? order.items : order.items.filter((item) => item.lane === activeLane);

                      return (
                        <tr key={order.id} className="hover:bg-gray-50 transition-colors align-top">
                          <td className="px-6 py-4 whitespace-nowrap font-semibold text-gray-900">{order.receiptNumber}</td>
                          <td className="px-6 py-4 whitespace-nowrap text-gray-500">{order.tableId || "Takeaway/Retail"}</td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span
                              className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${order.status === "PREPARING"
                                ? "bg-amber-100 text-amber-800"
                                : "bg-blue-100 text-blue-800"
                                }`}
                            >
                              {order.status}
                            </span>
                          </td>
                          <td className="px-6 py-4 text-sm text-gray-600">
                            {displayItems.length === 0 ? (
                              <span className="text-gray-400">No item metadata</span>
                            ) : (
                              <ul className="space-y-2">
                                {displayItems.map((item) => (
                                  <li key={item.id} className="border border-gray-100 rounded-lg p-2 bg-gray-50">
                                    <div className="font-medium text-gray-800">
                                      {item.quantity}x {item.name}
                                      <span className="ml-2 text-xs px-2 py-0.5 rounded bg-indigo-100 text-indigo-700">{item.lane}</span>
                                    </div>
                                    {item.modifiers.length > 0 && (
                                      <div className="text-xs mt-1">Modifiers: {item.modifiers.join(", ")}</div>
                                    )}
                                    {item.sides.length > 0 && <div className="text-xs mt-1">Sides: {item.sides.join(", ")}</div>}
                                    {item.notes && <div className="text-xs mt-1 text-gray-500">Notes: {item.notes}</div>}
                                  </li>
                                ))}
                              </ul>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-gray-700">UGX {order.totalAmount}</td>
                          <td className="px-6 py-4 whitespace-nowrap text-gray-500">{new Date(order.createdAt).toLocaleString()}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>
          </section>
        ) : null}
      </div>
    </main>
  );
}

export default withAuth(Dashboard);
