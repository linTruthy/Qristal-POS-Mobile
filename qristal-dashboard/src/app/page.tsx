"use client";

import { useCallback, useEffect, useState } from 'react';
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
} from 'recharts';
import { io, Socket } from 'socket.io-client';

const SERVER_URL = 'https://qristal-pos-api.onrender.com';
const REFRESH_INTERVAL_MS = 10000;

type InventoryItem = {
  id: string;
  name: string;
  sku?: string;
  unitOfMeasure: string;
  currentStock: number;
  minimumStock: number;
  costPerUnit: number;
};

export default function Dashboard() {
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchInventory = useCallback(async () => {
    try {
      const response = await fetch(`${SERVER_URL}/inventory`, {
        cache: 'no-store',
      });
      const data = await response.json();
      setInventory(data);
    } catch (error) {
      console.error('Error fetching inventory:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchInventory();

    const socket: Socket = io(SERVER_URL, {
      transports: ['websocket', 'polling'],
      reconnection: true,
    });

    socket.on('connect', () => {
      console.log('Dashboard connected to live server!');
    });

    socket.on('connect_error', (error) => {
      console.error('Socket connection error, relying on polling fallback:', error.message);
    });

    const handleInventoryUpdate = (updatedInventoryData: InventoryItem[]) => {
      console.log('⚡ Real-time inventory update received!');
      setInventory(updatedInventoryData);
    };

    // Support both common event names to avoid missing updates because of naming mismatch.
    socket.on('inventoryUpdate', handleInventoryUpdate);
    socket.on('inventoryUpdated', handleInventoryUpdate);

    const refreshTimer = setInterval(() => {
      void fetchInventory();
    }, REFRESH_INTERVAL_MS);

    return () => {
      clearInterval(refreshTimer);
      socket.disconnect();
    };
  }, [fetchInventory]);

  if (loading) return <div className="p-8">Loading live data...</div>;

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <header className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Qristal Dashboard</h1>
            <p className="text-gray-500">Real-time inventory & analytics</p>
          </div>
          <div className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold shadow">
            Owner Portal
          </div>
        </header>

        {/* Chart Section */}
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 mb-8">
          <h2 className="text-xl font-bold text-gray-800 mb-6">Current Stock Levels</h2>
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={inventory} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="name" axisLine={false} tickLine={false} />
                <YAxis axisLine={false} tickLine={false} />
                <Tooltip cursor={{ fill: '#f3f4f6' }} />
                <Legend />
                {/* Red line showing minimum safe stock level at 20 */}
                <ReferenceLine y={20} label="Low Stock Warning" stroke="red" strokeDasharray="3 3" />
                <Bar dataKey="currentStock" name="Current Stock" fill="#0EA5E9" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Data Table Section */}
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
                  <td className="px-6 py-4 whitespace-nowrap text-gray-500">{item.sku || 'N/A'}</td>
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
      </div>
    </main>
  );
}
