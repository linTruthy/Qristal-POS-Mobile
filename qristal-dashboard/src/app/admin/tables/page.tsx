"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";

export default function TablesPage() {
  const { token } = useAuth();
  const [tables, setTables] = useState<any[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [form, setForm] = useState({ name: "", floor: "Main" });

  const fetchTables = async () => {
    if (!token) return;
    const res = await fetch(`${SERVER_URL}/tables`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    setTables(await res.json());
  };

  useEffect(() => { fetchTables(); }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/tables`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(form)
    });
    setIsModalOpen(false);
    setForm({ name: "", floor: "Main" });
    fetchTables();
  };

  const handleDelete = async (id: string) => {
    if(!confirm("Delete table?")) return;
    await fetch(`${SERVER_URL}/tables/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` }
    });
    fetchTables();
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Floor Plan</h1>
        <button onClick={() => setIsModalOpen(true)} className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow">+ Add Table</button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-4">
        {tables.map(t => (
          <div key={t.id} className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex flex-col items-center relative">
            <button onClick={() => handleDelete(t.id)} className="absolute top-2 right-2 text-red-400 hover:text-red-600">×</button>
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-3 text-blue-600">
                <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M3 14h18m-9-4v8m-7-4h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v2a2 2 0 002 2z" /></svg>
            </div>
            <h3 className="font-bold text-gray-900">{t.name}</h3>
            <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded mt-1">{t.floor}</span>
          </div>
        ))}
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-80">
            <h3 className="text-lg font-bold mb-4">Add Table</h3>
            <form onSubmit={handleSubmit}>
              <input placeholder="Table Name (e.g. T-1)" className="w-full border p-2 rounded mb-3"
                value={form.name} onChange={e => setForm({...form, name: e.target.value})} required />
              <input placeholder="Floor (e.g. Terrace)" className="w-full border p-2 rounded mb-4"
                value={form.floor} onChange={e => setForm({...form, floor: e.target.value})} />
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-3 py-1.5 text-gray-600">Cancel</button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}