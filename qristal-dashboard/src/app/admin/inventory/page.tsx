"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";

interface InventoryItem {
  id: string;
  name: string;
  unitOfMeasure: string;
  currentStock: number;
  minimumStock: number;
  costPerUnit: number;
}

export default function InventoryAdminPage() {
  const { token } = useAuth();
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  
  // Modals
  const [isItemModalOpen, setItemModalOpen] = useState(false);
  const [isRestockModalOpen, setRestockModalOpen] = useState(false);
  
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  
  // Forms
  const [itemForm, setItemForm] = useState({ name: "", unitOfMeasure: "kg", minimumStock: "", costPerUnit: "" });
  const [restockAmount, setRestockAmount] = useState("");

  const fetchInventory = async () => {
    if (!token) return;
    const res = await fetch(`${SERVER_URL}/inventory`, { headers: { Authorization: `Bearer ${token}` }});
    setInventory(await res.json());
  };

  useEffect(() => { fetchInventory(); }, [token]);

  // Submit New Item
  const handleItemSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/inventory`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(itemForm),
    });
    setItemModalOpen(false);
    setItemForm({ name: "", unitOfMeasure: "kg", minimumStock: "", costPerUnit: "" });
    fetchInventory();
  };

  // Submit Restock
  const handleRestock = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedItem || !restockAmount) return;
    
    await fetch(`${SERVER_URL}/inventory/${selectedItem.id}/restock`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ amount: parseFloat(restockAmount) }),
    });
    
    setRestockModalOpen(false);
    setRestockAmount("");
    setSelectedItem(null);
    fetchInventory();
  };

  const handleDelete = async (id: string) => {
    if(!confirm("Remove this item from inventory?")) return;
    await fetch(`${SERVER_URL}/inventory/${id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` }
    });
    fetchInventory();
  };

  return (
    <div className="max-w-6xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Raw Material Inventory</h1>
          <p className="text-gray-500 text-sm">Manage stock levels for recipes.</p>
        </div>
        <button onClick={() => setItemModalOpen(true)} className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow">
          + Add Material
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Material Name</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Current Stock</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Min Level</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Unit Cost</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {inventory.map(item => (
              <tr key={item.id}>
                <td className="px-6 py-4">
                  <div className="font-medium text-gray-900">{item.name}</div>
                  <div className="text-xs text-gray-500">Unit: {item.unitOfMeasure}</div>
                </td>
                <td className="px-6 py-4">
                  <span className={`font-bold ${item.currentStock <= item.minimumStock ? 'text-red-600' : 'text-green-600'}`}>
                    {Number(item.currentStock).toFixed(2)} {item.unitOfMeasure}
                  </span>
                </td>
                <td className="px-6 py-4 text-gray-500">{item.minimumStock}</td>
                <td className="px-6 py-4 text-gray-500">UGX {item.costPerUnit}</td>
                <td className="px-6 py-4 text-right space-x-4">
                  <button 
                    onClick={() => { setSelectedItem(item); setRestockModalOpen(true); }} 
                    className="text-emerald-600 font-semibold hover:underline"
                  >
                    + Restock
                  </button>
                  <button onClick={() => handleDelete(item.id)} className="text-red-500 hover:underline">
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* NEW ITEM MODAL */}
      {isItemModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-4">New Material</h3>
            <form onSubmit={handleItemSubmit} className="space-y-3">
              <input placeholder="Name (e.g. Tomato, Ground Beef)" className="w-full border p-2 rounded" 
                value={itemForm.name} onChange={e => setItemForm({...itemForm, name: e.target.value})} required />
              
              <input placeholder="Unit of Measure (e.g. kg, liters, pcs)" className="w-full border p-2 rounded" 
                value={itemForm.unitOfMeasure} onChange={e => setItemForm({...itemForm, unitOfMeasure: e.target.value})} required />
              
              <input placeholder="Minimum Stock Alert Level" type="number" step="0.01" className="w-full border p-2 rounded" 
                value={itemForm.minimumStock} onChange={e => setItemForm({...itemForm, minimumStock: e.target.value})} required />
              
              <input placeholder="Cost Per Unit (UGX)" type="number" className="w-full border p-2 rounded" 
                value={itemForm.costPerUnit} onChange={e => setItemForm({...itemForm, costPerUnit: e.target.value})} required />

              <div className="flex justify-end gap-2 mt-4">
                <button type="button" onClick={() => setItemModalOpen(false)} className="px-3 py-1.5 text-gray-600">Cancel</button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">Create Item</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* RESTOCK MODAL */}
      {isRestockModalOpen && selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-1">Restock</h3>
            <p className="text-gray-600 mb-4">{selectedItem.name} (Current: {Number(selectedItem.currentStock).toFixed(2)} {selectedItem.unitOfMeasure})</p>
            <form onSubmit={handleRestock}>
              <label className="text-sm font-medium">Add quantity ({selectedItem.unitOfMeasure})</label>
              <input 
                type="number" step="0.01" min="0" autoFocus
                placeholder="0.00" 
                className="w-full border p-2 rounded mb-4 mt-1 text-lg" 
                value={restockAmount} onChange={e => setRestockAmount(e.target.value)} required 
              />
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => {setRestockModalOpen(false); setRestockAmount("")}} className="px-3 py-1.5 text-gray-600">Cancel</button>
                <button type="submit" className="px-3 py-1.5 bg-emerald-600 text-white rounded">+ Add Stock</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}