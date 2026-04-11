# Core Contracts First Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a flexible, test-driven core contracts module that defines the domain entities, value objects, gateway interfaces, and use case boundaries for the translation app.

**Architecture:** Start with a pure Dart core layer that has no Flutter, Android, network, or database dependencies. Keep the first module focused on immutable entities, small value objects, and abstract interfaces so the rest of the app can implement them later without changing the contract. Each task below is intentionally small and ends with a passing test before moving to the next module.

**Tech Stack:** Flutter SDK, `flutter_test`, Dart language features, no additional packages for this first module.

---

### Task 1: Create core domain model

**Files:**
- Create: `lib/core/domain/llm_config.dart`
- Create: `lib/core/domain/translation_request.dart`
- Create: `lib/core/domain/translation_record.dart`
- Create: `lib/core/domain/action_event.dart`
- Create: `test/core/domain/domain_models_test.dart`

- [ ] **Step 1: Write the failing test**

Cover the expected immutability and field presence for the core entities: config, request, record, and action event.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/domain_models_test.dart`
Expected: fail because the new domain files do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Implement simple immutable Dart classes with const constructors and the fields described in the design.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/domain_models_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain test/core/domain/domain_models_test.dart
git commit -m "feat: add core domain models"
```

### Task 2: Define core gateway interfaces

**Files:**
- Create: `lib/core/domain/gateways/clipboard_gateway.dart`
- Create: `lib/core/domain/gateways/llm_gateway.dart`
- Create: `lib/core/domain/gateways/overlay_gateway.dart`
- Create: `lib/core/domain/gateways/record_repository.dart`
- Create: `test/core/domain/gateways/gateway_contract_test.dart`

- [ ] **Step 1: Write the failing test**

Verify each gateway exposes the narrow methods needed by the first MVP flow.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/gateways/gateway_contract_test.dart`
Expected: fail because the interfaces do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add abstract interfaces only, with no concrete behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/gateways/gateway_contract_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/gateways test/core/domain/gateways/gateway_contract_test.dart
git commit -m "feat: define core gateway interfaces"
```

### Task 3: Define the translation use case contract

**Files:**
- Create: `lib/core/application/translate_clipboard_use_case.dart`
- Create: `lib/core/application/use_case_result.dart`
- Create: `test/core/application/translate_clipboard_use_case_test.dart`

- [ ] **Step 1: Write the failing test**

Verify the use case contract describes the first MVP flow and returns a typed result.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/application/translate_clipboard_use_case_test.dart`
Expected: fail because the use case files do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Define the use case interface, a small result type, and any failure type needed by the contract.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/application/translate_clipboard_use_case_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/application test/core/application/translate_clipboard_use_case_test.dart
git commit -m "feat: define translation use case contract"
```

### Task 4: Wire the app shell to the new core

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Replace the counter smoke test with a simple app shell test that verifies the app boots with a stable title and placeholder home page.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: fail until the app shell is updated.

- [ ] **Step 3: Write minimal implementation**

Swap the counter demo for a minimal translation app scaffold that can later host the modular screens.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: replace counter demo with app shell"
```

### Task 5: Verify the workspace stays green

**Files:**
- No new files

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 2: Fix any regressions**

Only address failures introduced by this plan.

- [ ] **Step 3: Stop before the next module**

After the core contracts module is green, pause and confirm the next module to implement.