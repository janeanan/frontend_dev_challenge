# Solutions — Rescu Flutter Assessment

## AI Tools Used

ใช้ **Claude Code** (Anthropic's CLI) เป็นตัวช่วยตลอดการทำ assessment นี้ โดยติดตั้งเครื่องมือเสริม 2 อย่าง:

**CLAUDE.md** — ไฟล์ context ที่อธิบายโครงสร้างโปรเจค, stack, bug tickets, และกฎที่ห้ามแตะ (`fake_api_service.dart`, `assets/data/`) ให้ Claude อ่านตั้งแต่ต้น conversation แทนที่จะต้องอธิบายซ้ำทุกครั้ง เพื่อให้ Claude ตอบคำถามและแก้โค้ดได้ตรงจุดโดยไม่ต้องเดา context

**graphify** — เครื่องมือที่สร้าง knowledge graph จาก codebase (529 nodes, 652 edges) แล้วให้ query ด้วยภาษาธรรมชาติเช่น `graphify query "where is ever() called"` แทนที่จะต้องเปิดไฟล์ทีละไฟล์ ช่วยให้หา root cause ของ bug ได้เร็วขึ้น โดยเฉพาะ bug ที่กระจายข้าม file เช่น RES-103 (listener lifecycle) และ RES-107 (deep link entry point)

### AI Usage Log — แนวทางที่ปรับเปลี่ยนระหว่างทาง

**RES-102:** AI เสนอแนวทางแรกคือ `dispose()` + stored `Timer` ซึ่งถูกต้องในเชิง Flutter แต่ dev มองว่าโปรเจคนี้ใช้ GetX Controller เป็นหลัก การมาเขียน `dispose()` ใน `StatefulWidget` แยกออกไปเพิ่มภาระในการดูแล dev จึงเลือกใช้ `Stream.periodic` + `StreamBuilder` แทน ซึ่ง Flutter จัดการ lifecycle ให้อัตโนมัติ ไม่ต้องเขียน `dispose()` เอง

**RES-103:** AI เสนอ `isClosed` guard เป็นแนวทางหนึ่ง แต่ dev ชี้ให้เห็นว่า Worker ยังค้างอยู่ใน memory และยังต้องมี `dispose()` ใน `onClose()` อยู่ดี dev มองว่าเมื่อ controller เข้า `onInit()` ครั้งแรกจะได้ `quantityLeft` จาก model มาแล้ว การลดค่าใน `addToCart()` แบบ optimistic จึงตอบโจทย์กว่า เพราะไม่มี Worker เกิดขึ้นเลย ไม่มีอะไรต้องจัดการ

---

## Part A: Bug Fixes

---

### RES-101 — Search race condition ✅ Fixed

**File:** `lib/feature/search/search_deals_controller.dart`

**Root cause:** `_search()` is async, so every keystroke fires a new `Future` concurrently. If a slow request from an earlier query resolves *after* a faster request from a newer query, the stale results overwrite the current ones — the UI shows the wrong list.

**Fix:** Added a `_activeQuery` field that is updated synchronously on every keystroke (before the `await`). After the `await` resolves, a single guard — `if (query != _activeQuery) return;` — discards the response if the user has typed something newer. The request is still sent; only the result is discarded.

**Trade-off:** Requests for intermediate keystrokes still reach the backend. A debounce + cancellation token would reduce network calls, but is unnecessary here because `FakeApiService` is in-process with no real network cost.

**Time spent:** ~25 min

---

### RES-102 — Timer.periodic leak in PickupCountdown ✅ Fixed

**File:** `lib/feature/order/widget/pickup_countdown.dart`

**Root cause:** `Timer.periodic` is created in `initState` but the returned `Timer` reference is never stored, so `dispose()` cannot cancel it. The timer keeps firing after the widget is removed from the tree, calling `setState` on a dead `State` object → "setState called after dispose" error. Multiple visits to `/orders` compound the problem: each visit creates another timer, so N visits → N timers running permanently.

**Why not `dispose()` + stored Timer?** Considered it, but chose `Stream.periodic` + `StreamBuilder` instead:
- `StreamBuilder` manages the subscription lifecycle automatically — no `dispose()` override needed
- Eliminates `setState` entirely — only the `Text` widget inside the builder rebuilds
- Avoids the edge-case race where the timer fires exactly as `dispose()` runs (would still need `if (mounted)` guard)

**Why not GetxController?** `PickupCountdown` appears N times in the orders list simultaneously. GetX stores controllers in a global registry keyed by type + tag, so each instance needs a unique tag (`order.id`). Callers must also manually call `Get.delete<>(tag: id)` per instance on teardown — replicating what `StatefulWidget` provides for free.

**Fix applied:** Replaced `Timer.periodic` + `setState` with `Stream.periodic` + `StreamBuilder`. The stream is stored in `_tickStream` (initialized once in `initState`) so it is not recreated on rebuild. The `computation` parameter is omitted intentionally — `Stream<dynamic>` is sufficient since the emitted value is unused; only the tick is needed to trigger `_buildText()`.

**Time spent:** ~40 min

---

### RES-103 — `ever()` listener accumulates across screen visits ✅ Fixed

**File:** `lib/feature/deal/deal_details_controller.dart`

**Root cause:** `ever(cartService.itemCount, ...)` registers a `Worker` that subscribes to a global observable (`CartService` is `permanent: true`). The Worker was not stored, so GetX could not dispose it when the controller was deleted. Confirmed via console log: on the second visit, pressing "Add to bag" once produced 2 `GET /deals/1` requests — one from the current controller, one from the orphaned Worker of the previous visit. Each additional visit adds another Worker, making the app chattier the longer the session.

**Approaches considered:**

| Approach | Worker leak | Syncs from server | Notes |
|---|---|---|---|
| `ever()` + `onClose()` dispose | ✅ | ✅ | Canonical fix — still makes API call per cart change |
| `isClosed` guard | ✗ Worker stays alive | ✅ | Fires callback then discards result — wastes API calls |
| `addToCart()` + fetch | ✅ | ✅ | 1 call per button press, but FakeApiService returns stale value |
| `addToCart()` optimistic | ✅ | ✗ | Decrement in memory — accurate for this app |

**Why not `isClosed`:** The Worker is still registered on `cartService.itemCount` after the controller is deleted. It keeps firing and calling `fetchById()` silently — wasting API calls without any visible benefit. It fixes the crash but not the root cause.

**Fix applied:** Removed `ever()` entirely. `addToCart()` decrements `_quantityLeft` optimistically by 1 per press, clamped to `[0, deal.quantityLeft]`. No Worker is created, so there is nothing to leak. This matches the actual UX: the user added one item, so one fewer is available to add.

**Time spent:** ~60 min

---

### RES-104 — Duplicate deals when refreshing during loadMore ✅ Fixed

**File:** `lib/feature/home/home_controller.dart`

**Root cause:** `refreshDeals()` resets `_page = 1` and calls `deals.assignAll()`, but does not guard against a concurrent `loadMore`. If both run simultaneously: `loadMore` increments `_page` and is awaiting a network response; `refreshDeals` resets `_page = 1` and replaces `deals` with fresh page-1 items; then `loadMore` resolves and calls `deals.addAll()` with stale page-2 results on top — mixing fresh page-1 data with stale page-2 data, or creating duplicate entries if `loadMore` was also fetching page 1.


**Fix applied:** Added `int _generation = 0` field.

- `refreshDeals()` increments the counter (`final gen = ++_generation`) before the `await`. After the `await`, if `_generation != gen` the result is discarded — a newer operation has superseded this one.
- `loadMore()` reads the counter without incrementing (`final gen = _generation`). After the `await`, if `_generation != gen` the result is discarded and `_page` is rolled back — a `refreshDeals` call that ran during the fetch has made this data stale.

**Why generation counter over `_isRefreshing` flag:** `_isRefreshing` saves one network call (stops `loadMore` before it starts) but does not handle refresh-over-refresh races. Generation counter handles both directions — any operation that arrives late is discarded regardless of which triggered the other. The log output is also more debuggable.

**Time spent:** ~45 min

---

### RES-105 — Full-list rebuild + unbounded image cache ❌ Not fixed

**File:** `lib/feature/home/home_screen.dart`, `lib/feature/shared_widget/deal_card.dart`

**Root cause (two parts):**
1. The root `Obx` wraps the entire `Scaffold`, meaning any observable change (including `scrollOffset` on every scroll frame) triggers a rebuild of the whole screen, not just the widget that changed.
2. `TheNetworkImage` has no `cacheWidth`/`cacheHeight` limit; loading full-resolution images for thumbnail-sized cards wastes memory and causes jank.

**Fix needed:** Split the `Obx` scopes — wrap only `AppBar.elevation` in its own `Obx`, and wrap `DealCard` instances in `RepaintBoundary`. For images, pass `cacheWidth` constraints to limit decoded bitmap size.

**Time spent:** 0 min (identified, not fixed)

---

### RES-106 — Pickup time displayed in UTC instead of UTC+7 ✅ Fixed

**File:** `lib/model/pickup_window_model.dart`

**Root cause:** Two separate bugs in the same model:

1. **`label`** — `DateFormat('HH:mm').format(start)` is called on a UTC `DateTime`. `DateFormat.format()` formats the DateTime as-is in its own timezone — so a UTC `DateTime` renders as UTC time, 7 hours behind Bangkok. Users see "10:30 – 14:00" instead of "17:30 – 21:00".

2. **`isToday`** — `start.day == DateTime.now().day` compares the UTC calendar day of `start` against the local-device calendar day of `now`. If the device is in a different timezone, or if the window spans UTC midnight, the `.day` comparison gives the wrong answer.

**Why `isOpenNow` / `untilStart` are fine:** Both use `DateTime.now()` in a comparison or `.difference()` call. Dart normalises UTC vs local DateTimes to epoch milliseconds for these operations — they are timezone-safe without any conversion.

**Fix applied:** Added a `static const _bangkokOffset = Duration(hours: 7)` and two private getters `_startBkk` / `_endBkk` that apply `.toUtc().add(_bangkokOffset)`. Updated `label` to format the Bangkok-local DateTimes, and updated `isToday` to compare year/month/day against `DateTime.now().toUtc().add(_bangkokOffset)` for a three-field equality (year + month + day) to avoid cross-month edge cases.

**Why not `package:timezone`?** The project uses no timezone package and Bangkok is always UTC+7 (no daylight saving), so a plain `Duration(hours: 7)` offset is accurate and adds no dependency.

**Time spent:** ~15 min

---

### RES-107 — `Get.arguments` is null on deep-link navigation ✅ Fixed

**Files:** `lib/feature/deal/deal_details_controller.dart`, `lib/feature/deal/deal_details_screen.dart`

**Root cause:** Two layered issues:

1. **`Get.arguments` is null when the screen is opened via a deep link.** In-app navigation passes a `DealModel` directly via `arguments`, but a deep link (`rescu://open/deal?id=42&source=push`) has no `arguments` — GetX only parses the URL and places `{'id': '42'}` in `Get.parameters`. The original cast `Get.arguments as DealModel` therefore casts `null`, which throws at runtime.

2. **Flutter draws the screen the moment the route opens — it does not wait for `onInit()` to finish.** Even after fixing the null by fetching from `Get.parameters['id']`, `fetchById()` is async. By the time `build()` runs for the first time, `deal` has not been set yet → `LateInitializationError`.

**Fix applied:**

When the screen is opened via a deep link, the original `Get.arguments as DealModel` tries to cast `null` into a `DealModel`, which throws an exception at runtime. The fix changes the cast to `Get.arguments as DealModel?` (nullable) so the cast never throws — if `null`, it falls back to `Get.parameters['id']` and fetches the deal from the repository instead.

However, `fetchById()` is async, which means `deal` is not yet set when Flutter draws the screen for the first time. To prevent a crash from this async timing, `isLoading = true.obs` is added to hold the screen at a spinner until the fetch completes. If the fetch fails, `hasError = true.obs` signals the screen to show an error message with a Go back button instead of trying to render an uninitialized `deal`.

**Time spent:** ~30 min

---

## Part B: Features

### F-1 — Live flash-sale countdown ✅ Fixed

**Files:** `lib/feature/shared_widget/flash_sale_countdown.dart` (new), `lib/feature/shared_widget/deal_card.dart`, `lib/feature/home/widget/flash_deals_section.dart`, `lib/feature/deal/deal_details_screen.dart`

**Root cause:** Flash deals showed a static `"Ends soon"` badge with no live time. `DealModel.flashSaleEndsAt` existed but was unused in the UI.

**Fix applied:**

Created `FlashSaleCountdown` widget in `lib/feature/shared_widget/` (shared across all three locations) and replaced the static badge everywhere:

- **`DealCard`** (home feed) — shows `FlashSaleCountdown` inside the red FLASH SALE badge
- **`FlashDealsSection`** (flash rail) — replaces static `"Ends soon"` label with `FlashSaleCountdown`
- **`DealDetailsScreen`** — adds a red banner row "Flash sale ends in `hh:mm:ss`" below the price, only shown when `deal.isFlashSale`

`FlashSaleCountdown` uses `Stream.periodic(Duration(seconds: 1))` + `StreamBuilder` — same lifecycle-safe pattern as RES-102; no `dispose()` needed. `_buildText()` formats as `mm:ss` under an hour and `hh:mm:ss` at or above an hour, switching to `'Ended'` once `flashSaleEndsAt` is past. The `color` parameter (default `Colors.white`) keeps text readable on both red and white backgrounds.

**Time spent:** ~30 min

---

### F-2 — Deal impression tracking ✅ Implemented

**Files:** `lib/feature/shared_widget/impression_tracker.dart` (new), `lib/service/analytics_service.dart`, `lib/feature/home/home_screen.dart`, `lib/feature/home/widget/flash_deals_section.dart`, `lib/feature/search/search_screen.dart`, `lib/main.dart`

**What the spec required:**
- Fire `deal_impression` when a `DealCard` is ≥ 50% visible for ≥ 1 second
- Log `deal_id`, `source` (home_feed / flash_rail / search), and `position` (index in list)
- Each deal ID must be logged at most once per session
- Batch events and send via `FakeApiService.sendAnalyticsBatch()` at 10 events or every 15 seconds
- Must not hurt scroll performance

**Fix applied:**

**`ImpressionTracker` widget** (`shared_widget/impression_tracker.dart`) — a `StatefulWidget` that wraps `VisibilityDetector` from the `visibility_detector` package. When `visibleFraction >= 0.5`, it starts a 1-second `Timer`. If the card scrolls out before the timer fires, the timer is cancelled immediately. Zero `setState` calls — the widget only manages the timer in its state; the child never rebuilds.

**Session dedup** — `Set<int> _seenDealIds` in `AnalyticsService`. `logImpression()` returns early if the deal ID is already in the set, so each deal fires at most one event for the life of the app session. No persistence required.

**Batching** — Added `_pending` buffer and `_batchTimer` to `AnalyticsService`. The timer is started lazily (`_batchTimer ??= Timer(...)`) on the first queued event, so the 15-second window measures from the first unsent event, not reset per event. At 10 events the batch flushes immediately. `onClose()` flushes any remaining events so nothing is lost on app exit.

**Scroll performance** — `VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500)` set in `main()` before `initDependencies()`. This throttles visibility callbacks to at most once per 500ms instead of every frame, removing per-frame work during scroll.

**Integration** — Wrapped each deal list with `ImpressionTracker`:
- `HomeScreen` — `.indexed.map()` over `visibleDeals` with `source: 'home_feed'`
- `FlashDealsSection` — `itemBuilder` with `source: 'flash_rail'`
- `SearchScreen` — `itemBuilder` with `source: 'search'`

Each tracker uses `Key('imp-<source>-<deal.id>')` so `VisibilityDetector` can reliably track identity across rebuilds.

**Verified via logs:** Observed `POST /analytics/batch events=10` when 10 unique deals were seen, and `POST /analytics/batch events=3` after 15 seconds for a smaller batch. Revisiting already-seen cards produced no additional log entries or API calls.

**Time spent:** ~60 min

---

### F-3 — Stock reservations with optimistic UI ✅ Implemented (one known limitation)

**Files:** `lib/main.dart`, `lib/service/cart_service.dart`, `lib/feature/cart/cart_controller.dart`, `lib/feature/cart/cart_screen.dart`, `lib/model/cart_item_model.dart` (doc comment only). No changes to `lib/service/fake_api_service.dart`, `lib/repository/order_repo.dart`, or `lib/model/reservation_model.dart` — the reservation API (`reserveDeal`/`releaseReservation`/`checkout`) and models already existed, unused.

**What the spec required:**
- Adding to the bag reserves stock; the UI responds optimistically, then reconciles (rollback with a non-technical message if the reservation fails)
- Each bag line shows how long its reservation has left
- Removing a line / reducing quantity releases or adjusts the hold
- Checkout passes reservation ids; handle the `410 reservation expired` rejection gracefully
- Deliberately underspecified: decide what happens when a reservation expires while the user is still in the app (or mid-checkout)

**Fix applied:**

**DI wiring:** `CartService` now takes `OrderRepo` as a constructor dependency. `main.dart` registers `DealRepo`/`StoreRepo`/`OrderRepo` (`lazyPut`) *before* `Get.put(CartService(orderRepo: Get.find()))`, since `Get.find()` resolves eagerly at that call site — reversing the order throws `"OrderRepo" not found` at startup.

**Optimistic add + rollback (`CartService.add`):** The cart line is added to `items` synchronously, before any `await`, so the UI updates instantly. `orderRepo.reserve(dealId)` is then awaited; on success the returned `ReservationModel` is attached to the line. On `ApiException(409)` the line is rolled back (quantity decremented, or removed if it was the only unit) and a snackbar shows a plain-language message ("Someone just grabbed this item. Please try again.") — no status code or exception text reaches the user. A per-deal generation counter (same technique as RES-104's `_generation` field) discards a `reserve()` response that resolves after a newer request for the same deal, so rapid taps on "+" can't let a stale response clobber a newer one.

**Time-left per line:** Reused `FlashSaleCountdown` (built for F-1) unmodified — it only needs a `DateTime endsAt`, and `ReservationModel.expiresAt` fits directly. No new widget was written; `StreamBuilder` already disposes its `Stream.periodic` subscription safely (same pattern validated for RES-102/F-1). While a reservation is still in flight the line shows "Reserving..." instead.

**Release on decrement/remove:** `decrement`/`remove`/`clear` in `CartService` call `orderRepo.releaseReservation(id)` (fire-and-forget, failure logged) for whatever reservation is dropped, so the hold is freed immediately rather than waiting out its 5-minute natural expiry — stock becomes visible to other users sooner.

**Checkout 410 handling:** `CartController.checkout()` branches on `ApiException.statusCode`. A `410` calls `CartService.dropExpiredReservations()` to drop the expired line(s) and shows "Some items timed out. Please add them again." instead of the generic failure message. Other status codes (e.g. the simulated 502 payment-gateway timeout) keep the original generic handling.

**Design decision — reservation expires while still in the app:** Chose a **proactive** approach over a **reactive** one. `CartController.onInit()` starts a `Timer.periodic(1s)` (cancelled in `onClose()` — the RES-102 lesson applies directly here) that calls `dropExpiredReservations()` on every tick; an expired line is removed immediately with a snackbar ("Reservation timed out..."), and the displayed total updates automatically. Rejected alternative: leave the line sitting in the bag until the user tries to check out. That defers the bad experience rather than avoiding it — checkout would reject the line anyway (410), and in the meantime the bag would display a total and quantity that no longer reflect anything actually held on the server.

**Known limitation — cannot be closed without touching the read-only backend:** `FakeApiService.reserveDeal` checks `quantityLeft` but never decrements it; only `checkout` decrements it, and `checkout` never re-validates against other reservations still outstanding for the same deal. Two devices reserving the last unit inside the same time window can therefore both receive a valid reservation and both successfully check out, overselling the item — the exact scenario the feature's own motivation describes. This is a concurrency gap in the simulated backend (`fake_api_service.dart`, read-only per CLAUDE.md `ห้ามแตะ`), not something fixable from the client. The client-side work above only guarantees correct, graceful handling of whatever 409/410 the backend actually returns — it narrows the window (prompt release on decrement/remove/expiry) but cannot make cross-device reservation atomic.

#### What F-3's own motivation asks for that this solution cannot fully deliver

F-3 opens with: *"two users can 'add' the last bag and one of them finds out only at pickup"* — the feature is meant to close that gap. It cannot be closed completely, specifically because of two things inside `fake_api_service.dart` (read-only, `ห้ามแตะ`):

1. **`reserveDeal` never decrements stock at reservation time** (`fake_api_service.dart:126-155`) — it only checks `quantityLeft < quantity` and rejects if insufficient, but the reservation it creates does not reduce `quantityLeft`. Two `reserveDeal` calls for the same deal, arriving before either resolves, both read the same unreduced `quantityLeft` and both pass the check — so **both get a valid reservation for what is really one physical unit.**
2. **`checkout` never re-validates a reservation against other outstanding reservations for the same deal** (`fake_api_service.dart:166-220`) — it only checks that the reservation exists and hasn't expired, then decrements `quantityLeft` clamped to `0` (never throwing for insufficient stock) and never removes the reservation record afterward. So **both devices from point 1 can also both `checkout` successfully** — two `CONFIRMED` orders for one unit.

Fixing either would require editing `fake_api_service.dart` (e.g. decrementing `quantityLeft` atomically inside `reserveDeal`, and having `checkout` reject if the combined quantity of still-valid reservations exceeds stock) — not permitted under this assessment's rules. As a result, F-3 as implemented guarantees correct, graceful client behavior for every 409/410 the backend *does* return, and shortens the exposure window (prompt release on decrement/remove, proactive expiry), but it cannot guarantee the last unit is never oversold end-to-end — that guarantee can only come from the backend.

**Time spent:** ~90 min

---

## Summary

| ID | Status | Notes |
|---|---|---|
| RES-101 | ✅ Fixed | Last-write-wins guard via `_activeQuery` |
| RES-102 | ✅ Fixed | Replaced `Timer.periodic` + `setState` with `Stream.periodic` + `StreamBuilder` |
| RES-103 | ✅ Fixed | Removed `ever()` entirely; `addToCart()` decrements `_quantityLeft` optimistically |
| RES-104 | ✅ Fixed | Generation counter discards stale loadMore/refresh results |
| RES-105 | ❌ Not fixed | `Obx` scope too wide; no image cache bounds |
| RES-106 | ✅ Fixed | Convert UTC → UTC+7 via `_bangkokOffset` before formatting and `.day` compare |
| RES-107 | ✅ Fixed | Nullable cast + isLoading/hasError guards for deep-link entry |
| F-1 | ✅ Fixed | Live `mm:ss` / `hh:mm:ss` countdown in DealCard, flash rail, and DealDetailsScreen |
| F-2 | ✅ Implemented | `ImpressionTracker` widget + session dedup + batch 10/15 s |
| F-3 | ✅ Implemented | Optimistic reserve/rollback, per-line countdown, release on decrement/remove, 410 handling, proactive expiry ticker — known limitation: backend doesn't prevent true concurrent double-reservation of the last unit |

**Total time logged:** ~365 min (RES-101: ~25 min, RES-102: ~40 min, RES-103: ~60 min, RES-104: ~45 min, RES-106: ~15 min, RES-107: ~30 min, F-1: ~30 min, F-2: ~60 min, F-3: ~90 min)
