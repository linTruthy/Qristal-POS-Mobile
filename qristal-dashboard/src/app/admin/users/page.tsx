"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";

interface UserItem {
  id: string;
  fullName: string;
  role: string;
  isActive: boolean;
}

export default function UsersPage() {
  const { token } = useAuth();
  const [users, setUsers] = useState<UserItem[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Form State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ fullName: "", role: "WAITER", pin: "1234" });

  const fetchUsers = async () => {
    try {
      const res = await fetch(`${SERVER_URL}/users`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) setUsers(await res.json());
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (token) fetchUsers();
  }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const method = editId ? "PUT" : "POST";
    const url = editId ? `${SERVER_URL}/users/${editId}` : `${SERVER_URL}/users`;

    await fetch(url, {
      method,
      headers: { 
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}` 
      },
      body: JSON.stringify(formData),
    });

    setIsModalOpen(false);
    setEditId(null);
    setFormData({ fullName: "", role: "WAITER", pin: "" });
    fetchUsers();
  };

  const handleDelete = async (id: string) => {
    if(!confirm("Are you sure? This effectively disables access.")) return;
    await fetch(`${SERVER_URL}/users/${id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    fetchUsers();
  }

  const openEdit = (user: UserItem) => {
    setEditId(user.id);
    setFormData({ fullName: user.fullName, role: user.role, pin: "" }); // Blank PIN on edit
    setIsModalOpen(true);
  };

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Staff Management</h1>
        <button
          onClick={() => { setEditId(null); setFormData({ fullName: "", role: "WAITER", pin: "" }); setIsModalOpen(true); }}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow hover:bg-blue-700"
        >
          + Add Staff
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {users.map((u) => (
              <tr key={u.id}>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{u.fullName}</td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{u.role}</td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${u.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {u.isActive ? 'Active' : 'Disabled'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button onClick={() => openEdit(u)} className="text-blue-600 hover:text-blue-900 mr-4">Edit</button>
                  <button onClick={() => handleDelete(u.id)} className="text-red-600 hover:text-red-900">Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* MODAL */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">{editId ? 'Edit Staff' : 'New Staff'}</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Full Name</label>
                <input required type="text" className="mt-1 block w-full border border-gray-300 rounded-md p-2"
                  value={formData.fullName} onChange={e => setFormData({ ...formData, fullName: e.target.value })} />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Role</label>
                <select className="mt-1 block w-full border border-gray-300 rounded-md p-2"
                  value={formData.role} onChange={e => setFormData({ ...formData, role: e.target.value })}>
                  <option value="WAITER">Waiter</option>
                  <option value="CASHIER">Cashier</option>
                  <option value="KITCHEN">Kitchen</option>
                  <option value="MANAGER">Manager</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">PIN (4 Digits)</label>
                <input type="text" className="mt-1 block w-full border border-gray-300 rounded-md p-2"
                  placeholder={editId ? "Leave blank to keep current" : "e.g. 1234"}
                  value={formData.pin} onChange={e => setFormData({ ...formData, pin: e.target.value })} 
                  required={!editId}
                />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-md">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}