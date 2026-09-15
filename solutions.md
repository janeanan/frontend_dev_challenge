# Solutions — Rescu Flutter Assessment

## AI Tools Used

Used **Claude Code** (Anthropic's CLI) as an assistant throughout this assessment — helping analyze, understand, and explain the codebase in order to arrive at fix approaches for the various tickets. Two supporting tools were set up:

**CLAUDE.md** — a context file describing the project structure, stack, bug tickets, and the read-only rules (`fake_api_service.dart`, `assets/data/`), loaded by Claude at the start of the conversation instead of being re-explained every time, so Claude could answer questions and fix code accurately without guessing at context.

**graphify** — a tool that builds a knowledge graph from the codebase (529 nodes, 652 edges) and lets you query it in natural language, e.g. `graphify query "where is ever() called"`, instead of opening files one by one. It helped find bug root causes faster, especially for bugs that span multiple files, such as RES-103 (listener lifecycle) and RES-107 (deep link entry point).

### AI Usage Log — Approaches That Changed Along the Way

**RES-102:** The AI's first suggestion was `dispose()` + a stored `Timer`, which is correct Flutter practice — but the dev felt that since this project is built primarily around GetX controllers, adding a separate `dispose()` in a `StatefulWidget` created extra maintenance burden. The dev chose `Stream.periodic` + `StreamBuilder` instead, which lets Flutter manage the lifecycle automatically, with no `dispose()` to write.

**RES-103:** The AI suggested an `isClosed` guard as one approach, but the dev pointed out that the `Worker` would still be left alive in memory, and a `dispose()` in `onClose()` would still be needed regardless. The dev noted that since the controller already receives `quantityLeft` from the model on its first `onInit()`, decrementing it optimistically inside `addToCart()` was the better fit — no `Worker` is ever created, so there is nothing to manage.

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

### RES-105 — Full-list rebuild + unbounded image cache ✅ Fixed

**Files:** `lib/feature/home/home_screen.dart`, `lib/feature/shared_widget/the_network_image.dart`

**Root cause (two independent contributing causes, confirmed with Flutter DevTools):**

1. **`Obx` scope too wide.** The original `build()` wrapped the entire `Scaffold` (AppBar + full deal list + FAB) in one `Obx`. `HomeController._onScroll()` sets `scrollOffset.value = scrollController.offset` on every scroll frame (`home_controller.dart:44`), but `scrollOffset` is only actually used for two small things — the AppBar's elevation and the FAB's visibility. Because `Obx` rebuilds everything inside its builder whenever any `.obs` value it reads changes, one scroll frame rebuilt the whole screen, including every `DealCard` in the list. `home_screen.dart` also used `ListView(children: [...])` (eager) rather than `ListView.builder`, so every deal card — not just the ones on screen — was constructed on each of those rebuilds, compounding the cost.
2. **No cache-size limit on images.** `TheNetworkImage` passed no `memCacheWidth`/`memCacheHeight` to `CachedNetworkImage`, so a 1600×1200 source image (from `picsum.photos`) was decoded into memory at full resolution even when displayed at 64–160px. Memory grows roughly linearly with the number of distinct images scrolled past, exactly matching the reported symptom ("memory grows the further you scroll").

**DevTools evidence (Performance tab, Frame Analysis):**

- **Before:** during an ordinary scroll gesture, consecutive frames showed sustained jank — e.g. frame 19795: `Build: 20.7 ms` / `Raster: 1.0 ms` (UI-jank detected, well over the 16.6 ms/60fps budget). Raster stayed low throughout, confirming the cost was in widget construction (`Build`), not painting.
- **After splitting `Obx` into three narrow scopes** (`AppBar` via `PreferredSize(child: Obx(...))`, the list `body`, and the `floatingActionButton`, each reading only the `.obs` values it needs) **and switching to `ListView.builder`:** the same scroll gesture produced consistently low, jank-free frames (`Rebuild Stats` / frame chart showed near-0ms bars with no orange "Jank" markers), confirmed both in DevTools and by hand-testing the running app.
- Two isolated jank spikes were observed and deliberately **not** attributed to this bug after inspection: (a) the very first frame after initial data load (`isLoading` flipping to `false`) — `Rebuild Stats` showed `CachedNetworkImage` × 7 and `Icon`/`SizedBox`/`Text` (from `FlashSaleCountdown`) × 5, matching exactly the number of cards visible on screen — i.e. the one-time cost of constructing the initial visible viewport, not a rebuild loop; and (b) a jank frame immediately following a hot reload, which is a Flutter tooling artifact (widget-tree reconciliation + shader warm-up on the Impeller engine) that never occurs outside of development. Neither matches the reported symptom, which is specifically about degradation *while scrolling*.

**Fix applied:**

1. **`home_screen.dart`** — replaced the single wide `Obx` with three narrowly-scoped ones: `Obx(() => AppBar(elevation: ...))` (wrapped in `PreferredSize` since `Scaffold.appBar` requires a `PreferredSizeWidget`), a separate `Obx` for `body` that reads only `isLoading`/`flashDeals`/`visibleDeals`/`todayOnly`, and a separate `Obx` for `floatingActionButton` (returning `SizedBox.shrink()` instead of `null`, since `Obx`'s builder must return a non-null `Widget`). Also converted the deal list from `ListView(children: [...])` to `ListView.builder`, so off-screen cards are not constructed until they scroll into view. `ImpressionTracker`'s `Key('imp-home-${deal.id}')` was preserved unchanged so F-2's visibility tracking keeps working correctly under lazy building.
2. **`the_network_image.dart`** — added `memCacheWidth`/`memCacheHeight`, computed as `(width|height) * devicePixelRatio` and passed to `CachedNetworkImage`, but only when the caller supplies a finite value (`width!.isFinite` guard). `DealCard`/`FlashDealsSection` pass `width: double.infinity`, so only `memCacheHeight` applies there; `deal_details_screen.dart`'s hero image passes neither `width` nor `height` (intentionally full-resolution), so both stay `null` and it is unaffected.

**Why not `RepaintBoundary` per card (considered, not applied):** `RepaintBoundary` isolates *repaint* cost, but the measured bottleneck was `Build` (widget construction), not `Raster` (painting) — a `RepaintBoundary` would not have addressed the actual cost shown in DevTools. Splitting the `Obx` scope addresses the root cause directly.

**Time spent:** ~70 min

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

**Known limitation — cannot be closed without touching the read-only backend:** `FakeApiService.reserveDeal` checks `quantityLeft` but never decrements it; only `checkout` decrements it, and `checkout` never re-validates against other reservations still outstanding for the same deal. Two devices reserving the last unit inside the same time window can therefore both receive a valid reservation and both successfully check out, overselling the item — the exact scenario the feature's own motivation describes. This is a concurrency gap in the simulated backend (`fake_api_service.dart`, marked read-only in CLAUDE.md), not something fixable from the client. The client-side work above only guarantees correct, graceful handling of whatever 409/410 the backend actually returns — it narrows the window (prompt release on decrement/remove/expiry) but cannot make cross-device reservation atomic.

#### What F-3's own motivation asks for that this solution cannot fully deliver

F-3 opens with: *"two users can 'add' the last bag and one of them finds out only at pickup"* — the feature is meant to close that gap. It cannot be closed completely, specifically because of two things inside `fake_api_service.dart` (read-only, per CLAUDE.md):

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
| RES-105 | ✅ Fixed | Split `Obx` into 3 narrow scopes + `ListView.builder`; added `memCacheWidth/Height` — verified jank-free scroll in DevTools |
| RES-106 | ✅ Fixed | Convert UTC → UTC+7 via `_bangkokOffset` before formatting and `.day` compare |
| RES-107 | ✅ Fixed | Nullable cast + isLoading/hasError guards for deep-link entry |
| F-1 | ✅ Fixed | Live `mm:ss` / `hh:mm:ss` countdown in DealCard, flash rail, and DealDetailsScreen |
| F-2 | ✅ Implemented | `ImpressionTracker` widget + session dedup + batch 10/15 s |
| F-3 | ✅ Implemented | Optimistic reserve/rollback, per-line countdown, release on decrement/remove, 410 handling, proactive expiry ticker — known limitation: backend doesn't prevent true concurrent double-reservation of the last unit |

**Total time logged:** ~435 min (RES-101: ~25 min, RES-102: ~40 min, RES-103: ~60 min, RES-104: ~45 min, RES-105: ~70 min, RES-106: ~15 min, RES-107: ~30 min, F-1: ~30 min, F-2: ~60 min, F-3: ~90 min)

---

## Design Questions

### Q1 — `GetxController` lifecycle vs widget `State` lifecycle

A widget's `State` always disappears together with the widget itself — the moment a widget is removed from the screen, Flutter guarantees `dispose()` is called. A `GetxController` is different: when it disappears is something we decide ourselves at the time we create it — we can choose to let it disappear together with the screen it belongs to (the default), or keep it alive forever until the app closes.

**Example — RES-103:** every time the deal-details screen is opened and closed, one `ever()` listener is left behind, never destroyed. When the cart later changes (e.g. tapping "Add to bag"), every listener left over from all previous visits fires at once, each sending a duplicate `GET /deals/{id}` request.

A fix that was considered:
```dart
_cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability()); // store it in a field, then
_cartWorker?.dispose(); // call dispose() to fix it
```

But `addToCart()` was chosen to update optimistically instead, since adding an item to the bag is an action whose outcome we already know locally — decrementing the value in memory immediately avoids waiting on an extra round-trip to the server. Checking `FakeApiService` further showed that `quantityLeft` is only adjusted at checkout time, not when an item is added to the bag, so re-fetching after `addToCart()` would return the same value anyway.

### Q2 — When does wrapping a large subtree in a single `Obx` hurt you? How do you decide how tightly to scope reactivity?

`Obx` rebuilds everything wrapped inside it as one block, every time any `.obs` value it reads changes — it doesn't matter whether that value is actually used by just one small part of the subtree. This starts to hurt once **(1)** the observed value changes at high frequency (e.g. `scrollOffset`, which changes on every scroll frame), and **(2)** the wrapped subtree is large or expensive to build (e.g. a list of cards with several images each).

To decide how tightly to scope it, I go through every `.obs` value a given `Obx` reads and ask "which widgets actually use this value?" — then wrap only that widget in its own small `Obx`, instead of wrapping a whole screen just because one small part of it needs to be reactive.

**Example — RES-105:** `home_screen.dart` originally wrapped a single `Obx` around the entire `Scaffold`, even though only the `AppBar`'s elevation and the FAB's visibility depended on `scrollOffset`. Splitting it into three narrowly-scoped `Obx` widgets (AppBar, deal list, FAB) meant scrolling no longer rebuilt the whole list. DevTools confirmed this: Build time per frame dropped from ~20ms (jank-flagged) to consistently under the 16ms/60fps budget.

### Q3 — How would you write an automated test that would have caught RES-106 before release? What (if anything) would you change in the code to make such a test possible?

I had never written an automated test before this assessment, and I did not actually add a test file to this project for RES-106. Reading the ticket, my understanding was that the time was displaying incorrectly because UTC has an offset of 0, so I added 7 hours to match local (Bangkok) time.

If I had to check this, I would feed in `start`/`end` values that are UTC, then verify whether the output displays as Bangkok time (+7 hours), not the original UTC value.

---

## Time Spent & Next Steps

**Time spent:** see the summary table above (~435 minutes total).

**What I'd do next with one more day:** not add new features, but spend it deepening my understanding of two things this assessment kept surfacing — GetX's lifecycle (`onInit`/`onReady`/`onClose`, the dependency-injection registry, and what actually guarantees a controller gets disposed) and writing automated tests. Neither is a new concept in general, but I'm not comfortable with either yet, and working through RES-102, RES-103, and RES-105 made that gap clear. With more time I'd actually write and run the tests sketched in Q3, and practice scoping `Obx`/GetX lifecycle correctly.
