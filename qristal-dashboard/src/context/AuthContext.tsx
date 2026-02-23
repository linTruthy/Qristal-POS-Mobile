"use client";

import { createContext, useContext, useState, useEffect, ReactNode } from "react";
import { useRouter } from "next/navigation";

// Define the shape of our User and AuthContext
interface User {
    id: string;
    fullName: string;
    role: string;
    branchId: string;
}

interface AuthContextType {
    user: User | null;
    token: string | null;
    login: (id: string, pin: string) => Promise<void>;
    logout: () => void;
    isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Define server URL (ensure this matches your environment)
const SERVER_URL = "https://qristal-pos-api.onrender.com";

export function AuthProvider({ children }: { children: ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [token, setToken] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const router = useRouter();

    // On mount, check for existing session in localStorage
    useEffect(() => {
        const storedToken = localStorage.getItem("qristal_token");
        const storedUser = localStorage.getItem("qristal_user");

        if (storedToken && storedUser) {
            setToken(storedToken);
            setUser(JSON.parse(storedUser));
        }
        setIsLoading(false);
    }, []);

    const login = async (id: string, pin: string) => {
        try {
            const response = await fetch(`${SERVER_URL}/auth/login`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ id, pin }),
            });

            if (!response.ok) {
                throw new Error("Login failed");
            }

            const data = await response.json();

            // Save to state
            setToken(data.access_token);
            setUser(data.user);

            // Persist to local storage
            localStorage.setItem("qristal_token", data.access_token);
            localStorage.setItem("qristal_user", JSON.stringify(data.user));

            router.push("/"); // Redirect to dashboard home
        } catch (error) {
            console.error("Login Error:", error);
            throw error; // Propagate error to the UI component to handle
        }
    };

    const logout = () => {
        setUser(null);
        setToken(null);
        localStorage.removeItem("qristal_token");
        localStorage.removeItem("qristal_user");
        router.push("/login");
    };

    return (
        <AuthContext.Provider value={{ user, token, login, logout, isLoading }}>
            {children}
        </AuthContext.Provider>
    );
}

// Helper hook to use the context easily
export const useAuth = () => {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error("useAuth must be used within an AuthProvider");
    }
    return context;
};