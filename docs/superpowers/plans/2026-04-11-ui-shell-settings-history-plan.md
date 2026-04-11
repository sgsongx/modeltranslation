# UI Shell Settings and History Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tabbed app shell that exposes settings and history screens without breaking the existing platform bridge and floating bubble controls.

**Architecture:** Keep the current bridge/control page as the center of the shell, then add sibling settings and history views behind explicit tabs. The settings view should stay mostly declarative and display bridge/config status, while the history view should consume the existing translation history use case so the app shows real records as soon as storage is connected. The shell should remain injectable for tests so fake gateways and fake history use cases can drive the UI without Android.

**Tech Stack:** Flutter Material 3, `flutter_test`, existing `PlatformBridgeGateway`, existing `TranslationHistoryUseCase`.

---

### Task 1: Add shell tabs and section widgets

**Files:**
- Modify: `lib/main.dart`
- Create: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Verify the shell shows tabs for control, settings, and history and that switching tabs changes the displayed section.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: fail because the shell still renders a single control page.

- [ ] **Step 3: Write minimal implementation**

Add a tabbed scaffold with three sections: control, settings, and history.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: add shell tabs for settings and history"
```

### Task 2: Connect settings section to bridge status

**Files:**
- Modify: `lib/main.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Verify the settings section shows bridge capabilities and a connection status summary.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: fail until the settings summary is wired.

- [ ] **Step 3: Write minimal implementation**

Render the bridge capability summary in the settings section without introducing platform-specific logic.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: wire settings shell to bridge status"
```

### Task 3: Connect history section to use case

**Files:**
- Modify: `lib/main.dart`
- Create: `test/core/application/history_shell_test.dart` if needed

- [ ] **Step 1: Write the failing test**

Verify the history section loads a recent-record list and shows an empty-state message when no records exist.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/application/history_shell_test.dart`
Expected: fail because the shell-level history view is not implemented yet.

- [ ] **Step 3: Write minimal implementation**

Show recent records from the existing history use case and add a simple empty state.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/application/history_shell_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/core/application/history_shell_test.dart
git commit -m "feat: add history shell view"
```

### Task 4: Full regression verification

**Files:**
- No new files

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 2: Fix any regressions**

Only address failures introduced by the shell update.

- [ ] **Step 3: Stop before next module**

After this shell update is green, pause and confirm whether to continue with settings forms or history actions.
