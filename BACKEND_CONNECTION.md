# Mobile ↔ Backend connection (Machakos NMS-EOC)

Use this when the Flutter app lives in another folder/IDE (e.g. `C:\Users\Nccg`) while the API runs from `C:\Users\USER\machakos-web\backend`.

A copy also lives at `C:\Users\Nccg\BACKEND_CONNECTION.md`.

---

## Backend readiness (local)

| Item | Value |
|------|--------|
| Project | `C:\Users\USER\machakos-web\backend` |
| Start | `.\dev.cmd` |
| Bind | `HOST=0.0.0.0` `PORT=3000` (LAN-reachable) |
| CORS | `CORS_ORIGIN=*` |
| Health | `GET http://127.0.0.1:3000/` → `{"ok":true,"service":"NMS-EOC API",...}` |
| This machine LAN IP | `192.168.100.184` (Wi-Fi — re-check if network changes) |
| LAN health | `GET http://192.168.100.184:3000/` |

**No `/api` prefix on local Fastify.** Production nginx may use `https://machakos.brighton.co.ke/api`; local mobile must **not** append `/api`.

If a physical phone cannot reach the API but this PC can, allow inbound TCP **3000** in Windows Firewall (Private network).

---

## Flutter (`C:\Users\Nccg`) — `AppConfig`

```dart
// lib/core/config/app_config.dart
API_URL     // REST base, no trailing slash
SOCKET_URL  // optional; else derived from API_URL origin only
```

### Run commands

```bat
REM Android emulator (host loopback via 10.0.2.2)
flutter run --dart-define=API_URL=http://10.0.2.2:3000

REM iOS simulator / desktop
flutter run --dart-define=API_URL=http://127.0.0.1:3000

REM Physical phone on same Wi-Fi (current LAN)
flutter run --dart-define=API_URL=http://192.168.100.184:3000

REM Production build (nginx /api proxy)
flutter build apk --release --dart-define=API_URL=https://machakos.brighton.co.ke/api --dart-define=SOCKET_URL=https://machakos.brighton.co.ke
```

Socket.IO must use the **bare origin** (scheme + host + port). Never point the socket client at `…/api`.

---

## Auth (field crew)

Roles: `DRIVER` | `EMT` | `NURSE` (OTP only — password login rejects these roles).

| Step | Method | Path | Body |
|------|--------|------|------|
| 1 | POST | `/auth/otp/request` | `{ "phone": "07…" }` |
| 2 | POST | `/auth/otp/verify` | `{ "phone": "07…", "code": "123456" }` |
| 3* | POST | `/auth/select-role` | `{ "role": "DRIVER" }` + `Authorization: Bearer <pendingToken>` |
| Session | GET | `/auth/me` | Bearer JWT |

\*Only if verify returns `requiresRoleSelection` + `pendingToken`. Mobile UI may not handle this yet — prefer single-role crew accounts for local testing.

All later calls: `Authorization: Bearer <token>`.

---

## Endpoints the mobile app hits

Base = `API_URL` with **no** path prefix locally.

### Auth / push
| Method | Path |
|--------|------|
| POST | `/auth/otp/request` |
| POST | `/auth/otp/verify` |
| GET | `/auth/me` |
| POST | `/auth/login` *(repo only; UI uses OTP)* |
| POST | `/notifications/token` |
| DELETE | `/notifications/token` |

### Fleet / shift / crew
| Method | Path |
|--------|------|
| GET | `/fleet/vehicles` |
| GET | `/fleet/my-checkin` |
| POST | `/fleet/:vehicleId/checkin` *(multipart: `file`, `lat`, `lng`, `locationName?`)* |
| DELETE | `/fleet/:vehicleId/checkin` |
| GET | `/fleet/crew-members` |
| POST | `/fleet/:vehicleId/crew` |
| GET | `/fleet/available-for-handover?excludeVehicleId=` |

### Tasks / PCR / stops
| Method | Path |
|--------|------|
| GET | `/tasks/active` |
| GET | `/tasks/history?page=&limit=` |
| PATCH | `/tasks/:taskId/status` |
| POST | `/tasks/:taskId/patient-data` |
| POST | `/tasks/:taskId/patient-care-report` *(multipart `file`)* |
| GET | `/tasks/:taskId/patient-care-reports` |
| GET | `/tasks/:taskId/patient-care-reports/:reportId/file` |
| GET | `/tasks/:taskId/stops` |
| POST | `/tasks/:taskId/stops` |
| PATCH | `/tasks/:taskId/stops/:stopId/arrived` |
| POST | `/tasks/:taskId/reassign` |

### Case / inventory
| Method | Path |
|--------|------|
| POST | `/incidents/:incidentId/close` |
| GET | `/inventory` |
| POST | `/inventory/checkout` |
| GET | `/inventory/my` |
| POST | `/inventory/checkouts/:checkoutId/return` |

### Socket.IO (same host:port as API)

Handshake: `auth: { token: <JWT> }`

| Listen | Purpose |
|--------|---------|
| `task:assigned` | New assignment |
| `task:updated` | Status / case updates |
| `task:stop-added` | Refresh stops |
| `task:stop-updated` | Refresh stops |

Mobile does not emit client events (joins are server-side via JWT rooms `user:{id}` / `role:{role}`).

---

## Quick connectivity checks

```bat
curl http://127.0.0.1:3000/
curl http://192.168.100.184:3000/
```

From the phone browser (same Wi-Fi): open `http://192.168.100.184:3000/` — should show JSON health.

---

## Web frontend check prompt (copy into another Cursor chat)

```
In C:\Users\USER\machakos-web, verify the Vite frontend is actually calling the local Fastify backend.

1. Confirm frontend/.env has:
   VITE_API_BASE_URL=http://127.0.0.1:3000
   VITE_SOCKET_URL=http://127.0.0.1:3000
2. Confirm backend is up: GET http://127.0.0.1:3000/ returns ok:true
3. Confirm Vite injected those env values (transform of src/api/client.ts and src/lib/socket.ts)
4. Open http://localhost:5173, attempt login (desk roles use POST /auth/login), and confirm Network tab shows requests to http://127.0.0.1:3000/... with 2xx (not connection refused / wrong host)
5. Report: env values, sample request URL + status, and any CORS or 401 issues

Do not change production URLs. Local API has no /api prefix.
```
