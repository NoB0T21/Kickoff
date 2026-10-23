# ⚽ Kickoff — Turf Booking & Athlete Social Network

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Fastify](https://img.shields.io/badge/Fastify-5.x-000000?style=for-the-badge&logo=fastify&logoColor=white)](https://fastify.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://supabase.com)
[![BullMQ](https://img.shields.io/badge/BullMQ-Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://bullmq.io)
[![Cashfree](https://img.shields.io/badge/Cashfree-Payments-7B2CBF?style=for-the-badge)](https://cashfree.com)

---

## 📌 Project Summary

**Kickoff** is an all-in-one sports turf discovery, booking, and athlete community platform. It bridges the gap between booking physical sports turf slots and organizing competitive community matches. 

Whether booking a 5-a-side football turf or a late-night box cricket pitch, Kickoff streamlines:
- **Discovering & Reserving Turfs:** Geo-aware turf discovery with real-time slot availability and concurrency-safe locking.
- **Digital Payments:** Seamless in-app payment processing via Cashfree Payment Gateway with automated reconciliation.
- **Match Hosting:** Converting confirmed turf reservations into public community games or private invite-only match rooms.
- **Live Match Scoring Engines:** Dedicated scoring controllers for **Football** (minute goals, cards, scorers) and **Cricket** (overs, balls, wickets, extras, innings).
- **Gamified Progression:** Dynamic athlete profiles, social following, real-time leaderboards, automated achievement unlock pipelines, and MVP ratings.

---

## 🏗️ System Architecture

Kickoff uses a decoupled, mobile-first layered architecture designed for real-time responsiveness and high concurrency:

```mermaid
graph TD
    subgraph Client Application
        FlutterApp[Flutter Mobile App<br/>iOS & Android]
    end

    subgraph API & Application Layer
        FastifyServer[Fastify 5 Node.js API<br/>TypeScript]
        BullMQWorkers[BullMQ Background Workers<br/>Match, Email, Reconciliation]
    end

    subgraph Data & Identity Layer
        SupabaseAuth[Supabase Auth<br/>JWT & OAuth]
        PostgreSQL[(Supabase PostgreSQL<br/>RLS + Stored Triggers)]
        RedisStore[(Redis<br/>BullMQ Queues & Caching)]
    end

    subgraph Third-Party Integrations
        CashfreePG[Cashfree Payment Gateway<br/>Orders & Webhooks]
    end

    FlutterApp -->|REST / HTTPS| FastifyServer
    FlutterApp -->|JWT Authentication| SupabaseAuth
    FlutterApp -->|In-App Checkout| CashfreePG
    FastifyServer -->|pg Connection Pool| PostgreSQL
    FastifyServer -->|Enqueues Tasks| RedisStore
    FastifyServer -->|Payment Verification| CashfreePG
    BullMQWorkers -->|Processes Jobs| RedisStore
    BullMQWorkers -->|Atomic Updates| PostgreSQL
    CashfreePG -->|Webhooks| FastifyServer
```

---

## 🌟 Special & Key Features

### 1. 🔒 Concurrency-Safe Turf Slot Locking
- **Two-Phase Reservation:** Implements a temporary lock state (`available` &rarr; `locked` &rarr; `booked`) with a strict **5-minute TTL**.
- **Race Condition Prevention:** Multi-slot bookings are executed in a single PostgreSQL transaction with `SELECT ... FOR UPDATE` row-level locks.
- **Single-Active-Lock Rule:** Enforced at the database and application layer to prevent malicious cart hoarding.
- **Automated Sweep:** Unpaid or expired locks are reclaimed independently without blocking read queries.

### 2. 💳 Integrated Cashfree Payment Gateway
- **Checkout Pipeline:** Creates dynamic Cashfree payment sessions and loads the secure checkout via an embedded mobile WebView.
- **Idempotent Webhooks:** Validates cryptographic webhook signatures, prevents duplicate payment execution, and automatically triggers booking confirmation.
- **Reconciliation Worker:** Handles background polling and automated refunds if a transaction fails after a slot lock expires.

### 3. 🏟️ Post-Booking Match Hosting & Community
- **Instant Event Creation:** Once a booking is confirmed, the host can create a public or private community match.
- **Dynamic Capacity Limits:** Sport-specific capacity validation (Football: 10–22, Cricket: 10–30, Badminton: 2–4).
- **Privacy Controls:**
  - **Public Events:** Discoverable on the community feed for any nearby athlete to join.
  - **Private Events:** Accessible only via cryptographically unguessable invite tokens or to followers.
- **QR Check-In:** Match state transitions from `scheduled` to `live` via on-premise turf verification.

### 4. ⚡ Adaptive Live Scoring Engines
Kickoff provides custom scoring controllers tailored to the event's sport:
- **Football Engine:**
  - Real-time match clock.
  - Team A vs. Team B score tracker.
  - Goal attribution with timestamps and player roster tagging.
- **Cricket Engine:**
  - Complete ball-by-ball logging: standard runs (0, 1, 2, 3, 4, 6), extras (wides, no-balls), and dismissals (bowled, caught, run out, LBW).
  - Inning switcher and automatic overs calculation (e.g., 14 balls = 2.2 overs).

### 5. 👥 Team Division & Hybrid Roster Management
- **Single-Host Control:** The match host manages rosters, assigns players between Team A and Team B, and submits verified final results.
- **Hybrid Rosters:** Supports registered platform athletes as well as guest placeholder players ("Friends without the app") to ensure total team capacity matches real-world play.

### 6. 🏆 Leaderboards, Points & Achievements Pipeline
- **Zero-Latency Aggregates:** Total player points are maintained as denormalized counters via database triggers on `points_transactions`, avoiding slow runtime SQL `SUM()` queries.
- **Background Achievement Evaluator:** An asynchronous BullMQ worker scans completed match stats to unlock achievements (e.g., *First Kickoff*, *Victory Circle*, *Golden Boot*, *Clean Sheet*, *Match MVP*) and dispatches bonus points.
- **Podium Rankings:** Global and sport-filtered leaderboards featuring top-3 podium highlights and instant search.

---

## 🛠️ Tech Stack

### Mobile Application (Frontend)
| Technology | Description |
| :--- | :--- |
| **Flutter 3.x / Dart** | Cross-platform framework targeting Android and iOS devices |
| **Flutter Riverpod 2.6+** | Reactive, compile-safe state management |
| **GoRouter 14.8+** | Declarative, auth-guarded routing with redirect listeners |
| **Dio 5.8+** | Robust HTTP client configured with JWT auto-refresh interceptors |
| **WebView Flutter 4.8+** | Native WebView integration for Cashfree payment gateways |
| **Google Sign-In 6.2+** | Native Google authentication integration |
| **Image Picker** | Avatar selection and image upload handling |

### API & Application Server (Backend)
| Technology | Description |
| :--- | :--- |
| **Node.js & Fastify 5.x** | High-performance, low-overhead HTTP web framework |
| **TypeScript 5.x** | Strictly typed application development |
| **TypeBox** | JSON schema validation and runtime type checking |
| **@fastify/jwt** | Fast token verification using Supabase JWT signing keys |
| **@fastify/rate-limit** | IP-based rate limiting to prevent spam and credential stuffing |
| **pg (node-postgres)** | High-throughput PostgreSQL connection pool |

### Database, Queues & Cloud Infrastructure
| Technology | Description |
| :--- | :--- |
| **Supabase (PostgreSQL 15+)** | Managed PostgreSQL database with Row Level Security (RLS) |
| **PostgreSQL Triggers & Functions** | Automated profile creation, point accrual, and follow counters |
| **Redis & BullMQ 6.x** | Distributed job queues for async match settlement, email, and reconciliation |
| **Cashfree PG API** | Production-ready payment processing (API version `2023-08-01`) |

---

## 📁 Repository Structure

```text
Kickoff/
├── Backend/                       # Node.js + Fastify API Server
│   ├── src/
│   │   ├── config/                # Environment variables, database pool, constants
│   │   ├── controllers/           # HTTP route controllers (auth, turf, booking, event, profile)
│   │   ├── middleware/            # JWT verification, rate limiter, error handlers
│   │   ├── repositories/          # Direct PostgreSQL / PostgREST queries
│   │   ├── schemas/               # TypeBox request/response validation schemas
│   │   ├── services/              # Business logic (Cashfree, Booking, Event, Points)
│   │   ├── workers/               # BullMQ background workers (match, email, reconciliation)
│   │   ├── index.ts               # Server bootstrap & port listener (0.0.0.0:3000)
│   │   └── routes.ts              # Central router registry
│   ├── .env.example               # Backend environment template
│   ├── package.json               # Backend dependencies and scripts
│   └── tsconfig.json              # TypeScript configuration
│
├── frontend/                      # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/                  # Theme, network client, router, app constants
│   │   ├── features/
│   │   │   ├── auth/              # Sign up, Login, OTP, Forgot Password
│   │   │   ├── bookings/          # Slot checkout, payment webview, booking receipt
│   │   │   ├── dashboard/         # Bottom navigation screen (Explore, Bookings, Community, Profile)
│   │   │   ├── events/            # Event creation, live scoreboards, match controllers, invite links
│   │   │   ├── profile/           # Athlete profile, onboarding, follower lists
│   │   │   └── turfs/             # Discovery feed, search filters, slot booking matrix
│   │   └── main.dart              # Flutter application entrypoint
│   └── pubspec.yaml               # Flutter dependencies & asset declarations
│
├── supabase/
│   └── migrations/                # SQL migrations (DDL, tables, triggers, RLS policies)
└── docs/                          # Detailed architecture specifications & API contracts
```

---

## 🚀 Getting Started & Setup

### Prerequisites
Make sure you have the following installed on your development machine:
- **Node.js** (v18.0.0 or higher) and **npm**
- **Flutter SDK** (v3.12.0 or higher) & **Dart SDK**
- **Android Studio** / **Xcode** with appropriate simulators or a physical device
- **PostgreSQL 15+** (or a free [Supabase](https://supabase.com) project)
- **Redis Server** (running locally or via Redis Cloud / Docker)

---

### 1. Database Setup (Supabase / PostgreSQL)

1. Create a new project in [Supabase](https://supabase.com).
2. Navigate to the **SQL Editor** in the Supabase Dashboard.
3. Run the migration scripts located in `supabase/migrations/` sequentially:
   - `20260731120000_turf_booking_v2.sql`
   - `20260803150000_event_creation_and_privacy.sql`
   - `20260803160000_live_match_and_roster.sql`
   - `20260804130000_cricket_state_v2.sql`
4. Set up two storage buckets in Supabase Storage:
   - `avatars` (Public read, authenticated upload)
   - `turf-images` (Public read)

---

### 2. Backend Setup (`/Backend`)

1. Open a terminal and navigate to the `Backend` directory:
   ```bash
   cd Backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables:
   ```bash
   cp .env.example .env
   ```

4. Populate your `.env` file with your credentials:
   ```env
   # PostgreSQL Connection URL (Supabase direct connection string)
   DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-ID].supabase.co:5432/postgres"

   # Supabase API Credentials
   SUPABASE_URL="https://[PROJECT-ID].supabase.co"
   SUPABASE_SERVICE_ROLE_KEY="your-supabase-service-role-key"
   SUPABASE_JWT_SECRET="your-supabase-jwt-secret"

   # Server Config
   PORT=3000
   HOST="0.0.0.0"

   # Cashfree Payment Gateway Credentials
   CASHFREE_APP_ID="your-cashfree-app-id"
   CASHFREE_SECRET_KEY="your-cashfree-secret-key"
   CASHFREE_BASE_URL="https://sandbox.cashfree.com/pg"
   CASHFREE_WEBHOOK_SECRET="your-cashfree-webhook-secret"

   # Redis Configuration (Required for BullMQ workers)
   REDIS_HOST="127.0.0.1"
   REDIS_PORT=6379
   ```

5. Start the backend in development mode:
   ```bash
   npm run dev
   ```
   *The server starts on `http://0.0.0.0:3000`. You can verify it at `http://localhost:3000/health`.*

---

### 3. Frontend Setup (`/frontend`)

1. Open a new terminal and navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```

2. Install Flutter packages:
   ```bash
   flutter pub get
   ```

3. Set up the development endpoint:
   - Open `frontend/lib/core/constants/constants.dart`.
   - Update `apiBaseUrl` with your machine's local IP address if testing on a physical mobile device (e.g., `http://192.168.1.50:3000`) or leave the default for local emulator testing.
   - Alternatively, pass environment flags at build/run time:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://<YOUR-LOCAL-IP>:3000
     ```

4. Run the app on your connected device or simulator:
   ```bash
   flutter run
   ```

---

## 📡 API Reference Overview

| Module | Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- | :--- |
| **Auth** | `POST` | `/api/auth/signup` | Register a new user | No |
| **Auth** | `POST` | `/api/auth/login` | Login with email and password | No |
| **Auth** | `POST` | `/api/auth/refresh` | Exchange refresh token | Yes |
| **Profile** | `GET` | `/api/profiles/:id` | Fetch athlete profile and stats | Yes |
| **Profile** | `PUT` | `/api/profiles/:id` | Update profile attributes & sport | Yes |
| **Turfs** | `GET` | `/api/turfs` | Discover turfs by sport, date & geo-distance | No |
| **Turfs** | `GET` | `/api/turfs/:id/slots` | Retrieve slot schedule with availability | No |
| **Bookings**| `POST` | `/api/bookings/lock` | Temporarily lock slots (5-min reservation) | Yes |
| **Bookings**| `POST` | `/api/bookings/checkout` | Create Cashfree payment order session | Yes |
| **Bookings**| `POST` | `/api/bookings/webhook` | Cashfree webhook for payment status updates | Signature |
| **Events** | `POST` | `/api/events` | Create public/private match room from booking | Yes |
| **Events** | `POST` | `/api/events/:id/join` | Join event roster (registered user) | Yes |
| **Events** | `POST` | `/api/events/:id/roster/guest` | Add guest player (Host only) | Yes |
| **Events** | `POST` | `/api/events/:id/score/log` | Record Football or Cricket score action | Yes |
| **Events** | `POST` | `/api/events/:id/settle` | Settle match, pick MVP, allocate points | Yes |
| **Board** | `GET` | `/api/leaderboards` | Retrieve global or sport-specific rankings | No |

---

## 👨‍💻 Author

- **Aryan Gawade**
  - **GitHub:** [@NoB0T21](https://github.com/NoB0T21)
  - **Email:** [aryangawade65418@gmail.com](mailto:aryangawade65418@gmail.com)
  - **Project Repository:** [NoB0T21/Kickoff](https://github.com/NoB0T21/Kickoff)

---

## 📄 License

This project is licensed under the terms specified by the author. See the repository for details.
