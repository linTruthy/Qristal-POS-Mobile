"use client";

import { useAuth } from "@/context/AuthContext";
import withAuth from "@/components/withAuth";
import Link from "next/link";
import { usePathname } from "next/navigation";

function AdminLayout({ children }: { children: React.ReactNode }) {
  const { logout, user } = useAuth();
  const pathname = usePathname();

  const navItems = [
    { name: "Dashboard", href: "/" },
    { name: "Staff & Users", href: "/admin/users" },
    { name: "Menu Management", href: "/admin/menu" },
    { name: "Inventory", href: "/admin/inventory" }, // <--- ADD THIS LINE
    { name: "Floor Plan", href: "/admin/tables" },
    { name: "Reports", href: "/reports" },
  ];

  return (
    <div className="flex h-screen bg-gray-100">
      {/* Sidebar */}
      <aside className="w-64 bg-white shadow-md flex flex-col">
        <div className="p-6 border-b border-gray-200">
          <h1 className="text-2xl font-bold text-blue-600">Qristal Admin</h1>
          <p className="text-sm text-gray-500 mt-1">{user?.fullName}</p>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`block px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-blue-50 text-blue-700"
                    : "text-gray-700 hover:bg-gray-50"
                }`}
              >
                {item.name}
              </Link>
            );
          })}
        </nav>
        <div className="p-4 border-t border-gray-200">
          <button
            onClick={logout}
            className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700"
          >
            Logout
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto p-8">
        {children}
      </main>
    </div>
  );
}

export default withAuth(AdminLayout);