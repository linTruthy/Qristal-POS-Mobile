"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";

const SERVER_URL = "https://qristal-pos-api.onrender.com";
const PRODUCT_METADATA_KEY = "qristal-menu-product-metadata";
const MODIFIER_LIBRARY_KEY = "qristal-menu-modifier-library";
const SIDES_LIBRARY_KEY = "qristal-menu-sides-library";

type Category = {
  id: string;
  name: string;
  colorHex: string;
};

type Product = {
  id: string;
  name: string;
  price: number;
  categoryId: string;
  productionArea?: string;
  modifierGroups?: string[];
  sides?: string[];
};

type ProductMetadata = Record<
  string,
  {
    productionArea: string;
    modifierGroups: string[];
    sides: string[];
  }
>;

type ProductionArea = "KITCHEN" | "BARISTA" | "BAR" | "RETAIL" | "OTHER";

const PRODUCTION_AREAS: ProductionArea[] = ["KITCHEN", "BARISTA", "BAR", "RETAIL", "OTHER"];

export default function MenuPage() {
  const { token } = useAuth();
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);

  const [productMetadata, setProductMetadata] = useState<ProductMetadata>(() => {
    if (typeof window === "undefined") return {};
    try {
      return JSON.parse(localStorage.getItem(PRODUCT_METADATA_KEY) || "{}");
    } catch {
      return {};
    }
  });
  const [modifierLibrary, setModifierLibrary] = useState<string[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      return JSON.parse(localStorage.getItem(MODIFIER_LIBRARY_KEY) || "[]");
    } catch {
      return [];
    }
  });
  const [sidesLibrary, setSidesLibrary] = useState<string[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      return JSON.parse(localStorage.getItem(SIDES_LIBRARY_KEY) || "[]");
    } catch {
      return [];
    }
  });

  // Modals
  const [catModalOpen, setCatModalOpen] = useState(false);
  const [prodModalOpen, setProdModalOpen] = useState(false);

  // Forms
  const [catForm, setCatForm] = useState({ name: "", colorHex: "#3498db" });
  const [prodForm, setProdForm] = useState({
    name: "",
    price: "",
    categoryId: "",
    productionArea: "KITCHEN",
    modifierGroups: "",
    sides: "",
  });

  const [newModifier, setNewModifier] = useState("");
  const [newSide, setNewSide] = useState("");

  const fetchData = async () => {
    if (!token) return;
    const h = { Authorization: `Bearer ${token}` };

    const [cRes, pRes] = await Promise.all([
      fetch(`${SERVER_URL}/categories`, { headers: h }),
      fetch(`${SERVER_URL}/products`, { headers: h }),
    ]);

    setCategories(await cRes.json());
    setProducts(await pRes.json());
  };

  useEffect(() => {
    if (typeof window === "undefined") return;
    localStorage.setItem(PRODUCT_METADATA_KEY, JSON.stringify(productMetadata));
  }, [productMetadata]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    localStorage.setItem(MODIFIER_LIBRARY_KEY, JSON.stringify(modifierLibrary));
  }, [modifierLibrary]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    localStorage.setItem(SIDES_LIBRARY_KEY, JSON.stringify(sidesLibrary));
  }, [sidesLibrary]);

  useEffect(() => {
    if (!token) return;

    const h = { Authorization: `Bearer ${token}` };
    const load = async () => {
      const [cRes, pRes] = await Promise.all([
        fetch(`${SERVER_URL}/categories`, { headers: h }),
        fetch(`${SERVER_URL}/products`, { headers: h }),
      ]);

      setCategories(await cRes.json());
      setProducts(await pRes.json());
    };

    void load();
  }, [token]);

  const handleCatSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/categories`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(catForm),
    });
    setCatModalOpen(false);
    void fetchData();
  };

  const parseCsv = (value: string) =>
    value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

  const handleProdSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const modifierGroups = parseCsv(prodForm.modifierGroups);
    const sides = parseCsv(prodForm.sides);

    const payload = {
      name: prodForm.name,
      price: parseFloat(prodForm.price),
      categoryId: prodForm.categoryId,
      productionArea: prodForm.productionArea,
      modifierGroups,
      sides,
    };

    const response = await fetch(`${SERVER_URL}/products`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(payload),
    });

    const createdProduct = response.ok ? await response.json() : null;

    if (createdProduct?.id) {
      setProductMetadata((current) => ({
        ...current,
        [createdProduct.id]: {
          productionArea: prodForm.productionArea,
          modifierGroups,
          sides,
        },
      }));
    }

    setModifierLibrary((current) => {
      const merged = Array.from(new Set([...current, ...modifierGroups]));
      return merged.sort((a, b) => a.localeCompare(b));
    });

    setSidesLibrary((current) => {
      const merged = Array.from(new Set([...current, ...sides]));
      return merged.sort((a, b) => a.localeCompare(b));
    });

    setProdModalOpen(false);
    setProdForm({
      name: "",
      price: "",
      categoryId: "",
      productionArea: "KITCHEN",
      modifierGroups: "",
      sides: "",
    });

    void fetchData();
  };

  const handleDeleteProduct = async (id: string) => {
    if (!confirm("Delete this product?")) return;
    await fetch(`${SERVER_URL}/products/${id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });

    setProductMetadata((current) => {
      if (!current[id]) return current;
      const copy = { ...current };
      delete copy[id];
      return copy;
    });

    void fetchData();
  };

  const handleAddModifierToLibrary = () => {
    const value = newModifier.trim();
    if (!value) return;

    setModifierLibrary((current) => Array.from(new Set([...current, value])).sort((a, b) => a.localeCompare(b)));
    setNewModifier("");
  };

  const handleAddSideToLibrary = () => {
    const value = newSide.trim();
    if (!value) return;

    setSidesLibrary((current) => Array.from(new Set([...current, value])).sort((a, b) => a.localeCompare(b)));
    setNewSide("");
  };

  const resolveProductMeta = (product: Product) => {
    const localMeta = productMetadata[product.id];
    return {
      productionArea: localMeta?.productionArea || product.productionArea || "KITCHEN",
      modifierGroups: localMeta?.modifierGroups || product.modifierGroups || [],
      sides: localMeta?.sides || product.sides || [],
    };
  };

  const multiKdsCounts = products.reduce<Record<string, number>>((acc, product) => {
    const area = resolveProductMeta(product).productionArea;
    acc[area] = (acc[area] || 0) + 1;
    return acc;
  }, {});

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Menu, Modifiers & Production Routing</h1>
        <p className="text-sm text-gray-500 mt-1">
          Phase 1 foundation: configure modifiers/sides and assign products to Kitchen, Barista, Bar, Retail, or Other KDS lanes.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {PRODUCTION_AREAS.map((area) => (
          <div key={area} className="rounded-xl border border-gray-200 bg-white px-4 py-3">
            <p className="text-xs font-semibold tracking-wide text-gray-500">{area}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">{multiKdsCounts[area] || 0}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="space-y-8">
          <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-bold">Categories</h2>
              <button onClick={() => setCatModalOpen(true)} className="text-blue-600 text-sm font-semibold">+ New</button>
            </div>
            <div className="space-y-2">
              {categories.map((cat) => (
                <div key={cat.id} className="flex items-center p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <div className="w-4 h-4 rounded-full mr-3" style={{ backgroundColor: cat.colorHex }}></div>
                  <span className="font-medium text-gray-700">{cat.name}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 space-y-5">
            <h2 className="text-lg font-bold">Modifier & Side Libraries</h2>

            <div>
              <p className="text-sm font-semibold text-gray-700 mb-2">Modifier groups</p>
              <div className="flex gap-2 mb-2">
                <input
                  value={newModifier}
                  onChange={(e) => setNewModifier(e.target.value)}
                  placeholder="e.g. Sugar level, Milk choice"
                  className="flex-1 border p-2 rounded"
                />
                <button type="button" onClick={handleAddModifierToLibrary} className="px-3 py-2 bg-blue-600 text-white rounded">
                  Add
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {modifierLibrary.map((item) => (
                  <span key={item} className="px-2 py-1 bg-indigo-50 text-indigo-700 rounded text-xs font-medium">
                    {item}
                  </span>
                ))}
              </div>
            </div>

            <div>
              <p className="text-sm font-semibold text-gray-700 mb-2">Sides</p>
              <div className="flex gap-2 mb-2">
                <input
                  value={newSide}
                  onChange={(e) => setNewSide(e.target.value)}
                  placeholder="e.g. Chips, Side salad"
                  className="flex-1 border p-2 rounded"
                />
                <button type="button" onClick={handleAddSideToLibrary} className="px-3 py-2 bg-blue-600 text-white rounded">
                  Add
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {sidesLibrary.map((item) => (
                  <span key={item} className="px-2 py-1 bg-emerald-50 text-emerald-700 rounded text-xs font-medium">
                    {item}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-bold">Products</h2>
            <button onClick={() => setProdModalOpen(true)} className="bg-blue-600 text-white px-3 py-1.5 rounded text-sm hover:bg-blue-700">
              + New Product
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="text-left text-xs text-gray-500 uppercase border-b">
                  <th className="pb-2">Name</th>
                  <th className="pb-2">Category</th>
                  <th className="pb-2">Price</th>
                  <th className="pb-2">Production</th>
                  <th className="pb-2">Modifiers</th>
                  <th className="pb-2">Sides</th>
                  <th className="pb-2">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {products.map((p) => {
                  const meta = resolveProductMeta(p);
                  return (
                    <tr key={p.id}>
                      <td className="py-3 font-medium">{p.name}</td>
                      <td className="py-3 text-sm text-gray-500">{categories.find((c) => c.id === p.categoryId)?.name || "Unknown"}</td>
                      <td className="py-3">UGX {p.price}</td>
                      <td className="py-3">
                        <span className="px-2 py-1 rounded bg-amber-50 text-amber-700 text-xs font-semibold">{meta.productionArea}</span>
                      </td>
                      <td className="py-3 text-xs text-gray-600">{meta.modifierGroups.length ? meta.modifierGroups.join(", ") : "—"}</td>
                      <td className="py-3 text-xs text-gray-600">{meta.sides.length ? meta.sides.join(", ") : "—"}</td>
                      <td className="py-3 text-sm text-red-500 cursor-pointer" onClick={() => handleDeleteProduct(p.id)}>
                        Delete
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {catModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-96">
            <h3 className="text-lg font-bold mb-4">New Category</h3>
            <form onSubmit={handleCatSubmit}>
              <input
                placeholder="Category Name"
                className="w-full border p-2 rounded mb-3"
                value={catForm.name}
                onChange={(e) => setCatForm({ ...catForm, name: e.target.value })}
                required
              />
              <input
                type="color"
                className="w-full h-10 p-1 border rounded mb-4"
                value={catForm.colorHex}
                onChange={(e) => setCatForm({ ...catForm, colorHex: e.target.value })}
              />
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setCatModalOpen(false)} className="px-3 py-1.5 text-gray-600">
                  Cancel
                </button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {prodModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 w-[30rem]">
            <h3 className="text-lg font-bold mb-4">New Product</h3>
            <form onSubmit={handleProdSubmit}>
              <input
                placeholder="Product Name"
                className="w-full border p-2 rounded mb-3"
                value={prodForm.name}
                onChange={(e) => setProdForm({ ...prodForm, name: e.target.value })}
                required
              />

              <input
                placeholder="Price (UGX)"
                type="number"
                className="w-full border p-2 rounded mb-3"
                value={prodForm.price}
                onChange={(e) => setProdForm({ ...prodForm, price: e.target.value })}
                required
              />

              <select
                className="w-full border p-2 rounded mb-3"
                value={prodForm.categoryId}
                onChange={(e) => setProdForm({ ...prodForm, categoryId: e.target.value })}
                required
              >
                <option value="">Select Category</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>

              <select
                className="w-full border p-2 rounded mb-3"
                value={prodForm.productionArea}
                onChange={(e) => setProdForm({ ...prodForm, productionArea: e.target.value })}
              >
                {PRODUCTION_AREAS.map((area) => (
                  <option key={area} value={area}>
                    {area}
                  </option>
                ))}
              </select>

              <input
                placeholder="Modifier groups (comma-separated)"
                className="w-full border p-2 rounded mb-3"
                value={prodForm.modifierGroups}
                onChange={(e) => setProdForm({ ...prodForm, modifierGroups: e.target.value })}
              />

              <input
                placeholder="Sides (comma-separated)"
                className="w-full border p-2 rounded mb-4"
                value={prodForm.sides}
                onChange={(e) => setProdForm({ ...prodForm, sides: e.target.value })}
              />

              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setProdModalOpen(false)} className="px-3 py-1.5 text-gray-600">
                  Cancel
                </button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
