# Solutions — Rescu Flutter Assessment

## AI Tools Used

ใช้ **Claude Code** (Anthropic's CLI) เป็นตัวช่วยตลอดการทำ assessment นี้ โดยติดตั้งเครื่องมือเสริม 2 อย่าง:

**CLAUDE.md** — ไฟล์ context ที่อธิบายโครงสร้างโปรเจค, stack, bug tickets, และกฎที่ห้ามแตะ (`fake_api_service.dart`, `assets/data/`) ให้ Claude อ่านตั้งแต่ต้น conversation แทนที่จะต้องอธิบายซ้ำทุกครั้ง เพื่อให้ Claude ตอบคำถามและแก้โค้ดได้ตรงจุดโดยไม่ต้องเดา context

**graphify** — เครื่องมือที่สร้าง knowledge graph จาก codebase (529 nodes, 652 edges) แล้วให้ query ด้วยภาษาธรรมชาติเช่น `graphify query "where is ever() called"` แทนที่จะต้องเปิดไฟล์ทีละไฟล์ ช่วยให้หา root cause ของ bug ได้เร็วขึ้น โดยเฉพาะ bug ที่กระจายข้าม file เช่น RES-103 (listener lifecycle) และ RES-107 (deep link entry point)

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

### RES-104 — Duplicate deals when refreshing during loadMore ❌ Not fixed

**File:** `lib/feature/home/home_controller.dart:58-63`

**Root cause:** `refreshDeals()` resets `_page = 1` and calls `deals.assignAll()`, but it does not guard against a concurrent `loadMore`. If both run simultaneously: `loadMore` increments `_page` and is awaiting; `refreshDeals` resets `_page = 1` and replaces `deals` with page-1 items; then `loadMore` resolves and calls `deals.addAll()` with page-2 results on top — producing a list that mixes fresh page-1 with page-2, or worse, page-1 duplicates if loadMore was fetching page 1 as well.

**Fix needed:** In `refreshDeals()`, set `_isFetchingMore = false` and reset the flag before the `assignAll` call, or cancel any in-flight loadMore. A simple approach: `if (_isFetchingMore) { _isFetchingMore = false; }` at the top of `refreshDeals`, then proceed.

**Time spent:** 0 min (identified, not fixed)

---

### RES-105 — Full-list rebuild + unbounded image cache ❌ Not fixed

**File:** `lib/feature/home/home_screen.dart`, `lib/feature/shared_widget/deal_card.dart`

**Root cause (two parts):**
1. The root `Obx` wraps the entire `Scaffold`, meaning any observable change (including `scrollOffset` on every scroll frame) triggers a rebuild of the whole screen, not just the widget that changed.
2. `TheNetworkImage` has no `cacheWidth`/`cacheHeight` limit; loading full-resolution images for thumbnail-sized cards wastes memory and causes jank.

**Fix needed:** Split the `Obx` scopes — wrap only `AppBar.elevation` in its own `Obx`, and wrap `DealCard` instances in `RepaintBoundary`. For images, pass `cacheWidth` constraints to limit decoded bitmap size.

**Time spent:** 0 min (identified, not fixed)

---

### RES-106 — Pickup time displayed in local timezone instead of UTC+7 ❌ Not fixed

**File:** `lib/model/pickup_window_model.dart`

**Root cause:** `DateFormat('HH:mm').format(start)` calls `format()` on a UTC `DateTime` without converting it to Bangkok time (UTC+7) first. Dart's `DateTime.parse()` on an ISO-8601 UTC string returns a UTC instance; `DateFormat.format()` on a UTC instance uses the *device's* local timezone, not UTC+7. For a user in a different timezone, `label`, `isToday`, and `isOpenNow` are all wrong.

**Fix needed:** Convert before formatting: `start.toUtc().add(const Duration(hours: 7))`. Alternatively add `package:timezone` and use `TZDateTime`.

**Time spent:** 0 min (identified, not fixed)

---

### RES-107 — `Get.arguments` is null on deep-link navigation ❌ Not fixed

**File:** `lib/feature/deal/deal_details_controller.dart:28`

**Root cause:** `deal = Get.arguments as DealModel` assumes the screen is always opened by pushing a route with a `DealModel` argument. When the screen is opened via a deep link (`rescu://open/deal?id=42&source=push`), the middleware calls `Get.toNamed('/deal?id=42&source=push')` with no `arguments`, so `Get.arguments` is `null` and the cast throws.

**Fix needed:** In `onInit()`, check `Get.arguments`: if it is a `DealModel`, use it directly; otherwise fall back to `Get.parameters['id']` and call `dealRepo.fetchById()` to load the deal, showing a loading state in the UI meanwhile.

**Time spent:** 0 min (identified, not fixed)

---

## Part B: Features

### F-1 — Live flash-sale countdown ❌ Not implemented

**Scope:** `DealCard` (home feed + flash rail), `FlashDealsSection`, `DealDetailsScreen`.

**Plan (not executed):**
- Extend `DealModel` with a computed getter `flashSaleSecondsRemaining` based on `flashSaleEndsAt`.
- Add a `CountdownTimer` widget similar to `PickupCountdown` that shows `mm:ss` and rebuilds every second.
- When `flashSaleEndsAt` is past: disable the "Add to bag" button and call `CartService.remove()` for any cart item referencing this deal.
- The `Timer` must be cancelled in `dispose()` (lesson from RES-102).

---

### F-2 — Deal impression tracking ❌ Not implemented

**Scope:** `DealCard` wherever it appears (home feed, flash rail, search results).

**Plan (not executed):**
- Use a `VisibilityDetector` (or `IntersectionObserver`-style approach) to detect when ≥ 50% of a `DealCard` is on screen for ≥ 1 second.
- Maintain a `Set<int>` of deal IDs already logged this session to fire each event only once.
- Log `deal_impression` via `AnalyticsService.logEvent()`, which already batches at 10 events or 15 s.

**Key decision:** Session-scoped dedup lives in memory (no persistence needed per spec). The 1-second timer must be cancelled if the card scrolls out before the threshold, otherwise partial-visibility triggers false impressions.

---

### F-3 — Optimistic add + reservation expiry ❌ Not implemented

**Scope:** `CartService`, `CartScreen`, `DealDetailsScreen`.

**Plan (not executed):**
- On "Add to bag", call `FakeApiService.reserveDeal()` immediately and store the returned `reservationId` alongside the cart item.
- Show the item optimistically (already in cart) while the reservation completes; roll back + show a snackbar if it fails.
- Each `CartItemModel` gets an `expiresAt = DateTime.now().add(Duration(minutes: 5))`. A periodic timer in `CartService` removes expired items and notifies the user.
- `CartService.checkout()` already forwards `reservationId` per line — this just ensures the ID is populated.

---

## Summary

| ID | Status | Notes |
|---|---|---|
| RES-101 | ✅ Fixed | Last-write-wins guard via `_activeQuery` |
| RES-102 | ❌ Not fixed | Timer reference needs to be stored and cancelled |
| RES-103 | ❌ Not fixed | `ever()` worker needs to be disposed in `onClose()` |
| RES-104 | ❌ Not fixed | `refreshDeals` must reset `_isFetchingMore` flag |
| RES-105 | ❌ Not fixed | `Obx` scope too wide; no image cache bounds |
| RES-106 | ❌ Not fixed | Must convert UTC → UTC+7 before formatting |
| RES-107 | ❌ Not fixed | Must handle null `Get.arguments` for deep-link entry |
| F-1 | ❌ Not implemented | Countdown widget + cart eviction on expiry |
| F-2 | ❌ Not implemented | VisibilityDetector + session dedup + batch log |
| F-3 | ❌ Not implemented | Optimistic reserve + 5-min expiry timer |

**Total time logged:** ~25 min (RES-101 only)
