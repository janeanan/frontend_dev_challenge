# CLAUDE.md — Rescu Flutter Assessment

## graphify

This project has a knowledge graph at `graphify-out/` (529 nodes, 652 edges, 42 communities).

**Rules — use the graph before touching source files:**

1. **Codebase questions** → `graphify query "<question>"` first. Read only the files it surfaces.
2. **Relationship between two things** → `graphify path "<A>" "<B>"` (shortest path, cross-community bridges).
3. **Deep dive on one concept** → `graphify explain "<concept>"` (scoped subgraph, cheaper than reading the file).
4. **Broad architecture review** → `graphify-out/GRAPH_REPORT.md` (last resort — high token cost).
5. **Skip graph entirely** when: question names a specific file + line, or the answer fits in one `Read` call.

**Graph freshness:**
- User runs `graphify . --watch` in a terminal during active development — `graph.json` auto-rebuilds when code changes (no LLM cost; AST only).
- After a coding session without `--watch`: run `graphify . --update` to re-extract only changed files before querying.
- If `graph.json` is missing or stale (last modified > 30 min ago during active work), suggest the user run `/graphify .` or `graphify . --update`.

**Fallback chain** (stop when context is sufficient):
```
graphify query → graphify path/explain → GRAPH_REPORT.md → targeted Read of flagged files
```

**God nodes** (highest betweenness — start here for cross-cutting questions):
`DealModel` · `FakeApiService` · `AnalyticsService` · `DealRepo` · `pubspec.yaml`

**Key communities:**
`Cart & Checkout Flow` · `Repository & Data Layer` · `Home Feed & Pagination` · `Fake API Service`
`Deal Data Model` · `Pickup Window Model` · `Countdown Timer Widget` · `Analytics & Route Middleware`

---

## ห้ามแตะ (READ-ONLY)
- `lib/service/fake_api_service.dart` — simulated backend
- `assets/data/` — seed data (stores.json, deals.json, orders.json)
- Flutter version: **3.27.0** (pinned), Java: **17**

---

## Stack
| Layer | Tool |
|---|---|
| State / DI / Routing | **GetX** |
| Maps | `flutter_map` |
| HTTP (simulated) | `FakeApiService` (in-process, adds latency + random failures) |
| Currency area | Asia/Bangkok **UTC+7** — API sends ISO-8601 UTC |

---

## โครงสร้างโปรเจค

```
lib/
  main.dart              DI bootstrap (FakeApiService, AnalyticsService, CartService, repos)
  app_config.dart        Theme + colors (AppConfig.primaryGreen, etc.)
  model/                 Plain Dart models (fromJson, no codegen)
  service/               GetxService (app-wide singletons)
  repository/            Thin wrappers over FakeApiService → typed models
  routes/routes.dart     Named routes + GetPage list
  binding/               Per-route lazy DI
  middleware/            ScreenViewMiddleware (analytics)
  feature/<name>/        screen + controller + widgets
  feature/shared_widget/ DealCard, ShimmerDealCard, TheNetworkImage
```

---

## Navigation Flow

```
App Start
  └─ main.dart → initDependencies() → Routes.home

/home  (HomeScreen + HomeController)
  ├─ Flash deals rail (horizontal) → /deal?id=X&source=flash_rail
  ├─ Main feed (paginated, pull-to-refresh) → /deal?id=X&source=home_feed
  ├─ FAB map icon → /map
  ├─ Search icon → /search
  ├─ Cart icon (badge) → /cart
  └─ ⋮ overflow menu
       ├─ Analytics debug → /debug/analytics
       └─ Simulate deep link → rescu://open/deal?id=42&source=push

/deal  (DealDetailsScreen + DealDetailsController)
  ├─ args: DealModel (passed via Get.arguments)
  ├─ query params: ?id=<int>&source=<string>
  ├─ Add to bag → CartService.add()
  └─ Back → previous route

/search  (SearchScreen + SearchDealsController)
  ├─ Query triggers dealRepo.search() on every keystroke
  └─ Result card → /deal?id=X&source=search

/map  (MapScreen + MapController)
  └─ Markers for nearby stores

/cart  (CartScreen + CartService)
  ├─ Increment/decrement/remove via CartService
  └─ Checkout → calls FakeApiService.checkout() (passes reservationId per line)

/orders  (OrdersScreen + OrdersController)
  ├─ Active orders (isActive=true) with PickupCountdown widget
  └─ Past orders

/debug/analytics  (AnalyticsDebugScreen)
  └─ Shows batched analytics events from AnalyticsService
```

### Deep link
```
rescu://open/deal?id=<int>&source=<string>
```
Handled by `ScreenViewMiddleware` → navigates to `/deal`.

---

## Services (永続 Singletons — `permanent: true`)

| Service | Responsibility |
|---|---|
| `FakeApiService` | Simulated backend; all network calls go here |
| `AnalyticsService` | Batched event logging; `sendAnalyticsBatch` every 10 events or 15 s |
| `CartService` | Observable bag (`items`, `itemCount`); `add/decrement/remove/clear` |

## Repositories (lazyPut, fenix: true)

| Repo | Methods |
|---|---|
| `DealRepo` | `fetchDeals(page)`, `fetchFlashDeals()`, `fetchById(id)`, `search(query)` |
| `StoreRepo` | store listing |
| `OrderRepo` | `fetchOrders()` |

---

## Models ที่สำคัญ

### DealModel
- `flashSaleEndsAt: DateTime?` — null = ไม่ใช่ flash sale
- `pickupWindow: PickupWindowModel` — `.start/.end` เป็น UTC; `.label/.isToday/.isOpenNow`
- `isFlashSale`, `discountPercent` getters

### PickupWindowModel
- `start/end` — UTC `DateTime` (API ส่ง ISO-8601 UTC)
- `.label` ใช้ `DateFormat('HH:mm').format(start)` — **ยังไม่แปลง timezone → RES-106 bug**
- `.isToday` เทียบ `.day` เท่านั้น — **timezone bug → RES-106**

---

## Bug Tickets (Part A)

| ID | หน้า | ไฟล์หลัก | อาการ |
|---|---|---|---|
| RES-101 | /search | `search_deals_controller.dart` | Race condition: ผลลัพธ์เก่า override ใหม่ |
| RES-102 | /orders | `pickup_countdown.dart` | Timer.periodic ไม่ถูก cancel → setState after dispose |
| RES-103 | /deal | `deal_details_controller.dart:36` | `ever()` สร้างทุกครั้งที่เปิดหน้า แต่ไม่ถูกทำลาย |
| RES-104 | /home | `home_controller.dart:58-63` | refresh ขณะ loadMore → deals ซ้ำ |
| RES-105 | /home | `home_screen.dart`, `deal_card.dart` | Rebuild ทั้ง list + image cache ไม่มี limit |
| RES-106 | /home, /deal | `pickup_window_model.dart` | `DateFormat.format()` ใช้ local time แทน UTC+7 |
| RES-107 | deep link | `deal_details_controller.dart:28` | `Get.arguments` เป็น null เมื่อมาจาก deep link |

---

## Features (Part B)

| ID | หน้าที่เกี่ยวข้อง | หมายเหตุ |
|---|---|---|
| F-1 | DealCard, FlashDealsSection, DealDetailsScreen | Live countdown `mm:ss`; expired → disabled + remove from cart |
| F-2 | DealCard (home_feed, flash_rail, search) | `deal_impression` event; 50% visible ≥ 1s; once/session; batch 10/15s |
| F-3 | CartService, CartScreen, DealDetailsScreen | Optimistic add → `reserveDeal`; 5-min expiry; checkout passes reservationId |

---

## กฎการ commit

```
[RES-101] Fix search race condition by cancelling stale futures
[F-1] Add live flash-sale countdown to DealCard
```
- หนึ่ง commit ต่อหนึ่ง logical change
- บันทึกเวลาที่ใช้จริงใน `solutions.md`

---

## คำสั่งที่ใช้บ่อย

```bash
fvm flutter run                  # run app
fvm flutter analyze              # static analysis
fvm flutter test                 # tests
# Android deep link test:
adb shell am start -a android.intent.action.VIEW \
  -d "rescu://open/deal?id=42&source=push" dev.rescu.rescu
```

---

## จุดที่ต้องระวัง

1. **GetX lifecycle vs Widget lifecycle** — `GetxController.onClose()` ต้อง dispose Timer/Subscription เสมอ
2. **ever() listener** สมัครกับ observable ระดับ global (`cartService.itemCount`) — ถ้าไม่ dispose จะสะสมทุก instance
3. **UTC vs local time** — API ส่ง UTC ทุกอย่าง, แสดงผลต้องแปลงเป็น UTC+7 (Bangkok)
4. **Obx scope** — wrap แค่ widget ที่เปลี่ยนจริงๆ ไม่ใช่ทั้ง subtree
5. **Pagination race** — guard `_isFetchingMore` และ reset `_page` อย่างถูกต้องก่อน refresh
