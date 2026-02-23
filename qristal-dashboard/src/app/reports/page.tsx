"use client";

import { useEffect, useState } from 'react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

// Mock token for dev (In real app, manage auth context)
const TOKEN = "YOUR_JWT_TOKEN_HERE";
const SERVER_URL = "https://qristal-pos-api.onrender.com";

export default function ReportsPage() {
    const [salesData, setSalesData] = useState([]);
    const [topItems, setTopItems] = useState([]);
    const [paymentData, setPaymentData] = useState([]);

    useEffect(() => {
        const fetchData = async () => {
            const headers = { 'Authorization': `Bearer ${TOKEN}` };

            // 1. Sales
            const salesRes = await fetch(`${SERVER_URL}/reports/sales`, { headers });
            const salesJson = await salesRes.json();
            // Format date for chart
            setSalesData(salesJson.map((d: any) => ({ ...d, date: new Date(d.date).toLocaleDateString() })));

            // 2. Top Items
            const itemsRes = await fetch(`${SERVER_URL}/reports/top-items`, { headers });
            setTopItems(await itemsRes.json());

            // 3. Payments
            const payRes = await fetch(`${SERVER_URL}/reports/payments`, { headers });
            setPaymentData(await payRes.json());
        };

        fetchData();
    }, []);

    const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042'];

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
                                <Line type="monotone" dataKey="total" stroke="#0EA5E9" strokeWidth={3} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* 2. Top Selling Items (Bar Chart) */}
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="text-lg font-semibold mb-4">Top 5 Products</h2>
                    <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={topItems} layout="vertical">
                                <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                                <XAxis type="number" />
                                <YAxis dataKey="name" type="category" width={100} />
                                <Tooltip />
                                <Bar dataKey="quantity" fill="#10B981" radius={[0, 4, 4, 0]} />
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