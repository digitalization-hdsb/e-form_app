# HDSB e-Form (Flutter)

Flutter/Android/iOS client for the same HDSB e-Form system as the web app in
the parent `e-form/` folder. It talks to the **same Supabase project** — same
`users`/`submissions`/`cars` tables, same Auth users, same Storage bucket —
so anything submitted here shows up on the website and vice versa.

## What's implemented

Full parity with the website's approval-flow surface — 40 routes / 67 Dart
files. Role-aware navigation drawer (mirrors `AppSidebar.tsx`) shows the
right sections for whoever is signed in.

- **Auth**: login, register, email OTP verification, forgot/reset password, change password
- **Home**: department cards (role-filtered), submission stats, announcement banner
- **HR**: Company Car Request, Gate Pass, PPE/Uniform/Office Supply request
- **Finance**: Petty Cash Claim, Upload Receipt
- **IT**: CCTV Access Request, Help Desk Ticket, IT Request (Admin), IT Request (Application, with the full 673-row ERP authorization rights picker)
- **Safety**: Mixing & Chemical, Final Discharge, Waste Inventory (all auto-approve, no HOS/HOD chain, per the website)
- **My Submissions**: list + detail view, realtime status updates
- **Profile**: view/edit contact details, change password, sign out
- **Approver Dashboard**: generic HOS/HOD/Manco/HOP/HOF approval queue covering car_rental, leave, and claim — same status state machine, same `approvalRemarksHistory` shape as the website
- **HR Admin**: Form Approvals (car rental final approval), Car Management (checkout/check-in with mileage/fuel/photos/petrol card), Inventory Tracker, Purchases
- **Finance Admin**: claim review → Head of Finance handoff → payment processing (GL code + amount paid)
- **IT Admin**: CCTV / Help Desk / Facilities request dashboards (one screen, three modes, matching `ITAdminDashboard.tsx`'s `mode` prop)
- **Safety Admin**: Discharge, Mixing, Waste dashboards (stat tiles + remarks logging) + read-only Waste Records browser
- **Security Guard**: gate pass exit/entry logging, overdue personal-pass alerts
- **Super Admin**: User Directory (role/department/secondary-role management, activate/deactivate), All Submissions (search/filter + permanent delete), Analytics (stat tiles), System Settings (departments, home poster, announcements)

### Known gaps (intentionally scoped out)

- **Charts**: Safety dashboards and Analytics show the same aggregate numbers as the website but skip the line/bar/pie charts (presentational only, no `fl_chart` dependency added yet).
- **Bilingual English/Malay toggle**: every form on the website renders bilingual labels via `FormLanguageContext`; the Flutter forms are English-only. Adding this touches every screen — treat as a separate pass if wanted.
- **Realtime in-app notification bell**: the website's `NotificationBell` + `useRealtimeNotifications` (toast + sound on submission status change) aren't ported. Submission lists still update live via Supabase realtime streams — you just don't get a bell/toast for it.
- **IT Admin Facilities / Application Options settings management**: the requisition forms read live from `it_admin_facilities` / `it_application_options`, but there's no in-app screen to add/edit those option lists (edit them via Supabase directly, or the website).
- **Inventory item prices**: the website keeps per-item prices in browser `localStorage` (not Supabase) for the PPE purchase cost estimate; the Flutter Inventory Tracker shows quantities only, no cost tracking.
- **Route guards**: screens aren't role-gated beyond what the drawer chooses to show (no address bar on mobile, so this is low-risk, but a deep link could theoretically reach a screen the user's role wouldn't normally navigate to).

## Setup

1. Get the Supabase project URL and anon key the website uses — they're in
   the website's `.env` file (`VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`),
   or the Supabase dashboard → Project Settings → API. **Use the same
   project** so both apps share data.
2. Run with those values injected at build/run time (never hard-code them
   into source):

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```

   For a repeatable setup, create `env.sh` (git-ignored) with those two
   `--dart-define` flags and source it, or use an IDE run configuration with
   the same `--dart-define` args.

   Without these, the app boots to a "Supabase credentials not set" screen
   instead of crashing.

## Architecture

- **State**: Riverpod (`StateNotifierProvider`) — `lib/providers/*` mirror
  the website's React contexts (`AuthContext`, `UsersContext`,
  `SubmissionsContext`) one-to-one, including the same daily-submission-limit
  guard and the same Postgres RPCs (`next_hdsb_ref_no`, `next_gate_pass_ref_no`)
  for reference numbers.
- **Routing**: `go_router`, auth-aware redirects in `lib/core/router.dart`.
- **Backend**: `supabase_flutter` — no custom API layer; screens call
  `supabase.from(...)` / `supabase.storage` / `supabase.rpc(...)` directly,
  same as the website's `src/supabase.ts` usage.
- **Theme**: `lib/core/theme.dart` — colors lifted directly from the
  website's `src/index.css` HSL tokens (navy primary `#1F2A5C`, gold accent
  `#F6B93B`) so the two clients read as the same product.

## Adding a new form

Each web form (`src/pages/*Form.tsx`) maps to one Flutter screen. Pattern to
follow, using `lib/screens/hr/gate_pass_form_screen.dart` as the simplest
reference:

1. Read the equivalent `src/pages/*.tsx` file on the website to get the exact
   field list, validation rules, and the `formType` string used in the
   `data` payload — the mobile submission must produce the same shape so the
   website's dashboards can render it.
2. Build the screen with `FormSectionCard` / `ApproverDropdown` /
   `PrefilledDetailsBox` from `lib/widgets/` for visual consistency.
3. Call `ref.read(submissionsProvider.notifier).addSubmission(...)` with the
   matching `formType` and `data` map.
4. Wire the route in `lib/core/router.dart` and link it from the relevant
   forms-list screen (`hr_forms_screen.dart` / `finance_forms_screen.dart`,
   or a new one for IT/Safety).

## Building

```bash
# Debug APK
flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Release APK / App Bundle (needs a signing config in android/app — see
# https://docs.flutter.dev/deployment/android)
flutter build appbundle --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# iOS (needs a Mac + Xcode signing setup — see https://docs.flutter.dev/deployment/ios)
flutter build ipa --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
