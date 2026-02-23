"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";

export default function MenuPage() {
  const { token } = useAuth();
  const [categories, setCategories] = useState<any[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  
  // Modals
  const [catModalOpen, setCatModalOpen] = useState(false);
  const [prodModalOpen, setProdModalOpen] = useState(false);
  
  // Forms
  const [catForm, setCatForm] = useState({ name: "", colorHex: "#3498db" });
  const [prodForm, setProdForm] = useState({ name: "", price: "", categoryId: "" });

  const fetchData = async () => {
    if (!token) return;
    const h = { Authorization: `Bearer ${token}` };
    
    const [cRes, pRes] = await Promise.all([
      fetch(`${SERVER_URL}/categories`, { headers: h }),
      fetch(`${SERVER_URL}/products`, { headers: h })
    ]);

    setCategories(await cRes.json());
    setProducts(await pRes.json());
  };

  useEffect(() => { fetchData(); }, [token]);

  // Handlers
  const handleCatSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/categories`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(catForm)
    });
    setCatModalOpen(false);
    fetchData();
  };

  const handleProdSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/products`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ ...prodForm, price: parseFloat(prodForm.price) })
    });
    setProdModalOpen(false);
    fetchData();
  };

  const handleDeleteProduct = async (id: string) => {
    if(!confirm("Delete this product?")) return;
    await fetch(`${SERVER_URL}/products/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
    });
    fetchData();
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
      
      {/* LEFT: Categories */}
      <div className="lg:col-span-1 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-bold">Categories</h2>
          <button onClick={() => setCatModalOpen(true)} className="text-blue-600 text-sm font-semibold">+ New</button>
        </div>
        <div className="space-y-2">
          {categories.map(cat => (
            <div key={cat.id} className="flex items-center p-3 bg-gray-50 rounded-lg border border-gray-100">
              <div className="w-4 h-4 rounded-full mr-3" style={{ backgroundColor: cat.colorHex }}></div>
              <span className="font-medium text-gray-700">{cat.name}</span>
            </div>
          ))}
        </div>
      </div>

      {/* RIGHT: Products */}
      <div className="lg:col-span-2 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-bold">Products</h2>
          <button onClick={() => setProdModalOpen(true)} className="bg-blue-600 text-white px-3 py-1.5 rounded text-sm hover:bg-blue-700">+ New Product</button>
        </div>
        
        <table className="min-w-full">
          <thead>
            <tr className="text-left text-xs text-gray-500 uppercase border-b">
              <th className="pb-2">Name</th>
              <th className="pb-2">Category</th>
              <th className="pb-2">Price</th>
              <th className="pb-2">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {products.map(p => (
              <tr key={p.id}>
                <td className="py-3">{p.name}</td>
                <td className="py-3 text-sm text-gray-500">{categories.find(c => c.id === p.categoryId)?.name || 'Unknown'}</td>
                <td className="py-3 font-medium">UGX {p.price}</td>
                <td className="py-3 text-sm text-red-500 cursor-pointer" onClick={() => handleDeleteProduct(p.id)}>Delete</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Category Modal */}
      {catModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-4">New Category</h3>
            <form onSubmit={handleCatSubmit}>
              <input placeholder="Category Name" className="w-full border p-2 rounded mb-3" 
                value={catForm.name} onChange={e => setCatForm({...catForm, name: e.target.value})} required />
              <input type="color" className="w-full h-10 p-1 border rounded mb-4" 
                value={catForm.colorHex} onChange={e => setCatForm({...catForm, colorHex: e.target.value})} />
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setCatModalOpen(false)} className="px-3 py-1.5 text-gray-600">Cancel</button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Product Modal */}
      {prodModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-4">New Product</h3>
            <form onSubmit={handleProdSubmit}>
              <input placeholder="Product Name" className="w-full border p-2 rounded mb-3"
                value={prodForm.name} onChange={e => setProdForm({...prodForm, name: e.target.value})} required />
              
              <input placeholder="Price (UGX)" type="number" className="w-full border p-2 rounded mb-3"
                value={prodForm.price} onChange={e => setProdForm({...prodForm, price: e.target.value})} required />
              
              <select className="w-full border p-2 rounded mb-4"
                value={prodForm.categoryId} onChange={e => setProdForm({...prodForm, categoryId: e.target.value})} required>
                <option value="">Select Category</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>

              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setProdModalOpen(false)} className="px-3 py-1.5 text-gray-600">Cancel</button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}