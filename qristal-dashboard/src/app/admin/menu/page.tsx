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
    productionArea: ProductionArea;
    modifierGroups: string[];
    sides: string[];
  }
>;

type ProductionArea = "KITCHEN" | "BARISTA" | "BAR" | "RETAIL" | "OTHER";

type ProductFormState = {
  name: string;
  price: string;
  categoryId: string;
  productionArea: ProductionArea;
  modifierGroups: string;
  sides: string;
};

const PRODUCTION_AREAS: ProductionArea[] = ["KITCHEN", "BARISTA", "BAR", "RETAIL", "OTHER"];

const EMPTY_PRODUCT_FORM: ProductFormState = {
  name: "",
  price: "",
  categoryId: "",
  productionArea: "KITCHEN",
  modifierGroups: "",
  sides: "",
};

const parseCsv = (value: string) =>
  Array.from(
    new Set(
      value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
    ),
  );

const asProductionArea = (value: string | undefined): ProductionArea => {
  if (!value) return "KITCHEN";
  return PRODUCTION_AREAS.includes(value as ProductionArea) ? (value as ProductionArea) : "OTHER";
};

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

  const [catModalOpen, setCatModalOpen] = useState(false);
  const [prodModalOpen, setProdModalOpen] = useState(false);
  const [editingProductId, setEditingProductId] = useState<string | null>(null);

  const [catForm, setCatForm] = useState({ name: "", colorHex: "#3498db" });
  const [prodForm, setProdForm] = useState<ProductFormState>(EMPTY_PRODUCT_FORM);

  const [newModifier, setNewModifier] = useState("");
  const [newSide, setNewSide] = useState("");
  const [feedback, setFeedback] = useState<{ type: "success" | "warning" | "error"; message: string } | null>(null);

  const syncLibrariesFromProducts = (items: Product[]) => {
    const productModifiers = items.flatMap((item) => item.modifierGroups || []);
    const productSides = items.flatMap((item) => item.sides || []);

    setModifierLibrary((current) => Array.from(new Set([...current, ...productModifiers])).sort((a, b) => a.localeCompare(b)));
    setSidesLibrary((current) => Array.from(new Set([...current, ...productSides])).sort((a, b) => a.localeCompare(b)));
  };

  const fetchData = async () => {
    if (!token) return;
    const headers = { Authorization: `Bearer ${token}` };

    const [categoriesRes, productsRes] = await Promise.all([
      fetch(`${SERVER_URL}/categories`, { headers }),
      fetch(`${SERVER_URL}/products`, { headers }),
    ]);

    const categoriesData: Category[] = await categoriesRes.json();
    const productsData: Product[] = await productsRes.json();

    setCategories(categoriesData);
    setProducts(productsData);
    syncLibrariesFromProducts(productsData);
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

    const headers = { Authorization: `Bearer ${token}` };
    const load = async () => {
      const [categoriesRes, productsRes] = await Promise.all([
        fetch(`${SERVER_URL}/categories`, { headers }),
        fetch(`${SERVER_URL}/products`, { headers }),
      ]);

      const categoriesData: Category[] = await categoriesRes.json();
      const productsData: Product[] = await productsRes.json();

      setCategories(categoriesData);
      setProducts(productsData);
      syncLibrariesFromProducts(productsData);
    };

    void load();
  }, [token]);

  const closeProductModal = () => {
    setProdModalOpen(false);
    setEditingProductId(null);
    setProdForm(EMPTY_PRODUCT_FORM);
  };

  const resolveProductMeta = (product: Product) => {
    const localMeta = productMetadata[product.id];
    return {
      productionArea: localMeta?.productionArea || asProductionArea(product.productionArea),
      modifierGroups: localMeta?.modifierGroups || product.modifierGroups || [],
      sides: localMeta?.sides || product.sides || [],
    };
  };

  const openCreateProduct = () => {
    setEditingProductId(null);
    setProdForm(EMPTY_PRODUCT_FORM);
    setProdModalOpen(true);
  };

  const openEditProduct = (product: Product) => {
    const meta = resolveProductMeta(product);
    setEditingProductId(product.id);
    setProdForm({
      name: product.name,
      price: String(product.price),
      categoryId: product.categoryId,
      productionArea: meta.productionArea,
      modifierGroups: meta.modifierGroups.join(", "),
      sides: meta.sides.join(", "),
    });
    setProdModalOpen(true);
  };

  const handleCatSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await fetch(`${SERVER_URL}/categories`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(catForm),
    });
    setCatModalOpen(false);
    setCatForm({ name: "", colorHex: "#3498db" });
    void fetchData();
  };

  const saveMetadataFallback = (productId: string, metadata: ProductMetadata[string]) => {
    setProductMetadata((current) => ({ ...current, [productId]: metadata }));
    setFeedback({
      type: "warning",
      message:
        "Saved locally only: product endpoint did not accept routing/modifier updates yet. Data is stored in this browser until backend support is enabled.",
    });
  };

  const handleProdSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFeedback(null);

    const modifierGroups = parseCsv(prodForm.modifierGroups);
    const sides = parseCsv(prodForm.sides);

    const payload = {
      name: prodForm.name,
      price: Number(prodForm.price),
      categoryId: prodForm.categoryId,
      productionArea: prodForm.productionArea,
      modifierGroups,
      sides,
    };

    if (Number.isNaN(payload.price) || payload.price <= 0) {
      setFeedback({ type: "error", message: "Please provide a valid product price." });
      return;
    }

    const metadataPayload = {
      productionArea: prodForm.productionArea,
      modifierGroups,
      sides,
    };

    if (editingProductId) {
      const headers = { "Content-Type": "application/json", Authorization: `Bearer ${token}` };
      let updateRes = await fetch(`${SERVER_URL}/products/${editingProductId}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify(payload),
      });

      if (!updateRes.ok) {
        updateRes = await fetch(`${SERVER_URL}/products/${editingProductId}`, {
          method: "PUT",
          headers,
          body: JSON.stringify(payload),
        });
      }

      if (!updateRes.ok) {
        saveMetadataFallback(editingProductId, metadataPayload);
      } else {
        setProductMetadata((current) => {
          const copy = { ...current };
          delete copy[editingProductId];
          return copy;
        });
        setFeedback({ type: "success", message: "Product updated successfully." });
      }
    } else {
      const createRes = await fetch(`${SERVER_URL}/products`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify(payload),
      });

      const createdProduct = createRes.ok ? await createRes.json() : null;

      if (!createRes.ok) {
        setFeedback({ type: "error", message: "Unable to create product. Please retry." });
        return;
      }

      if (createdProduct?.id) {
        setProductMetadata((current) => ({ ...current, [createdProduct.id]: metadataPayload }));
      }

      setFeedback({ type: "success", message: "Product created successfully." });
    }

    setModifierLibrary((current) => Array.from(new Set([...current, ...modifierGroups])).sort((a, b) => a.localeCompare(b)));
    setSidesLibrary((current) => Array.from(new Set([...current, ...sides])).sort((a, b) => a.localeCompare(b)));

    closeProductModal();
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

  const pushLibraryToken = (scope: "modifier" | "side", tokenValue: string) => {
    if (scope === "modifier") {
      const next = Array.from(new Set([...parseCsv(prodForm.modifierGroups), tokenValue]));
      setProdForm((current) => ({ ...current, modifierGroups: next.join(", ") }));
      return;
    }

    const next = Array.from(new Set([...parseCsv(prodForm.sides), tokenValue]));
    setProdForm((current) => ({ ...current, sides: next.join(", ") }));
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
        <p className="text-sm text-gray-500 mt-1">Next increment: edit existing products and try server persistence first, local fallback second.</p>
      </div>

      {feedback && (
        <div
          className={`rounded-lg border px-4 py-3 text-sm ${
            feedback.type === "success"
              ? "bg-emerald-50 border-emerald-200 text-emerald-700"
              : feedback.type === "warning"
                ? "bg-amber-50 border-amber-200 text-amber-700"
                : "bg-red-50 border-red-200 text-red-700"
          }`}
        >
          {feedback.message}
        </div>
      )}

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
              <button onClick={() => setCatModalOpen(true)} className="text-blue-600 text-sm font-semibold">
                + New
              </button>
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
                <input value={newModifier} onChange={(e) => setNewModifier(e.target.value)} placeholder="e.g. Sugar level" className="flex-1 border p-2 rounded" />
                <button
                  type="button"
                  onClick={() => {
                    const value = newModifier.trim();
                    if (!value) return;
                    setModifierLibrary((current) => Array.from(new Set([...current, value])).sort((a, b) => a.localeCompare(b)));
                    setNewModifier("");
                  }}
                  className="px-3 py-2 bg-blue-600 text-white rounded"
                >
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
                <input value={newSide} onChange={(e) => setNewSide(e.target.value)} placeholder="e.g. Chips" className="flex-1 border p-2 rounded" />
                <button
                  type="button"
                  onClick={() => {
                    const value = newSide.trim();
                    if (!value) return;
                    setSidesLibrary((current) => Array.from(new Set([...current, value])).sort((a, b) => a.localeCompare(b)));
                    setNewSide("");
                  }}
                  className="px-3 py-2 bg-blue-600 text-white rounded"
                >
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
            <button onClick={openCreateProduct} className="bg-blue-600 text-white px-3 py-1.5 rounded text-sm hover:bg-blue-700">
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
                {products.map((product) => {
                  const meta = resolveProductMeta(product);
                  return (
                    <tr key={product.id}>
                      <td className="py-3 font-medium">{product.name}</td>
                      <td className="py-3 text-sm text-gray-500">{categories.find((c) => c.id === product.categoryId)?.name || "Unknown"}</td>
                      <td className="py-3">UGX {product.price}</td>
                      <td className="py-3">
                        <span className="px-2 py-1 rounded bg-amber-50 text-amber-700 text-xs font-semibold">{meta.productionArea}</span>
                      </td>
                      <td className="py-3 text-xs text-gray-600">{meta.modifierGroups.length ? meta.modifierGroups.join(", ") : "—"}</td>
                      <td className="py-3 text-xs text-gray-600">{meta.sides.length ? meta.sides.join(", ") : "—"}</td>
                      <td className="py-3 text-sm">
                        <button onClick={() => openEditProduct(product)} className="text-blue-600 hover:text-blue-800 mr-3">
                          Edit
                        </button>
                        <button onClick={() => handleDeleteProduct(product.id)} className="text-red-500 hover:text-red-700">
                          Delete
                        </button>
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
          <div className="bg-white rounded-lg p-6 w-[36rem] max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-bold mb-4">{editingProductId ? "Edit Product" : "New Product"}</h3>
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
                onChange={(e) => setProdForm({ ...prodForm, productionArea: asProductionArea(e.target.value) })}
              >
                {PRODUCTION_AREAS.map((area) => (
                  <option key={area} value={area}>
                    {area}
                  </option>
                ))}
              </select>

              <input
                placeholder="Modifier groups (comma-separated)"
                className="w-full border p-2 rounded mb-2"
                value={prodForm.modifierGroups}
                onChange={(e) => setProdForm({ ...prodForm, modifierGroups: e.target.value })}
              />
              {modifierLibrary.length > 0 && (
                <div className="flex flex-wrap gap-2 mb-3">
                  {modifierLibrary.map((item) => (
                    <button
                      type="button"
                      key={item}
                      onClick={() => pushLibraryToken("modifier", item)}
                      className="px-2 py-1 rounded text-xs bg-indigo-50 text-indigo-700 border border-indigo-100"
                    >
                      + {item}
                    </button>
                  ))}
                </div>
              )}

              <input
                placeholder="Sides (comma-separated)"
                className="w-full border p-2 rounded mb-2"
                value={prodForm.sides}
                onChange={(e) => setProdForm({ ...prodForm, sides: e.target.value })}
              />
              {sidesLibrary.length > 0 && (
                <div className="flex flex-wrap gap-2 mb-4">
                  {sidesLibrary.map((item) => (
                    <button
                      type="button"
                      key={item}
                      onClick={() => pushLibraryToken("side", item)}
                      className="px-2 py-1 rounded text-xs bg-emerald-50 text-emerald-700 border border-emerald-100"
                    >
                      + {item}
                    </button>
                  ))}
                </div>
              )}

              <div className="flex justify-end gap-2">
                <button type="button" onClick={closeProductModal} className="px-3 py-1.5 text-gray-600">
                  Cancel
                </button>
                <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">
                  {editingProductId ? "Save Changes" : "Save"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
