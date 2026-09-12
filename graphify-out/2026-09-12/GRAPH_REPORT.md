# Graph Report - .  (2026-09-09)

## Corpus Check
- Corpus is ~17,961 words - fits in a single context window. You may not need a graph.

## Summary
- 529 nodes · 652 edges · 42 communities (33 shown, 9 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.92)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Cart & Checkout Flow|Cart & Checkout Flow]]
- [[_COMMUNITY_GetX Controller Base|GetX Controller Base]]
- [[_COMMUNITY_Repository & Data Layer|Repository & Data Layer]]
- [[_COMMUNITY_Home Feed & Pagination|Home Feed & Pagination]]
- [[_COMMUNITY_Fake API Service|Fake API Service]]
- [[_COMMUNITY_Flash Deals & Orders UI|Flash Deals & Orders UI]]
- [[_COMMUNITY_Analytics & Route Middleware|Analytics & Route Middleware]]
- [[_COMMUNITY_Flutter Native Bridge|Flutter Native Bridge]]
- [[_COMMUNITY_Feature Controllers Bundle|Feature Controllers Bundle]]
- [[_COMMUNITY_DI Route Bindings|DI Route Bindings]]
- [[_COMMUNITY_App Theme & Config|App Theme & Config]]
- [[_COMMUNITY_Deal Data Model|Deal Data Model]]
- [[_COMMUNITY_Architecture Concepts|Architecture Concepts]]
- [[_COMMUNITY_iOS App Icons|iOS App Icons]]
- [[_COMMUNITY_Store Data Model|Store Data Model]]
- [[_COMMUNITY_Pickup Window Model|Pickup Window Model]]
- [[_COMMUNITY_Countdown Timer Widget|Countdown Timer Widget]]
- [[_COMMUNITY_Reservation Model|Reservation Model]]
- [[_COMMUNITY_Cart Item Model|Cart Item Model]]
- [[_COMMUNITY_Paged Response Model|Paged Response Model]]
- [[_COMMUNITY_Bug Tickets & Services|Bug Tickets & Services]]
- [[_COMMUNITY_iOS CocoaPods Scripts|iOS CocoaPods Scripts]]
- [[_COMMUNITY_API Exception|API Exception]]
- [[_COMMUNITY_iOS Debug Tools|iOS Debug Tools]]
- [[_COMMUNITY_Android Plugin Registrant|Android Plugin Registrant]]
- [[_COMMUNITY_Android Launcher Icons|Android Launcher Icons]]
- [[_COMMUNITY_Log Service|Log Service]]
- [[_COMMUNITY_Model Tests|Model Tests]]
- [[_COMMUNITY_Android Main Activity|Android Main Activity]]
- [[_COMMUNITY_iOS Path Provider Pod|iOS Path Provider Pod]]
- [[_COMMUNITY_iOS Pods Runner|iOS Pods Runner]]
- [[_COMMUNITY_iOS Runner Tests Pod|iOS Runner Tests Pod]]
- [[_COMMUNITY_iOS SQLite Pod|iOS SQLite Pod]]
- [[_COMMUNITY_iOS Launch Images|iOS Launch Images]]
- [[_COMMUNITY_Project README|Project README]]
- [[_COMMUNITY_Flutter Environment|Flutter Environment]]
- [[_COMMUNITY_Dart Lint Config|Dart Lint Config]]
- [[_COMMUNITY_DevTools Settings|DevTools Settings]]
- [[_COMMUNITY_Launch Screen Docs|Launch Screen Docs]]

## God Nodes (most connected - your core abstractions)
1. `App Icon 1024x1024@1x — Flutter default logo; two sky-blue geometric chevrons (light #4FC3F7) on white with navy-blue (#0D47A1) accent at lower-right; geometric/flat-design style; canonical App Store resolution` - 14 edges
2. `UIKit` - 6 edges
3. `install_framework()` - 5 edges
4. `AppDelegate` - 5 edges
5. `DealRepo` - 5 edges
6. `AnalyticsService` - 5 edges
7. `FakeApiService` - 5 edges
8. `pubspec.yaml – Rescu Project` - 5 edges
9. `GeneratedPluginRegistrant` - 4 edges
10. `DealModel` - 4 edges

## Surprising Connections (you probably didn't know these)
- `GetX State / DI / Routing` --references--> `GetX Dependency (get ^4.6.6)`  [INFERRED]
  CLAUDE.md → pubspec.yaml
- `intl Dependency (DateFormat/Timezone)` --conceptually_related_to--> `UTC vs UTC+7 Bangkok Display Rule`  [INFERRED]
  pubspec.yaml → CLAUDE.md
- `RES-105: Home Feed Jank + Memory Leak` --references--> `cached_network_image Dependency`  [INFERRED]
  PROBLEM.md → pubspec.yaml
- `RES-101: Search Race Condition` --references--> `FakeApiService – Simulated Backend`  [INFERRED]
  PROBLEM.md → CLAUDE.md
- `RES-103: ever() Listener Accumulation` --references--> `CartService – Observable Bag`  [INFERRED]
  PROBLEM.md → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **GetX Lifecycle Bugs Cluster** — problem_res102_timer_leak, problem_res103_ever_listener_leak, claude_getx_lifecycle_vs_widget [INFERRED 0.95]
- **Async / Race Condition Bugs** — problem_res101_search_race, problem_res104_pagination_race, claude_fakeapiservice [INFERRED 0.85]
- **Analytics + Visibility Feature Group** — problem_f2_impression_tracking, claude_analyticsservice, pubspec_dep_visibility_detector [EXTRACTED 0.95]

## Communities (42 total, 9 thin omitted)

### Community 0 - "Cart & Checkout Flow"
Cohesion: 0.05
Nodes (36): dart:developer, cartService, checkout, isCheckingOut, orderRepo, initialCenter, isLoading, _load (+28 more)

### Community 1 - "GetX Controller Base"
Cohesion: 0.06
Nodes (35): app_config.dart, cart_controller.dart, deal_details_controller.dart, GetView, GetxController, home_controller.dart, CartController, build (+27 more)

### Community 2 - "Repository & Data Layer"
Cohesion: 0.06
Nodes (33): GetxService, api, DealRepo, fetchById, fetchDeals, fetchFlashDeals, search, api (+25 more)

### Community 3 - "Home Feed & Pagination"
Cohesion: 0.06
Nodes (30): dealRepo, deals, flashDeals, hasMore, _initialLoad, _isFetchingMore, isLoading, _loadFlashDeals (+22 more)

### Community 4 - "Fake API Service"
Cohesion: 0.06
Nodes (30): api_exception.dart, dart:convert, dart:math, checkout, _deals, _enrichDeal, _enrichOrder, _enrichStore (+22 more)

### Community 5 - "Flash Deals & Orders UI"
Cohesion: 0.07
Nodes (28): FlashDealsSection, build, order, _OrderTile, _SectionHeader, showCountdown, title, DealCard (+20 more)

### Community 6 - "Analytics & Route Middleware"
Cohesion: 0.08
Nodes (24): GetMiddleware, int get, AnalyticsDebugScreen, build, addToCart, analytics, cartService, deal (+16 more)

### Community 7 - "Flutter Native Bridge"
Cohesion: 0.08
Nodes (15): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, GeneratedPluginRegistrant (+7 more)

### Community 8 - "Feature Controllers Bundle"
Cohesion: 0.09
Nodes (20): Bindings, ../feature/cart/cart_controller.dart, ../feature/deal/deal_details_controller.dart, ../feature/home/home_controller.dart, ../feature/map/map_controller.dart, ../feature/order/orders_controller.dart, ../feature/search/search_deals_controller.dart, CartBinding (+12 more)

### Community 9 - "DI Route Bindings"
Cohesion: 0.08
Nodes (24): ../binding/cart_binding.dart, ../binding/deal_details_binding.dart, ../binding/home_binding.dart, ../binding/map_binding.dart, ../binding/orders_binding.dart, ../binding/search_binding.dart, ../feature/analytics_debug/analytics_debug_screen.dart, ../feature/cart/cart_screen.dart (+16 more)

### Community 10 - "App Theme & Config"
Cohesion: 0.10
Nodes (19): BorderRadius?, BoxFit, double?, AppConfig, appName, primaryGreen, theme, build (+11 more)

### Community 11 - "Deal Data Model"
Cohesion: 0.10
Nodes (20): currencyCode, description, discountPercent, flashSaleEndsAt, fromJson, id, imageUrl, isFlashSale (+12 more)

### Community 12 - "Architecture Concepts"
Cohesion: 0.13
Nodes (16): AnalyticsService – Batched Event Logging, DealModel, GetX State / DI / Routing, PickupWindowModel (UTC Timezone Bug), UTC vs UTC+7 Bangkok Display Rule, F-1: Live Flash-Sale Countdown, F-2: Deal Impression Tracking (50% visible ≥1s), RES-105: Home Feed Jank + Memory Leak (+8 more)

### Community 13 - "iOS App Icons"
Cohesion: 0.13
Nodes (15): App Icon 1024x1024@1x — Flutter default logo; two sky-blue geometric chevrons (light #4FC3F7) on white with navy-blue (#0D47A1) accent at lower-right; geometric/flat-design style; canonical App Store resolution, App Icon 20x20@1x — size variant of Flutter default logo chevron icon, App Icon 20x20@2x — size variant of Flutter default logo chevron icon, App Icon 20x20@3x — size variant of Flutter default logo chevron icon, App Icon 29x29@1x — size variant of Flutter default logo chevron icon, App Icon 29x29@2x — size variant of Flutter default logo chevron icon, App Icon 29x29@3x — size variant of Flutter default logo chevron icon, App Icon 40x40@1x — size variant of Flutter default logo chevron icon (+7 more)

### Community 14 - "Store Data Model"
Cohesion: 0.14
Nodes (13): address, category, currencyCode, fromJson, id, imageUrl, lat, lng (+5 more)

### Community 15 - "Pickup Window Model"
Cohesion: 0.18
Nodes (10): Duration get, end, fromJson, isToday, label, PickupWindowModel, start, untilStart (+2 more)

### Community 16 - "Countdown Timer Widget"
Cohesion: 0.22
Nodes (9): dart:async, build, createState, initState, PickupCountdown, _PickupCountdownState, pickupStart, State (+1 more)

### Community 17 - "Reservation Model"
Cohesion: 0.22
Nodes (8): DateTime, dealId, expiresAt, fromJson, id, isExpired, quantity, ReservationModel

### Community 18 - "Cart Item Model"
Cohesion: 0.22
Nodes (8): deal_model.dart, CartItemModel, deal, lineTotal, quantity, reservation, DealModel, reservation_model.dart

### Community 19 - "Paged Response Model"
Cohesion: 0.25
Nodes (7): bool get, fromJson, hasMore, items, page, PagedResponseModel, totalPages

### Community 20 - "Bug Tickets & Services"
Cohesion: 0.29
Nodes (8): CartService – Observable Bag, FakeApiService – Simulated Backend, GetX Controller vs Widget Lifecycle, F-3: Optimistic Stock Reservation, RES-101: Search Race Condition, RES-102: Timer Leak / setState After Dispose, RES-103: ever() Listener Accumulation, RES-104: Pagination Race (refresh + loadMore)

### Community 21 - "iOS CocoaPods Scripts"
Cohesion: 0.43
Nodes (6): code_sign_if_enabled(), install_bcsymbolmap(), install_dsym(), install_framework(), Pods-Runner-frameworks.sh script, strip_invalid_archs()

### Community 22 - "API Exception"
Cohesion: 0.33
Nodes (5): Exception, ApiException, message, statusCode, toString

### Community 23 - "iOS Debug Tools"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 24 - "Android Plugin Registrant"
Cohesion: 0.60
Nodes (3): GeneratedPluginRegistrant, FlutterEngine, Keep

### Community 25 - "Android Launcher Icons"
Cohesion: 1.00
Nodes (5): ic_launcher.png (hdpi) — Flutter default app icon, light-blue/navy diagonal parallelogram 'F' logo on white background, 72×72px density bucket, ic_launcher.png (mdpi) — Flutter default app icon, light-blue/navy diagonal parallelogram 'F' logo on white background, 48×48px density bucket, ic_launcher.png (xhdpi) — Flutter default app icon, light-blue/navy diagonal parallelogram 'F' logo on white background, 96×96px density bucket, ic_launcher.png (xxhdpi) — Flutter default app icon, light-blue/navy diagonal parallelogram 'F' logo on white background, 144×144px density bucket, ic_launcher.png (xxxhdpi) — Flutter default app icon, light-blue/navy diagonal parallelogram 'F' logo on white background, 192×192px density bucket

### Community 26 - "Log Service"
Cohesion: 0.40
Nodes (4): error, log, LogService, package:flutter/foundation.dart

### Community 27 - "Model Tests"
Cohesion: 0.50
Nodes (3): package:flutter_test/flutter_test.dart, package:rescu/model/deal_model.dart, main

### Community 33 - "iOS Launch Images"
Cohesion: 1.00
Nodes (3): LaunchImage.png — iOS launch screen 1x (blank/white default Flutter placeholder; no custom Rescu branding applied), LaunchImage@2x.png — iOS launch screen 2x Retina variant (blank/white default Flutter placeholder; no custom Rescu branding applied), LaunchImage@3x.png — iOS launch screen 3x Super Retina variant (blank/white default Flutter placeholder; no custom Rescu branding applied)

### Community 34 - "Project README"
Cohesion: 0.67
Nodes (3): FVM Flutter 3.27.0 Pinned Version, Rescu App, Surplus Food Marketplace

## Knowledge Gaps
- **262 isolated node(s):** `flutter_export_environment.sh script`, `+registerWithRegistry`, `XCTest`, `AppConfig`, `appName` (+257 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `DealModel` connect `Cart Item Model` to `Deal Data Model`, `Home Feed & Pagination`, `Analytics & Route Middleware`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `PickupWindowModel` connect `Pickup Window Model` to `Deal Data Model`, `Store Data Model`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `App Icon 1024x1024@1x — Flutter default logo; two sky-blue geometric chevrons (light #4FC3F7) on white with navy-blue (#0D47A1) accent at lower-right; geometric/flat-design style; canonical App Store resolution` (e.g. with `App Icon 20x20@1x — size variant of Flutter default logo chevron icon` and `App Icon 20x20@2x — size variant of Flutter default logo chevron icon`) actually correct?**
  _`App Icon 1024x1024@1x — Flutter default logo; two sky-blue geometric chevrons (light #4FC3F7) on white with navy-blue (#0D47A1) accent at lower-right; geometric/flat-design style; canonical App Store resolution` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_export_environment.sh script`, `+registerWithRegistry` to the rest of the system?**
  _263 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Cart & Checkout Flow` be split into smaller, more focused modules?**
  _Cohesion score 0.05365853658536585 - nodes in this community are weakly interconnected._
- **Should `GetX Controller Base` be split into smaller, more focused modules?**
  _Cohesion score 0.06282051282051282 - nodes in this community are weakly interconnected._
- **Should `Repository & Data Layer` be split into smaller, more focused modules?**
  _Cohesion score 0.06306306306306306 - nodes in this community are weakly interconnected._