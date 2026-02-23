
"use client";

import { useEffect, useState } from 'react';
import {
    LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell
} from 'recharts';
import { useAuth } from "@/context/AuthContext";
import withAuth from "@/components/withAuth";

const SERVER_URL = "https://qristal-pos-api.onrender.com";

function ReportsPage() {
    const { token, logout } = useAuth();
    const [salesData, setSalesData] = useState([]);
    const [topItems, setTopItems] = useState([]);
    const [paymentData, setPaymentData] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!token) return;

        const fetchData = async () => {
            try {
                const headers = { 'Authorization': `Bearer ${token}` };

                // 1. Sales
                const salesRes = await fetch(`${SERVER_URL}/reports/sales`, { headers });
                if (salesRes.status === 401) { logout(); return; }
                const salesJson = await salesRes.json();
                setSalesData(salesJson.map((d: any) => ({ ...d, date: new Date(d.date).toLocaleDateString() })));

                // 2. Top Items
                const itemsRes = await fetch(`${SERVER_URL}/reports/top-items`, { headers });
                setTopItems(await itemsRes.json());

                // 3. Payments
                const payRes = await fetch(`${SERVER_URL}/reports/payments`, { headers });
                setPaymentData(await payRes.json());
            } catch (error) {
                console.error("Error fetching report data", error);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [token, logout]);

    const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#AF19FF'];

    if (loading) return <div className="min-h-screen flex items-center justify-center">Loading Analytics...</div>;

    return (
        <div className="min-h-screen bg-gray-50 p-8">
            <h1 className="text-3xl font-bold mb-8 text-gray-800">Business Analytics</h1>

            {/* Grid Layout */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">

                {/* 1. Sales Trends (Line Chart) */}
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 col-span-2">
                    <h2 className="text-lg font-semibold mb-4">Sales Performance (Last 30 Days)</h2>
                    <div className="h-80">
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={salesData}>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                                <XAxis dataKey="date" />
                                <YAxis />
                                <Tooltip />
                                <Line type="monotone" dataKey="total" stroke="#0EA5E9" strokeWidth={3} dot={{ r: 4 }} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* 2. Top Selling Items (Bar Chart) */}
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="text-lg font-semibold mb-4">Top 5 Products</h2>
                    <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={topItems} layout="vertical" margin={{ left: 20 }}>
                                <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                                <XAxis type="number" />
                                <YAxis dataKey="name" type="category" width={100} tick={{ fontSize: 12 }} />
                                <Tooltip />
                                <Bar dataKey="quantity" fill="#10B981" radius={[0, 4, 4, 0]} barSize={20} />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* 3. Payment Methods (Pie Chart) */}
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="text-lg font-semibold mb-4">Revenue by Payment Type</h2>
                    <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={paymentData}
                                    cx="50%"
                                    cy="50%"
                                    innerRadius={60}
                                    outerRadius={80}
                                    paddingAngle={5}
                                    dataKey="_sum.amount"
                                    nameKey="method"
                                >
                                    {paymentData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                                    ))}
                                </Pie>
                                <Tooltip />
                                <Legend />
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                </div>

            </div>
        </div>
    );
}

export default withAuth(ReportsPage);