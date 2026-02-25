"use client";

import { useState, useEffect, useMemo, useCallback } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";
const RECIPE_STORAGE_KEY = "qristal.recipeMappings.v1";

interface InventoryItem {
  id: string;
  name: string;
  unitOfMeasure: string;
  currentStock: number;
  minimumStock: number;
  costPerUnit: number;
}

interface Product {
  id: string;
  name: string;
}

interface RecipeIngredient {
  inventoryId: string;
  inventoryName: string;
  unitOfMeasure: string;
  quantity: number;
  costPerUnit: number;
}

interface RecipeMap {
  productId: string;
  productName: string;
  ingredients: RecipeIngredient[];
  updatedAt: string;
}

export default function InventoryAdminPage() {
  const { token } = useAuth();
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [recipeMaps, setRecipeMaps] = useState<RecipeMap[]>(() => {
    if (typeof window === "undefined") return [];
    const raw = window.localStorage.getItem(RECIPE_STORAGE_KEY);
    if (!raw) return [];
    try {
      return JSON.parse(raw);
    } catch {
      return [];
    }
  });

  const [isItemModalOpen, setItemModalOpen] = useState(false);
  const [isRestockModalOpen, setRestockModalOpen] = useState(false);
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  const [itemForm, setItemForm] = useState({ name: "", unitOfMeasure: "kg", minimumStock: "", costPerUnit: "" });
  const [restockAmount, setRestockAmount] = useState("");

  const [selectedProductId, setSelectedProductId] = useState("");
  const [selectedInventoryId, setSelectedInventoryId] = useState("");
  const [ingredientQty, setIngredientQty] = useState("");

  const fetchData = useCallback(async () => {
    if (!token) return;
    const headers = { Authorization: `Bearer ${token}` };

    const [inventoryRes, productsRes] = await Promise.all([
      fetch(`${SERVER_URL}/inventory`, { headers }),
      fetch(`${SERVER_URL}/products`, { headers }),
    ]);

    setInventory(await inventoryRes.json());
    setProducts(await productsRes.json());
  }, [token]);

  useEffect(() => {
    if (!token) return;
    const timer = setTimeout(() => {
      void fetchData();
    }, 0);
    return () => clearTimeout(timer);
  }, [token, fetchData]);

  useEffect(() => {
    localStorage.setItem(RECIPE_STORAGE_KEY, JSON.stringify(recipeMaps));
  }, [recipeMaps]);

  const currentProduct = useMemo(
    () => products.find((item) => item.id === selectedProductId),
    [products, selectedProductId],
  );

  const editingRecipe = useMemo(() => {
    if (!currentProduct) return null;
    return recipeMaps.find((recipe) => recipe.productId === currentProduct.id) ?? null;
  }, [recipeMaps, currentProduct]);

  const recipeCost = useMemo(() => {
    const ingredients = editingRecipe?.ingredients ?? [];
    return ingredients.reduce((sum, item) => sum + item.quantity * item.costPerUnit, 0);
  }, [editingRecipe]);

  const handleItemSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/inventory`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(itemForm),
    });
    setItemModalOpen(false);
    setItemForm({ name: "", unitOfMeasure: "kg", minimumStock: "", costPerUnit: "" });
    void fetchData();
  };

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
    void fetchData();
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Remove this item from inventory?")) return;
    await fetch(`${SERVER_URL}/inventory/${id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    void fetchData();
  };

  const handleAddIngredient = () => {
    if (!selectedProductId || !selectedInventoryId || !ingredientQty) return;

    const qty = Number(ingredientQty);
    if (!qty || qty <= 0) return;

    const product = products.find((item) => item.id === selectedProductId);
    const inventoryItem = inventory.find((item) => item.id === selectedInventoryId);
    if (!product || !inventoryItem) return;

    setRecipeMaps((prev) => {
      const existing = prev.find((item) => item.productId === product.id);
      const ingredient: RecipeIngredient = {
        inventoryId: inventoryItem.id,
        inventoryName: inventoryItem.name,
        unitOfMeasure: inventoryItem.unitOfMeasure,
        quantity: qty,
        costPerUnit: Number(inventoryItem.costPerUnit),
      };

      if (!existing) {
        return [
          ...prev,
          {
            productId: product.id,
            productName: product.name,
            ingredients: [ingredient],
            updatedAt: new Date().toISOString(),
          },
        ];
      }

      const withoutIngredient = existing.ingredients.filter(
        (item) => item.inventoryId !== ingredient.inventoryId,
      );
      const updated: RecipeMap = {
        ...existing,
        ingredients: [...withoutIngredient, ingredient],
        updatedAt: new Date().toISOString(),
      };

      return prev.map((item) => (item.productId === existing.productId ? updated : item));
    });

    setIngredientQty("");
  };

  const handleRemoveIngredient = (productId: string, inventoryId: string) => {
    setRecipeMaps((prev) =>
      prev
        .map((recipe) =>
          recipe.productId === productId
            ? {
                ...recipe,
                ingredients: recipe.ingredients.filter(
                  (ingredient) => ingredient.inventoryId !== inventoryId,
                ),
                updatedAt: new Date().toISOString(),
              }
            : recipe,
        )
        .filter((recipe) => recipe.ingredients.length > 0),
    );
  };

  const handleDeleteRecipe = (productId: string) => {
    setRecipeMaps((prev) => prev.filter((recipe) => recipe.productId !== productId));
  };

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Inventory + Recipe Builder</h1>
          <p className="text-gray-500 text-sm">
            Maintain stock and map products to ingredient usage for better costing.
          </p>
        </div>
        <button
          onClick={() => setItemModalOpen(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow"
        >
          + Add Material
        </button>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-5 gap-6">
        <div className="xl:col-span-3 bg-white shadow rounded-lg overflow-hidden">
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
              {inventory.map((item) => (
                <tr key={item.id}>
                  <td className="px-6 py-4">
                    <div className="font-medium text-gray-900">{item.name}</div>
                    <div className="text-xs text-gray-500">Unit: {item.unitOfMeasure}</div>
                  </td>
                  <td className="px-6 py-4">
                    <span
                      className={`font-bold ${
                        item.currentStock <= item.minimumStock
                          ? "text-red-600"
                          : "text-green-600"
                      }`}
                    >
                      {Number(item.currentStock).toFixed(2)} {item.unitOfMeasure}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-500">{item.minimumStock}</td>
                  <td className="px-6 py-4 text-gray-500">UGX {item.costPerUnit}</td>
                  <td className="px-6 py-4 text-right space-x-4">
                    <button
                      onClick={() => {
                        setSelectedItem(item);
                        setRestockModalOpen(true);
                      }}
                      className="text-emerald-600 font-semibold hover:underline"
                    >
                      + Restock
                    </button>
                    <button
                      onClick={() => handleDelete(item.id)}
                      className="text-red-500 hover:underline"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="xl:col-span-2 bg-white border border-gray-100 rounded-lg p-5 space-y-4">
          <div>
            <h2 className="text-lg font-bold text-gray-800">Product Recipe Mapping</h2>
            <p className="text-xs text-gray-500 mt-1">
              Build product recipes from inventory ingredients.
            </p>
          </div>

          <div className="space-y-3">
            <div>
              <label className="text-xs font-semibold text-gray-600 uppercase">Product</label>
              <select
                className="mt-1 w-full border border-gray-300 rounded-md px-3 py-2"
                value={selectedProductId}
                onChange={(e) => setSelectedProductId(e.target.value)}
              >
                <option value="">Select product</option>
                {products.map((product) => (
                  <option key={product.id} value={product.id}>
                    {product.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs font-semibold text-gray-600 uppercase">Inventory Ingredient</label>
              <select
                className="mt-1 w-full border border-gray-300 rounded-md px-3 py-2"
                value={selectedInventoryId}
                onChange={(e) => setSelectedInventoryId(e.target.value)}
              >
                <option value="">Select ingredient</option>
                {inventory.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.name} ({item.unitOfMeasure})
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs font-semibold text-gray-600 uppercase">Quantity Used Per Product</label>
              <input
                type="number"
                step="0.01"
                min="0"
                className="mt-1 w-full border border-gray-300 rounded-md px-3 py-2"
                placeholder="0.00"
                value={ingredientQty}
                onChange={(e) => setIngredientQty(e.target.value)}
              />
            </div>

            <button
              onClick={handleAddIngredient}
              className="w-full bg-indigo-600 text-white px-3 py-2 rounded-md hover:bg-indigo-700"
            >
              Add / Update Ingredient in Recipe
            </button>
          </div>

          {currentProduct && (
            <div className="bg-gray-50 border border-gray-200 rounded-md p-3">
              <p className="text-sm font-semibold text-gray-700">Current Recipe: {currentProduct.name}</p>
              <p className="text-xs text-gray-500 mt-1">Estimated ingredient cost: UGX {recipeCost.toFixed(0)}</p>
              <div className="mt-2 space-y-2">
                {(editingRecipe?.ingredients ?? []).map((ingredient) => (
                  <div key={ingredient.inventoryId} className="flex items-center justify-between text-sm">
                    <div>
                      <p className="font-medium text-gray-800">{ingredient.inventoryName}</p>
                      <p className="text-xs text-gray-500">
                        {ingredient.quantity} {ingredient.unitOfMeasure} • UGX {(ingredient.quantity * ingredient.costPerUnit).toFixed(0)}
                      </p>
                    </div>
                    <button
                      onClick={() =>
                        handleRemoveIngredient(currentProduct.id, ingredient.inventoryId)
                      }
                      className="text-red-500 text-xs"
                    >
                      Remove
                    </button>
                  </div>
                ))}
                {!editingRecipe && (
                  <p className="text-xs text-gray-500">No ingredients mapped yet.</p>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="bg-white rounded-lg border border-gray-100 p-5">
        <h2 className="text-lg font-bold text-gray-800 mb-3">Saved Product Recipes</h2>
        {recipeMaps.length === 0 ? (
          <p className="text-sm text-gray-500">No recipe mappings saved yet.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {recipeMaps.map((recipe) => {
              const totalCost = recipe.ingredients.reduce(
                (sum, ingredient) => sum + ingredient.quantity * ingredient.costPerUnit,
                0,
              );
              return (
                <div key={recipe.productId} className="border border-gray-200 rounded-md p-3">
                  <div className="flex justify-between gap-3">
                    <div>
                      <p className="font-semibold text-gray-800">{recipe.productName}</p>
                      <p className="text-xs text-gray-500">Updated {new Date(recipe.updatedAt).toLocaleString()}</p>
                    </div>
                    <button
                      onClick={() => handleDeleteRecipe(recipe.productId)}
                      className="text-red-500 text-xs"
                    >
                      Delete
                    </button>
                  </div>
                  <ul className="mt-2 space-y-1 text-sm text-gray-700">
                    {recipe.ingredients.map((ingredient) => (
                      <li key={`${recipe.productId}-${ingredient.inventoryId}`}>
                        • {ingredient.inventoryName}: {ingredient.quantity} {ingredient.unitOfMeasure}
                      </li>
                    ))}
                  </ul>
                  <p className="text-xs font-semibold text-indigo-600 mt-2">
                    Estimated recipe cost: UGX {totalCost.toFixed(0)}
                  </p>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {isItemModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-4">New Material</h3>
            <form onSubmit={handleItemSubmit} className="space-y-3">
              <input
                placeholder="Name (e.g. Tomato, Ground Beef)"
                className="w-full border p-2 rounded"
                value={itemForm.name}
                onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })}
                required
              />

              <input
                placeholder="Unit of Measure (e.g. kg, liters, pcs)"
                className="w-full border p-2 rounded"
                value={itemForm.unitOfMeasure}
                onChange={(e) =>
                  setItemForm({ ...itemForm, unitOfMeasure: e.target.value })
                }
                required
              />

              <input
                placeholder="Minimum Stock Alert Level"
                type="number"
                step="0.01"
                className="w-full border p-2 rounded"
                value={itemForm.minimumStock}
                onChange={(e) =>
                  setItemForm({ ...itemForm, minimumStock: e.target.value })
                }
                required
              />

              <input
                placeholder="Cost Per Unit (UGX)"
                type="number"
                className="w-full border p-2 rounded"
                value={itemForm.costPerUnit}
                onChange={(e) =>
                  setItemForm({ ...itemForm, costPerUnit: e.target.value })
                }
                required
              />

              <div className="flex justify-end gap-2 mt-4">
                <button
                  type="button"
                  onClick={() => setItemModalOpen(false)}
                  className="px-3 py-1.5 text-gray-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-3 py-1.5 bg-blue-600 text-white rounded"
                >
                  Create Item
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isRestockModalOpen && selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-1">Restock</h3>
            <p className="text-gray-600 mb-4">
              {selectedItem.name} (Current: {Number(selectedItem.currentStock).toFixed(2)} {selectedItem.unitOfMeasure})
            </p>
            <form onSubmit={handleRestock}>
              <label className="text-sm font-medium">
                Add quantity ({selectedItem.unitOfMeasure})
              </label>
              <input
                type="number"
                step="0.01"
                min="0"
                autoFocus
                placeholder="0.00"
                className="w-full border p-2 rounded mb-4 mt-1 text-lg"
                value={restockAmount}
                onChange={(e) => setRestockAmount(e.target.value)}
                required
              />
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setRestockModalOpen(false);
                    setRestockAmount("");
                  }}
                  className="px-3 py-1.5 text-gray-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-3 py-1.5 bg-emerald-600 text-white rounded"
                >
                  + Add Stock
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
