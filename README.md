# Qristal API

The backend REST API and WebSocket gateway for the Qristal POS system. Built with [NestJS](https://nestjs.com), [Prisma](https://www.prisma.io), and PostgreSQL.

Developed and maintained by **[Truthy Systems](https://truthysystems.com)**.

---

## Tech Stack

- **Framework:** NestJS (TypeScript)
- **Database:** PostgreSQL via Prisma ORM
- **Auth:** JWT + PIN-based authentication
- **Real-time:** WebSocket gateway (Socket.io)
- **Containerisation:** Docker Compose

---

## Features

- JWT authentication with PIN-based staff login
- Role-based access control (Owner, Manager, Cashier, Waiter, Kitchen)
- Menu & product management (categories, products, modifiers, sides, production area routing)
- Order lifecycle management (Open → Kitchen → Served → Closed / Voided)
- Payment recording (Cash, Card, Mobile Money)
- Seating & floor plan management
- Shift management with cash reconciliation
- Inventory tracking with recipe-based ingredient deduction
- Offline sync — pull changes and push unsynced data from mobile terminals
- Audit logging (voids, discounts, cash in/out)
- Multi-branch data isolation

---

## Prerequisites

- Node.js 20+
- PostgreSQL database (local or hosted — e.g. Supabase, Railway, Render)
- npm

---

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Configure environment

Create a `.env` file in the project root:

```env
DATABASE_URL="postgresql://USER:PASSWORD@HOST:PORT/DATABASE?schema=public"
DIRECT_URL="postgresql://USER:PASSWORD@HOST:PORT/DATABASE?schema=public"
JWT_SECRET="your-secret-key"
```

### 3. Run database migrations

```bash
npx prisma migrate deploy
```

### 4. (Optional) Seed the database

```bash
npx ts-node prisma/seed.ts
```

---

## Running the Server

```bash
# Development
npm run start:dev

# Production
npm run start:prod
```

The API will be available at `http://localhost:3000` by default.

---

## Running with Docker

```bash
docker-compose up
```

---

## Running Tests

```bash
# Unit tests
npm run test

# End-to-end tests
npm run test:e2e

# Coverage
npm run test:cov
```

---

## API Modules

| Module | Description |
|--------|-------------|
| `auth` | PIN login, JWT issuance |
| `users` | Staff management |
| `menu` | Categories & products |
| `inventory` | Stock items & recipe ingredients |
| `seating` | Tables & floor plans |
| `reports` | Sales and shift reporting |
| `sync` | Push/pull sync for offline mobile terminals |
| `events` | WebSocket real-time gateway |

---

## Database Schema

Managed via Prisma. Key models:

- **User** — staff with role, PIN, and branch assignment
- **Category / Product** — menu items with modifiers, sides, and production area
- **Order / OrderItem** — with modifier and side line items, kitchen routing
- **Payment** — linked to orders and shifts
- **SeatingTable** — floor plan with status
- **Shift** — cash drawer open/close with reconciliation
- **InventoryItem / RecipeIngredient** — stock tracking
- **AuditLog / SyncLog** — traceability and sync history

---

## Developer

Built by **[Truthy Systems](https://truthysystems.com)**.