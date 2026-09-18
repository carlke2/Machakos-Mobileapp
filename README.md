# Machakos EOC — Field Responder Mobile App

Technical overview and implementation reference for the mobile app portion of the Machakos County Emergency Operations Center (EOC) system. This app is the field responder companion — used by Drivers (and other field crew) to receive dispatch, track fleet status, and submit patient care data — recalibrated from the original NMS (Nairobi/Malteser) architecture for Machakos County.

## 1. Overview

The wider Machakos EOC platform covers incident intake, dispatch, GIS, and dashboards for county disaster management, split across an Internal Portal, a Dispatch/Admin backend, and this mobile app. The mobile app is built and maintained by the mobile sub-team, with the web/internal portal owned by a separate sub-team.

- **Scope of this repo:** Field Responder mobile app only
- **Not covered here:** Citizen reporting app, Internal Portal, Partner Portal

## 2. Technology Stack

| Layer | Technology |
|---|---|
| Mobile Framework | **Flutter** (Dart) |
| Maps & Routing | Google Maps SDK, Google Directions API |
| Real-time | Socket.io client |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Backend | Fastify 5.8 (Node.js + TypeScript) |
| ORM | Prisma 7.8 (driver adapters) |
| Database | PostgreSQL (Supabase-hosted) |
| Cache / Real-time scaling | Redis (optional) |
| Logging | Pino (structured, backend-side) |
| Validation | Zod (backend-side) |

> Note: the original NMS reference architecture specifies Expo + React Native for the responder app. The Machakos build was recalibrated to use **Flutter** instead, while the backend (Fastify/Prisma/PostgreSQL/Redis/Socket.io) carries over largely unchanged.

## 3. System Context

The mobile app is one of several clients against a shared Core API Service:

- **Core API Service** — Fastify backend with Socket.io and Prisma (shared by all clients)
- **Internal Portal** — web app for Watchers, Dispatchers, Admins (owned by web sub-team)
- **Field Responder App** *(this repo)* — Flutter mobile app for Drivers/crew

## 4. Roles Relevant to This App

| Role | Responsibility in-app |
|---|---|
| **Driver** | Vehicle check-in/check-out, accepts and updates tasks, submits GPS telemetry, files Patient Care Reports (PCRs) |
| EMT / Nurse | *(planned/shared role structure — not yet confirmed as implemented in this app)* |

Full RBAC (Super Admin, Admin, Watcher, Dispatcher, Partner) is enforced backend-side; the mobile app only surfaces the Driver-facing workflow.

## 5. Core Workflows

1. **Auth** — login, session resolved via `GET /auth/me`; role returned determines in-app navigation (currently `DRIVER`)
2. **Fleet check-in** — driver checks a vehicle in/out (`GET/DELETE /fleet/{vehicleId}/checkin`, `GET /fleet/my-checkin`, `GET /fleet/vehicles`, `GET /fleet/crew-members`)
3. **Dispatch visibility** — driver's app polls dispatch state (`GET /dispatch/vehicles`, `GET /dispatch/nearest-vehicles`, `GET /dispatch/queue`)
4. **Incident handling** — view assigned incident and turnaround time (`GET /incidents`, `GET /incidents/:id`, `GET /incidents/:id/tat`)
5. **Task lifecycle** — active and historical tasks (`GET /tasks/active`, `GET /tasks/history`)
6. **Patient Care Report (PCR)** — capture and submit PCR with photo attachment (`GET/POST /tasks/:id/patient-care-reports`)
7. **Push notifications** — device token registered on login (`POST /notifications/token`)
8. **Fuel tracking** — fuel summary pulled from an external telemetry provider (`GET /fuel/summary`)

## 6. Real-time Architecture

- **Transport:** Socket.io client, one connection per authenticated session
- **Observed events:** connect / disconnect lifecycle tied to `user:{userId}` and role context (e.g. `role:DRIVER`)
- **Purpose:** live dispatch queue updates and fleet position broadcasts to the app without polling

## 7. External Integrations

| Integration | Purpose | Status |
|---|---|---|
| Google Maps / Directions API | In-app navigation to incident/pickup locations | **Active** — requires Billing enabled on the Google Cloud project; currently blocked by a billing error in testing |
| Firebase Cloud Messaging | Push notifications for dispatch alerts | Active |
| Uffizio (fleet telemetry) | Fuel summary / vehicle telemetry | **Broken** — auth handshake failing (`auth code not found in response`), returns 500 on `/fuel/summary` |

## 8. Development Status

Development is in its **final phase**. Core workflows above (auth, fleet check-in, dispatch visibility, incidents, tasks, PCR submission, push notifications) have been tested end-to-end against the production backend and are working. The **inventory module** is the one remaining piece of scope.

### Known open items
- **Inventory module** — not yet built
- **Google Maps Billing** — must be enabled on the Google Cloud project for in-app directions to work
- **Uffizio auth** — fuel summary integration failing auth handshake, needs investigation
- **`POST /auth/switch-role`** — called by the app but not implemented on the backend (404)
- **Notification token registration** — occasionally fails validation (`expected string, received undefined`) if the FCM token isn't ready at registration time
- **UI polish** — several `ListTile` widgets need to be wrapped in their own `Material` ancestor to fix invisible background/ink-splash rendering

## 9. Getting Started

### Prerequisites
- Flutter SDK installed and configured (`flutter doctor` should pass)
- A running instance of the companion backend (Fastify + PostgreSQL), reachable on your local network
- A Google Cloud project with Maps/Directions APIs and Billing enabled
- Firebase project configured for FCM

### Run locally

```bash
cd mobileapp
flutter pub get
flutter run
```

The app auto-probes for the backend at `localhost:3000`, `10.0.2.2:3000` (Android emulator loopback), and the local LAN IP — no `.env` configuration needed for the API URL.

### Backend

Backend lives in a separate repository (production: `BKerio/MACHAKOS-NMS`). Ensure `DATABASE_URL` points at a reachable PostgreSQL instance (local, Neon, or Supabase) before starting the mobile app against it.

## 10. Project Context

Developed for Machakos County, building on the original NMS platform (originally built for Nairobi/Malteser). Presented on-site to the client (Aug 19, 2026) alongside the web application, covering workflow, inventory module planning, and ambulance tracker rollout, with a follow-up review scheduled for September 9. The mobile app will continue to be supported post-launch by the mobile development team.
