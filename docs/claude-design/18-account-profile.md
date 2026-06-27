# Account & profile

The one place a signed-in person inspects and edits who they are to Cue — name, photo, time zone, the Apple identity behind the login — then signs out or deletes the account. A calm, low-traffic settings drill-down, not a dashboard.

> Status in code: **new** — broken out of `cue/Features/Settings/SettingsView.swift`, which today renders only a read-only `UserProfileRow` (avatar + name + email) at the top of the Settings `Form` and a destructive **Sign Out** button (`authStore.signOut()` + `telegramLink.clear()`). This prompt designs the dedicated drill-down: same `UserDTO` fields, the real sign-out behavior, plus the **edit** affordances (display name + time zone) and **delete-account** placeholder the founder wants in v1.
> **Backend honesty:** `UserDTO { id, appleUserId, email?, displayName?, avatarBase64?, timezone, createdAt, updatedAt }` is read today via `GET /auth/me`. A user-mutation endpoint (`PATCH /users/me`) does **not exist in the iOS client yet** — design the edit UI fully, but treat Save as forward-looking (optimistic local + queued). Delete-account is a **placeholder** (confirmation + "contact-to-delete" stub), not a wired `DELETE`. Flag both inline so the founder doesn't ship a dead button silently.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY — no invented palette, fonts, gradients, or pure white/black surfaces. Reference everything by name.

**Color (opaque sRGB; semantic roles, never raw hex in app):**
- `--background #FFFFFF` — app canvas behind everything (the scrolling `Form`/list background).
- `--surface #FAF6EF` — cards / grouped rows (faint warm paper).
- `--surface-elevated #FEFCF8` — the **photo-source action sheet / time-zone picker sheet** fill (top modals).
- `--surface-sunken #F1EADF` — recessed section-header strips, the avatar placeholder fill, zebra.
- `--primary #5A3A24` (espresso) — structural tint, the **avatar ring**, the Apple-identity glyph, field focus ring, key icons.
- `--primary-pressed #43291A` — pressed primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**; the one rationed wax-seal "make it stick" moment. Here: the **Save changes** decisive CTA fill + its wax seal, shown **only when the form is dirty**. Used at most ONCE.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe); used for the **"Change photo"** ghost link and the inline "edited" dot.
- `--on-accent #FBF5EA` (cream) — ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings (name, field values).
- `--text-secondary #6E5C4C` — supporting / muted text (email, captions, field labels).
- `--separator #D0BA98` — **decorative hairlines ONLY** (~1.88:1) — the faint rules between grouped rows.
- `--border #8C7142` — **functional edges** (the editable name field outline, card outlines, the avatar edit-badge).
- `--success #466234` (olive) — the "Saved" confirmation tick + banner rail.
- `--warning #C9A24B` (brass) — pending / draft notices. **Place INK on it, never cream.**
- `--danger #A8331F` (brick) — **Sign Out** and **Delete account** destructive labels/fills.

**More-accent discipline (hard rule):** terracotta `--secondary` is the one-hot moment — here, **Save changes + its wax seal**, once, and only while dirty. Olive = saved, brass = pending, espresso = structure (avatar ring, Apple glyph), brick = destructive. Color presence, not a rainbow.

**Typography (3 bundled families — substitute via Google Fonts in web preview):**
- Display/headings: **Fraunces** (≥17pt only — NEVER dense labels).
- Body/labels: **Public Sans** (explicitly NOT Inter / SF Pro).
- Code/receipts: **JetBrains Mono** (the time-zone identifier, the "member since" date, the user-id stamp — receipt voice).
- Ramp used here: `displayM` Fraunces 27 semibold (-0.4) = the user's **name** under the avatar (the screen hero) · `titleM` Fraunces 18 medium (-0.2) = section leads if any are titled in serif · `body` Public Sans 16 regular = field values · `bodyEmphasis` Public Sans 16 semibold = **button labels** · `callout` Public Sans 15 = the email line, footnotes · `label` Public Sans 13 medium (+0.3) = field labels / section eyebrows ("DISPLAY NAME", "TIME ZONE", "SIGN-IN METHOD") · `code` JetBrains Mono 13 (+0.2) = the **time-zone identifier** `Europe/Berlin`, the **member-since** date, the masked user-id. Display reads tighter (negative tracking); receipts read wider (positive).

**Spacing (4pt grid):** `xs 4 · sm 8 · md 12 · lg 16` (default gap / card inner) `· xl 20` (between fields) `· xxl 24` (between sections) `· xxxl 32` (avatar hero block top breathing) `· huge 48` (bottom breathing above the destructive zone). 16pt side margins.

**Radii (crisp cut-paper, never 16–20 squircle bubbles):** `chip 4` (rubber-stamp chips) · `small 6` (**default** — buttons, the editable name field, the avatar edit-badge) · `medium 8` · `card 10` (grouped row cards) · `large 12` (the picker sheet). The **avatar is the only true circle** on the screen — everything else is cut paper.

**Depth ("letterpress, not float"):** grouped row cards = `.letterpress` (1pt `--border` stroke + hard value-cut shadow `--text-primary` 6%, **blur radius 0**, y:1). NO soft uniform drop shadows anywhere. System **Liquid Glass** is chrome-only — the nav bar and the photo-source action sheet; re-tint it **warm** toward kraft/clay, never Apple's cool blue-grey.

**Components (by name):**
- **CueAvatar** — `CueAvatar(image:?, size: 56)` but rendered LARGE here (~96pt hero). Circular, `.scaledToFill` clipped; placeholder = `--surface-sunken` fill + `person.fill` glyph (`--text-secondary`, ~0.42× size). **Always ringed by a 1.5pt `--primary` (espresso) stroke circle.** On this screen it carries an **edit badge** (a small `--surface` circle, 1pt `--border`, `camera.fill` in `--primary`) bottom-trailing.
- **CueButton** — full-width, radius 6, padding v12/h16, label `bodyEmphasis`, press = 1pt downward letterpress offset (no scale/glow/shadow), `.easeOut(0.16)`. Variants used: `.decisive` (clay fill + cream — the ONE **Save changes** CTA, only while dirty), `.secondary` (clear + 1pt border + espresso label — **Manage Apple ID** / **Cancel**), `.destructive` (brick fill + cream — **Sign Out**), `.ghost` (clear + `--accent-text` clay label — **Change photo** and **Delete account**).
- **CueCard** — fill `--surface`, radius 10, `.letterpress`; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule. Wraps the grouped field rows.
- **CueChip** — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Unselected = `--surface` + `--text-secondary` + 1pt border; selected = `--primary` espresso fill + cream (deliberately NOT clay). Used only if a quick "common time zones" shortcut row is shown.
- **WaxSeal** — irregular hand-pressed blob (16 vertices, fixed jitter, NOT a clean circle). Unstamped = dashed "seal-well" (1.5pt `--border`, dash 4/4, @0.9). Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream `checkmark`. The signature mark of the **Save changes** commit — the only seal on the screen.
- **NotificationBanner** — INTENTIONALLY Liquid Glass, radius 8, 4pt severity rail. Used for the transient **"Profile saved" (success/olive)** and any **save-failed (error/brick)** toast — chrome, not a content card.

---

## Frame & platform

Single fixed iPhone **393 × 852 pt @3x**, **NOT responsive** — a native iOS 26 screen, not a web page.

- **Presentation:** a **stack-push** destination inside the **Settings** tab's `NavigationStack` (Settings → Account). Standard back-swipe from the left edge returns to Settings. The root content is a `Form`-style scroll on `--background`.
- **Status bar / Dynamic Island:** real iOS status bar (time + battery) at top; Dynamic Island reserved — no content under it. Top safe area ~59pt.
- **Nav chrome:** **inline** nav bar (NOT a large title — this is a drill-down), title **"Account"** in Fraunces ~17pt. Leading = system **back chevron + "Settings"** (`--accent-text` tint is fine for the chevron). The nav bar is warm-tinted Liquid Glass. **≤1 trailing action**: while the form is dirty, a trailing **"Save"** text button appears in `--accent-text` (mirror of the pinned CTA, for one-handed top reach); when clean, no trailing action.
- **Safe areas:** 16pt side margins; respect the **34pt home-indicator gutter** — the **Save changes** CTA, when present, floats just above it. The destructive **Sign Out / Delete** zone scrolls at the very bottom (below the fold), deliberately out of the resting thumb arc.
- **Sheets it can spawn:** a **photo-source action sheet** (Camera / Photo Library / Use Apple ID photo / Remove) and a **time-zone picker** (`.large` sheet, searchable list) — both warm Liquid-Glass chrome, fill `--surface-elevated`.
- **One-handed reach:** the most-used action (**Save**, when dirty) is the lowest, warmest target; the most-dangerous (**Delete account**) is the highest-friction — last on the page, ghost-styled, double-gated by a typed confirmation.

---

## Layout

Top → bottom (a single vertical `ScrollView` / `Form`; the **Save changes** CTA pins to the bottom safe-area inset only when the form is dirty).

Real content: signed-in user **"Jane Appleseed"**, email `jane.appleseed@icloud.com`, time zone `Europe/Berlin`, signed in **with Apple** since **Mar 2026**, no custom avatar yet (placeholder → suggests adding one).

```
┌─────────────────────────────────────────────┐
│  9:41                              ●●● ▮▮▮ 🔋 │  ← status bar · Dynamic Island reserved
│ ‹ Settings        Account              Save   │  ← inline nav · trailing "Save" only when dirty
├─────────────────────────────────────────────┤
│                                               │
│                  ╭───────╮                    │
│                  │  (JA) │◞ ⌖                  │  ← CueAvatar 96pt, espresso ring + camera badge
│                  ╰───────╯                    │
│              Jane Appleseed                   │  ← displayM Fraunces (the hero)
│           jane.appleseed@icloud.com           │  ← callout, --text-secondary
│              ‹ Change photo ›                  │  ← .ghost, --accent-text clay text
│                                               │
│  PROFILE                                      │  ← label eyebrow (--text-secondary)
│ ┌───────────────────────────────────────────┐ │  ← CueCard, grouped rows
│ │ Display name                              │ │  ← label (--text-secondary)
│ │ ┌───────────────────────────────────────┐ │ │
│ │ │ Jane Appleseed                      ⌫ │ │ │  ← editable field, 1pt --border, radius 6
│ │ └───────────────────────────────────────┘ │ │
│ │ ───────────────────────────────────────── │ │  ← --separator hairline
│ │ Time zone                            ›    │ │  ← tappable disclosure row → picker sheet
│ │ Europe/Berlin · GMT+2                     │ │  ← code (mono) identifier + offset
│ └───────────────────────────────────────────┘ │
│                                               │
│  SIGN-IN METHOD                               │  ← label eyebrow
│ ┌───────────────────────────────────────────┐ │
│ │  Apple   Signed in with Apple             │ │  ←  glyph (espresso) + body
│ │          jane.appleseed@icloud.com        │ │  ← the Apple relay/email, callout muted
│ │          Member since · Mar 2026          │ │  ← code (mono) date
│ │  [  Manage Apple ID  ]  (.secondary)      │ │  ← opens Settings app / account URL
│ └───────────────────────────────────────────┘ │
│                                               │
│····(scroll — below the resting thumb arc)·····│
│                                               │
│  [  Sign Out  ]            (.destructive)     │  ← brick fill + cream, clears auth + telegram
│                                               │
│            ‹ Delete account ›                 │  ← .ghost, --accent-text → double-gated dialog
│                                               │
│  User ID  usr_a1b2…f93   (tap to copy)        │  ← code (mono), muted — support footer
│                                               │
└─────────────────────────────────────────────┘
   ┌─────────────────────────────────────────┐    ← pinned ONLY while dirty, bottom thumb zone
   │  ⬗  Save changes                         │    ← CueButton .decisive (clay) + WaxSeal well
   └─────────────────────────────────────────┘
              ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯
```

**Region by region:**
1. **Avatar hero block** — centered **CueAvatar at ~96pt**, espresso `--primary` 1.5pt ring, with a small bottom-trailing **edit badge** (`--surface` circle, 1pt `--border`, `camera.fill` in `--primary`). Below it the **name** in `displayM` Fraunces (the screen hero) and the **email** in `callout`/`--text-secondary`. A **"Change photo"** `.ghost` link (`--accent-text`) sits under the email; tapping the avatar OR the link opens the photo-source action sheet. When no `avatarBase64`, the CueAvatar placeholder (`person.fill` on `--surface-sunken`) shows and the link reads **"Add photo"**.
2. **PROFILE card** — a `CueCard` of two grouped rows:
   - **Display name** — `label` caption + an **inline editable text field** (1pt `--border`, radius `small 6`, `--surface` fill, clear button on the right). Bound to `User.displayName`; empty → placeholder "Your name". Editing it dirties the form.
   - **Time zone** — a tappable **disclosure row** (`›`): label "Time zone", value the **identifier in JetBrains Mono** `Europe/Berlin` + a resolved offset `· GMT+2` in `--text-secondary`. Tapping opens the time-zone picker sheet. Bound to `User.timezone`.
3. **SIGN-IN METHOD card** — a `CueCard`: the ** Apple** glyph in `--primary`, "Signed in with Apple", the relay/email beneath (`callout`), and a **"Member since · Mar 2026"** line in `code` (from `User.createdAt`). A **"Manage Apple ID"** `.secondary` button (clear + 1pt border + espresso label) deep-links out to the system account page. This is **read-only** identity — Apple is the sole auth path; there is no "add another method."
4. **Destructive zone (scrolled bottom)** — **Sign Out** as `CueButton .destructive` (brick + cream); tapping clears the keychain JWT **and** the Telegram link (`authStore.signOut()` + `telegramLink.clear()`), returning to the Auth screen. Below it, **Delete account** as a low-emphasis `.ghost` clay-text link — deliberately small, double-gated (see states); a placeholder today.
5. **Support footer** — the masked **User ID** `usr_a1b2…f93` in `code`/`--text-secondary`, **tap-to-copy** (for support tickets). Quietest element on the page.

**The ONE wax-seal / clay moment:** the **Save changes** decisive button + its WaxSeal, appearing **only when the form is dirty** (name or time zone changed). When the form is pristine, there is **no clay anywhere** on the screen — the espresso avatar ring, the brick destructive zone, and the muted receipts carry it. Save is the single "make it stick" commit.

---

## Data & states

Bound to the real backend shapes (`UserDTO` via `GET /auth/me`, held in `AuthStore.state == .authenticated(user)`):

- **Avatar** → `User.avatarBase64` (base64, **no** data-URL prefix). Decode via `Data(base64Encoded:)` → `UIImage`; nil/empty → CueAvatar placeholder. Editing produces a new base64 string (same shape as first-sign-in `MeContactPhotoLoader.load()`).
- **Name** → `User.displayName` (optional; trim whitespace). Empty/nil → hero falls back to "Signed in" and the field shows a placeholder.
- **Email** → `User.email` (optional; the Apple relay address). Read-only — shown in hero + sign-in card.
- **Time zone** → `User.timezone` (IANA identifier, e.g. `"Europe/Berlin"`). Render the identifier in mono + a resolved `GMT±N` offset computed from `TimeZone(identifier:)`.
- **Member since** → `User.createdAt` (a `Date`) → "Member since · Mar 2026" in mono. **Updated** (`User.updatedAt`) is not surfaced.
- **Identity** → always "Apple" (`User.appleUserId` exists for every account; there is no other provider). The user-id footer masks `User.id` (`usr_…` is illustrative; surface a copyable truncation of the real id).

**Actions → endpoints (exact / honest):**
- **Save changes (name + time zone)** → **forward-looking**: no `PATCH /users/me` exists in the iOS client today. Design as **optimistic local update + queued sync**; the prompt must render the Save CTA and its dirty/clean logic, but note that wiring the endpoint is a follow-up. Until then Save updates the in-memory `AuthStore` user only.
- **Change / remove photo** → same forward-looking path (avatar travels in the same user payload).
- **Manage Apple ID** → opens the system account URL (`App-Prefs:` / `https://account.apple.com`) via `openURL` — leaves the app; no Cue endpoint.
- **Sign Out** → wired today: `authStore.signOut()` (clears keychain `accessToken` + `AuthTokenBridge`) **and** `telegramLink.clear()`. Returns to `AuthView`.
- **Delete account** → **placeholder**: no `DELETE` endpoint. The confirmation dialog explains deletion is permanent and (for now) routes to a "contact support to delete" stub or a disabled confirm. Do **not** render a one-tap working destroy.

**States:**
- **Default (clean):** all fields populated, **no Save CTA**, no clay on screen.
- **Dirty (edited):** the **Save changes** `.decisive` CTA appears pinned at the bottom (and a trailing nav "Save" appears); a tiny `--accent-text` "edited" dot marks each changed field's label. **Cancel** (a `.secondary` next to the field group, or discard-on-back) reverts.
- **Saving:** the Save button shows an inline `ProgressView` (cream on clay); the WaxSeal stamps on success (see motion). The trailing nav action disables.
- **Saved:** WaxSeal stamped → a transient **NotificationBanner** (`.success`, olive rail) "Profile saved" auto-dismisses (4s); CTA collapses; form returns to clean.
- **Save failed:** revert the optimistic change + a **NotificationBanner** (`.error`, brick rail) "Couldn't save — try again." The CTA stays (still dirty).
- **No avatar:** placeholder + the link reads "Add photo".
- **No display name:** hero shows "Signed in"; the field shows a "Your name" placeholder; not an error.
- **Loading (cold open / re-fetch):** if `AuthStore.state == .loading`, the hero shows a CueAvatar placeholder + a shimmer-free, calm `LoadingStateView`-style centered spinner (`--primary` tint) in place of the cards — **no skeleton bento**. Normally the user is already in memory so this is rare.
- **Offline:** edits are allowed and **queued**; the Save banner reads "Saved offline — will sync when connected" (brass-tinted info), the destructive zone (Sign Out) still works locally, **Manage Apple ID** is disabled (needs network) with a muted caption.
- **Sign Out confirm:** a `.confirmationDialog` — "Sign out of Cue? This also disconnects Telegram." → destructive **Sign Out** + Cancel.
- **Delete confirm (double-gated):** a `.confirmationDialog` or `.alert` requiring the user to **type "DELETE"** (or tap a clearly secondary destructive button) — and, since it's a placeholder, the confirm explains it routes to support rather than instantly destroying. Never a single-tap path.
- **Long values:** a long display name wraps the hero to ≤2 lines in `displayM`, never truncating mid-name; a long time-zone identifier (`America/Argentina/Buenos_Aires`) truncates the **tail** with the offset still visible.

---

## Interactions & motion

- **Push / pop:** standard `NavigationStack` push from Settings; left-edge back-swipe pops. If the form is **dirty**, popping triggers a **discard-changes** `.confirmationDialog` ("Discard your changes?") before leaving. Reduce Motion → the push becomes a **cross-fade**, no slide parallax.
- **Edit name:** tapping the field focuses it, keyboard rises; a keyboard toolbar carries **Done**. First keystroke that diverges from the stored value dirties the form (the Save CTA slides up `.snappy` from the bottom inset). Reduce Motion → CTA appears instantly (opacity only).
- **Save changes (the signature):** tap → optimistic write. The **WaxSeal stamps**: `.spring(response: 0.42, dampingFraction: 0.62)`, scale 0.4→1, opacity 0→1, rotation −8°→0° (~450ms settle), then the success banner slides in. **Reduce Motion fallback:** no spring/rotation — the seal **cross-fades** from seal-well to stamped (opacity only); the CTA collapses without a slide. `.sensoryFeedback(.success)` fires either way.
- **Button press:** all CueButtons depress 1pt downward (`.easeOut(0.16)`) — no scale, glow, or shadow. The `.decisive` Save adds the `--primary-pressed` multiply overlay @0.22 ("ink soaking in").
- **Change photo:** tapping the avatar or the link presents the warm-glass action sheet (`.snappy` rise); choosing a source opens the system picker; on return the avatar cross-fades to the new image (`.easeOut(0.16)`) and the form dirties.
- **Time-zone picker:** tapping the disclosure row pushes/presents a searchable `.large` sheet; selecting a zone dismisses with `.snappy` and writes the value (dirties the form). `.sensoryFeedback(.selection)` on selection.
- **Sign Out:** confirm dialog → on confirm, a brief spinner on the brick button → the whole tab stack cross-fades to `AuthView`. `.sensoryFeedback(.impact)` on confirm. Reduce Motion unaffected (no decorative motion).
- **Delete account:** double-gated dialog (typed "DELETE"); confirm is `.destructive`. Heaviest-friction path on the screen by design.
- **User-ID copy:** tap → copies to pasteboard, a tiny inline "Copied" `caption` flashes for ~1.2s (`.opacity`, no movement); `.sensoryFeedback(.success)`.

The **160ms ease-out** (every press), the **`.snappy`** chrome reveals, and the **single seal spring** are the recurring signatures — do not invent new curves.

---

## iOS specifics

- **Dynamic Type:** every role is a relative text style — the `displayM` name, field labels, and mono receipts all scale. At AX sizes: the sign-in card's "Manage Apple ID" button stays full-width; the time-zone row stacks identifier above offset rather than clipping; the hero name wraps. Never fix point sizes; never clip a name.
- **Haptics (`.sensoryFeedback`):** `.success` on Save / copy · `.selection` on time-zone pick · `.impact` on Sign Out / Delete confirm. Respect the system haptic setting.
- **Context menu:** long-press the **avatar** offers Change photo / Remove photo; long-press the **User ID** offers Copy. Mirror visible actions, never hide-only.
- **Swipe actions:** N/A — this is a settings detail, not a list of deletable rows.
- **Keyboard:** the name field uses `.textContentType(.name)`, `.submitLabel(.done)`, autocapitalization words; a toolbar **Done** dismisses. The form scrolls to keep the focused field above the keyboard.
- **VoiceOver labels:**
  - Avatar element: "Profile photo, Jane Appleseed. Double-tap to change." (placeholder variant: "No profile photo. Double-tap to add.")
  - Name field: label "Display name", value "Jane Appleseed", editable.
  - Time-zone row: "Time zone, Europe Berlin, GMT plus 2. Double-tap to change."
  - Sign-in card: "Signed in with Apple, jane.appleseed@icloud.com, member since March 2026." Read as one grouped element; "Manage Apple ID, button, opens Settings."
  - Save: "Save changes, button" — announced only when present; the WaxSeal is `.accessibilityHidden(true)` (decorative; the button carries the label and the "Saved" state is announced via the banner).
  - Sign Out: "Sign out, button. Also disconnects Telegram." Delete account: "Delete account, button" with the dialog spelling out permanence.
  - User ID: "User ID, usr a1b2 f93, double-tap to copy."
  - Never color-only meaning: the dirty state is the visible Save button + an "edited" text/dot, not hue alone; destructive intent is the word "Sign out" / "Delete", not just brick.

---

## ✦ Claude Design prompt (paste this)

```
Design a single native iOS 26 screen: "Account & profile" for CUE, an AI-assisted calendar +
Telegram-assistant app. Use the published "Kraft & Ink" design system and its tokens ONLY — no new
colors, fonts, gradients, or pure white/black surfaces.

FRAME: Fixed iPhone 393×852pt @3x, NOT responsive — a native iOS screen, not a web page. Real iOS
status bar (time + battery), Dynamic Island reserved — no content under it. This is a STACK-PUSH
drill-down inside Settings: an INLINE nav bar (warm Liquid Glass), title "Account" in Fraunces ~17pt,
a back chevron reading "Settings" on the left. The body is a vertical scrolling grouped form on
--background (#FFFFFF). Top safe area ~59pt; 16pt side margins; respect the 34pt home-indicator
gutter; all tap targets ≥44pt.

PURPOSE: View and edit who the signed-in person is to Cue — name, photo, time zone, the Apple
identity — then sign out or delete the account. A calm, low-traffic settings screen, not a dashboard.

LAYOUT (top → bottom):
  1. AVATAR HERO (centered): a ~96pt circular CueAvatar with a 1.5pt espresso (--primary) ring and a
     small bottom-trailing edit badge (a --surface circle, 1pt --border, camera.fill glyph in
     --primary). Below it the user's name "Jane Appleseed" in Fraunces displayM (27, semibold) — the
     screen hero — then the email "jane.appleseed@icloud.com" in Public Sans callout (--text-secondary),
     then a ghost text link "Change photo" in --accent-text clay.
  2. "PROFILE" section eyebrow (label, --text-secondary) over a CueCard with two grouped rows:
     • "Display name" label + an inline EDITABLE text field (--surface fill, 1pt --border, radius 6,
       trailing clear button) prefilled "Jane Appleseed".
     • a --separator hairline, then a "Time zone" disclosure row (chevron ›): value in JetBrains Mono
       "Europe/Berlin" + a "· GMT+2" offset in --text-secondary. Tapping opens a time-zone picker.
  3. "SIGN-IN METHOD" eyebrow over a CueCard: an Apple logo glyph in --primary + "Signed in with
     Apple", the relay email beneath (callout, muted), and "Member since · Mar 2026" in JetBrains Mono.
     A CueButton .secondary "Manage Apple ID" (clear + 1pt --border + espresso label) that deep-links
     out to the system account page. This identity block is READ-ONLY.
  4. Scrolled to the BOTTOM, below the resting thumb arc: a CueButton .destructive "Sign Out"
     (--danger brick fill + cream label), then a low-emphasis ghost text link "Delete account" in
     --accent-text. Below that, a quiet "User ID  usr_a1b2…f93" footer in JetBrains Mono
     (--text-secondary), tap-to-copy.
  5. PINNED in the bottom thumb zone above the home gutter, VISIBLE ONLY WHEN THE FORM IS DIRTY:
     a CueButton .decisive "Save changes" (--secondary clay fill + cream label) with a small WaxSeal
     seal-well glyph at its leading edge. When the form is clean this CTA is ABSENT and there is NO
     clay anywhere on the screen.

COMPONENTS (by name): CueAvatar (circle, espresso ring, --surface-sunken + person.fill placeholder),
CueCard (--surface, radius 10, letterpress depth = 1pt --border + hard value-cut shadow at
--text-primary 6%, BLUR RADIUS 0, y:1; optional --surface-sunken header strip with a 1pt --separator
bottom rule), CueButton (.decisive/.secondary/.destructive/.ghost; full-width, radius 6, label Public
Sans 16 semibold, press = 1pt downward letterpress offset), WaxSeal (irregular hand-pressed clay blob,
NOT a clean circle; a dashed seal-well that stamps to clay + cream check on Save), NotificationBanner
(warm Liquid Glass, 4pt olive rail) for the transient "Profile saved" toast.

REAL CONTENT (verbatim, no lorem, no "User 1"): name "Jane Appleseed", email
"jane.appleseed@icloud.com", time zone "Europe/Berlin · GMT+2", "Signed in with Apple",
"Member since · Mar 2026", footer "User ID  usr_a1b2…f93".

STATES to render alongside the default (clean): (a) DIRTY — the clay "Save changes" CTA pinned at the
bottom + a trailing nav "Save" text action + a tiny --accent-text "edited" dot on the changed field's
label; (b) NO-AVATAR — the CueAvatar placeholder (person.fill on --surface-sunken) with the link
reading "Add photo"; (c) SAVED — WaxSeal stamped + an olive NotificationBanner "Profile saved", CTA
gone; (d) SIGN-OUT CONFIRM — a confirmationDialog "Sign out of Cue? This also disconnects Telegram."
with a destructive "Sign Out" + Cancel.

MOTION: Save stamps the WaxSeal with spring(response 0.42, damping 0.62) — scale 0.4→1, rotation
−8°→0° (~450ms) — then the olive banner slides in. Reduce-Motion fallback: the seal cross-fades
opacity-only, the CTA collapses without sliding, no rotation. The dirty CTA slides up .snappy when the
form first changes; the nav push is a standard slide (Reduce-Motion → cross-fade). Buttons depress 1pt
on press (160ms ease-out); the .decisive Save adds a --primary-pressed multiply overlay @0.22. Haptics:
.success on Save and User-ID copy, .selection on time-zone pick, .impact on Sign Out / Delete confirm.

iOS PATTERNS: inline nav title + back chevron; grouped form rows in CueCards; a photo-source action
sheet (Camera / Photo Library / Use Apple ID photo / Remove) and a searchable time-zone picker sheet,
both warm Liquid Glass; .confirmationDialog on Sign Out and a DOUBLE-GATED (type "DELETE") dialog on
Delete account; discard-changes prompt on back-swipe while dirty; tap-to-copy User ID; keyboard
toolbar Done on the name field. Dynamic Type: relative styles, the sign-in button full-width at AX
sizes, the time-zone row stacks identifier-above-offset, the name wraps — nothing clips. VoiceOver:
every row speaks label + value + action and never relies on color alone (dirty = the visible Save
button + "edited", destructive = the words "Sign out"/"Delete").

ANTI-AI-SLOP GUARDRAILS (hard): NO Inter / Helvetica / SF Pro — pin Fraunces (the name + titles
≥17pt), Public Sans (body/labels), JetBrains Mono (the time-zone identifier, the member-since date,
the User ID). NO purple, NO blue accents, NO gradients, NO glassmorphism on the content cards (glass
is chrome-only — the nav bar and action/picker sheets — and re-tinted WARM, never Apple cool blue).
NO soft uniform drop shadows — letterpress only (1px border + hard value-cut, blur 0). NO pure
#FFFFFF surface-on-white, NO pure #000000. NO generic evenly-spaced bento grid — this is a calm
one-column settings page that breathes: an avatar hero, two grouped cards, a quiet destructive zone.
Crisp 4–12px cut-paper corners, never 16–20px squircle bubbles; the ONLY true circle is the avatar.
Selected chips fill espresso --primary, NOT clay. The terracotta wax seal + clay fill appear EXACTLY
ONCE — on "Save changes", and only while the form is dirty; when clean there is NO clay on the screen.
The avatar ring and structure are espresso, destructive is brick, saved is olive. Color presence, not
a rainbow. Do not say "modern / clean / sleek / beautiful". Honor Kraft & Ink exactly; native iOS,
not a web page.
```
