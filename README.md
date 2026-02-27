# Qristal POS

A full-stack, offline-capable Point of Sale system for restaurants and hospitality businesses — built and maintained by [Truthy Systems](https://truthysystems.com).

Qristal POS is composed of three sub-repositories managed as Git submodules:

| Repo | Description | Stack |
|------|-------------|-------|
| [`qristal_api`](./qristal_api) | Backend REST API & WebSocket server | NestJS · PostgreSQL · Prisma |
| [`qristal_dashboard`](./qristal_dashboard) | Web-based admin & reporting dashboard | Next.js · React · Tailwind CSS |
| [`qristal_mobile`](./qristal_mobile) | Offline-first POS terminal app | Flutter · Drift (SQLite) |

---

## System Overview

```
┌─────────────────────────────────────────────────────┐
│                   qristal_api                        │
│  NestJS REST API + WebSocket Gateway (PostgreSQL)   │
└──────────────────────┬──────────────────────────────┘
                       │  HTTP / WebSocket
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐          ┌─────────▼──────────┐
│qristal_dashboard│          │  qristal_mobile     │
│ Next.js (Web)  │          │  Flutter (Android/  │
│ Admin Portal   │          │  iOS / Windows)     │
└────────────────┘          └────────────────────┘
```

The mobile app operates fully offline and syncs with the API when a connection is available. The dashboard provides management tools — menu editing, user management, inventory, analytics, and reporting.

---

## Cloning the Monorepo

```bash
git clone --recurse-submodules <repo-url>
```

Or if already cloned:

```bash
git submodule update --init --recursive
```

---

## Features

- **PIN-based staff authentication** with role-based access (Owner, Manager, Cashier, Waiter, Kitchen)
- **Offline-first POS** — orders, payments, and shifts work without internet
- **Real-time sync** — push/pull architecture with WebSocket live updates
- **Table & floor plan management**
- **Kitchen display routing** — items routed to Kitchen, Bar, Barista, etc.
- **Shift management** — open/close shifts with cash reconciliation
- **Inventory tracking** with recipe-based stock deduction
- **Multi-branch ready** — branch isolation built into the data model
- **Audit logs** — void, discount, and cash flow events are tracked
- **Receipt printing** via Bluetooth thermal printer (mobile)
- **Analytics & reports** via the web dashboard

---

## Getting Started

Each sub-project has its own setup guide. See the respective `README.md`:

- [API Setup →](./qristal_api/README.md)
- [Dashboard Setup →](./qristal_dashboard/README.md)
- [Mobile App Setup →](./qristal_mobile/README.md)

---

## Developer

Built by **[Truthy Systems](https://truthysystems.com)** — software solutions for modern businesses.