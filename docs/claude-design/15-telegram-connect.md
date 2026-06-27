# Connect Telegram

Link (and unlink) the Telegram AI assistant — CUE's headline differentiated integration — by redeeming a one-time code, with a single wax-seal "make it stick" moment on a successful link.

> Status in code: **exists** (`cue/Features/Settings/Telegram/ConnectTelegramView.swift` + `ConnectTelegramViewModel.swift` + `TelegramLinkStore.swift`, with the deep-link entry in `cue/App/DeepLink.swift` / `RootView.swift`). This prompt designs the **intended** screen: the same five states, the same `isMutating` blocking overlay, the same endpoints and field names, but elevated from a plain grouped `Form` into the full Kraft & Ink treatment — a paper-receipt "linking code" field, a celebratory **WaxSeal** stamp on the connect, and a richly-rendered connected "ticket". Mirror the real state machine, copy, and behavior below; do not invent your own.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY — no invented palette, fonts, gradients, or pure white/black surfaces. Reference everything by name.

**Color (opaque sRGB; semantic roles, never raw hex in app):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards / rows (faint warm paper).
- `--surface-elevated #FEFCF8` — the **sheet** fill when entered via deep link (it's a top modal).
- `--surface-sunken #F1EADF` — recessed strips (section header bands, the code-field inset, grabber zone).
- `--primary #5A3A24` (espresso) — structural tint, icons, the **Paste** action, section spines; the **Connect CTA fill is clay (below)**, not this.
- `--primary-pressed #43291A` — pressed primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**; the one rationed moment, spent here **TWICE in one continuous beat**: the **Connect** decisive CTA fill **and** the **WaxSeal** that stamps when the link lands. Both are the *same* commit gesture, so it reads as a single rationed clay moment, not two.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe); used for the connected-state "✦ Assistant active" eyebrow and the retry link.
- `--on-accent #FBF5EA` (cream) — ink on a primary/secondary fill (Connect label, seal glyph).
- `--text-primary #2E211A` — body + headings, the typed code.
- `--text-secondary #6E5C4C` — supporting / muted text, the `@handle` + timestamp receipts.
- `--separator #D0BA98` — **decorative hairlines ONLY** (~1.88:1).
- `--border #8C7142` — **functional edges** (the code field outline, card outlines, seal-well).
- `--success #466234` (olive) — the connected/"active" status dot + check. Done = olive, never clay.
- `--warning #C9A24B` (brass) — the "bad code" inline notice. **Place INK on it, never cream.**
- `--danger #A8331F` (brick) — the **Disconnect** destructive action.
- `--info #5A3A24` (espresso) — structural notice rail.

**More-accent discipline (hard rule):** terracotta `--secondary` is the one-hot moment — here, the **Connect button + its WaxSeal stamp**, a single continuous commit beat. Olive = connected/active, brass = bad-code warning, brick = disconnect, espresso = structure, Telegram's own blue is **never** introduced (the bot's brand color does not enter this palette — the integration wears Kraft & Ink). Color presence, not a rainbow.

**Typography (3 bundled families — substitute via Google Fonts in web preview):**
- Display/headings: **Fraunces** (≥17pt only — NEVER dense labels). `titleL` 22 medium (-0.2) = screen lead ("Your assistant, on Telegram") · `titleM` 18 medium = the connected `@handle` headline.
- Body/labels: **Public Sans** (explicitly NOT Inter / SF Pro). `body` 16 = explanation copy · `bodyEmphasis` 16 semibold = **button labels** · `callout` 15 = supporting copy · `label` 13 medium (+0.3) = field labels / eyebrows / section headers.
- Code/receipts: **JetBrains Mono** (the receipt voice). `code` 13 (+0.2) = **the typed linking code** (`K7M2-9QXP`), the `@jane_appleseed` handle, the **linked-at timestamp** (`24 Jun 2026 at 09:41`) · `codeSmall` 11 medium (+0.8) = the masked-status micro-label.
- Display reads tighter (negative tracking); receipts read wider (positive). The code is **always** mono — it is a receipt, not prose.

**Spacing (4pt grid):** `xs 4 · sm 8 · md 12 · lg 16` (default gap / card inner) `· xl 20` (between fields) `· xxl 24` (between cards/sections) `· huge 48` (hero / empty breathing under the lead). 16pt side margins.

**Radii (crisp cut-paper, never 16–20 squircle bubbles):** `chip 4` (rubber-stamp chips, unused here) · `small 6` (**default** — the code field, the Connect/Disconnect buttons, the brass/notice tiles) · `medium 8` (icon tiles, the notification banner) · `card 10` (the explanation / connected cards) · `large 12` (the deep-link sheet itself).

**Depth ("letterpress, not float"):** cards = `.letterpress` (1pt `--border` stroke + hard value-cut shadow `--text-primary` 6%, **blur radius 0**, y:1). The code field = a `--surface-sunken` inset with a 1pt `--border` edge (a thing the user must *locate* and type into). NO soft uniform drop shadows anywhere. System **Liquid Glass** is chrome-only — the nav bar, the deep-link sheet's grabber zone, and the **blocking overlay** scrim's glass spinner; re-tint warm toward kraft/clay, never Apple's cool blue-grey.

**Components (by name):**
- **CueButton** — full-width, radius 6, padding v12/h16, label `bodyEmphasis`, press = 1pt downward letterpress offset (no scale/glow/shadow), `.easeOut(0.16)`, disabled → opacity 0.5. Variants used: `.decisive` (clay fill + cream — the ONE **Connect** CTA, with `--primary-pressed` multiply overlay @0.22 on press, "ink soaking in"), `.destructive` (brick + cream — **Disconnect**), `.secondary` (clear + 1pt border + espresso label — the **Paste from Clipboard** affordance can also read as a `.ghost`/`.secondary`; here use a quiet inline `.secondary` row), `.ghost` (clear + `--accent-text` label — the failed-state **Retry**).
- **CueCard** — fill `--surface`, radius 10, `.letterpress`; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule. Used for the explanation card and the connected "ticket".
- **CueChip** — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Not central here; the connected-status pill is **not** a CueChip (status uses an olive dot + label, not a selectable chip).
- **CueAvatar** — circular, 1.5pt `--primary` ring; placeholder = `--surface-sunken` + glyph. Used **small (size 40)** in the connected ticket as the assistant identity mark — a `paperplane.fill` in `--primary` inside the ring (NOT the Telegram logo; the integration wears Kraft & Ink). When the backend later threads a real avatar it slots straight in.
- **WaxSeal / WaxSealShape** — irregular hand-pressed blob (16 vertices, fixed jitter, NOT a clean circle). Unstamped = dashed "seal-well" (1.5pt `--border`, dash 4/4, @0.9). Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream glyph (`link` / `checkmark`). The **signature mark of the successful link** — the screen's one celebration.
- **LoadingStateView** / **`.loadingOverlay`** — the cold-read spinner (`ProgressView`, `--primary` tint, `callout` label) and the **blocking mutation overlay**: warm-ink scrim `--text-primary` @0.08 (NOT black) + a glass-backed spinner, label **"Working…"**, `.snappy`.
- **ErrorStateView** — full-state fetch failure on `ContentUnavailableView` (`wifi.exclamationmark`) + a retry. (Known DS gap: its retry is a system `.borderedProminent`, not a CueButton — in this prompt spec the on-brand `.ghost` Retry instead.)
- **NotificationBanner** — INTENTIONALLY Liquid Glass, radius 8, 4pt severity rail. Success rail = olive (`--success`), error rail = brick (`--danger`). Carries the `telegram.connected.*` and `telegram.error.*` outcomes.

---

## Frame & platform

Single fixed iPhone **393 × 852 pt @3x**, **NOT responsive** — a native iOS 26 screen, not a web page.

This screen has **two entries**, same content, different chrome — render the **pushed (Settings)** variant as the primary, and note the sheet variant:

- **Entry A — pushed from Settings** (`NavigationLink` in `SettingsView`, the Integrations section). Full screen on `--background`. **Inline nav bar** (Liquid Glass, warm-tinted), title **"Telegram"** (`telegram.title`, inline display mode), a leading back chevron. Status bar (time + battery) + Dynamic Island reserved at top (top safe area ~59pt); 34pt home-indicator gutter at bottom; 16pt side margins. No tab bar (this is a pushed detail inside the Settings stack).
- **Entry B — deep-link sheet** (`cue://telegram/link?code=…` or the universal link `https://<host>/app/telegram/link?code=…`, both routed through `DeepLink` → `RootView.onOpenURL` → a `.sheet` wrapping `ConnectTelegramView(prefilledCode:)` in its own `NavigationStack`). Render as a **sheet** over the current tab: fill `--surface-elevated`, corner `large 12`, a warm Liquid-Glass grabber zone (`--surface-sunken`) at top, the same inline "Telegram" title bar beneath the grabber. The code arrives **pre-filled** in the field but is **NEVER auto-submitted** — the user always taps Connect. On a successful link the sheet **dismisses itself**.
- **Safe areas / reach:** the primary **Connect** CTA sits low, in the **bottom thumb zone** above the 34pt gutter (in the pushed variant it's the last form section; in the sheet it sits just above the grabber gutter). Destructive **Disconnect** in the connected state is deliberately the lowest, highest-friction target.
- **All tap targets ≥44pt;** the code field is a full-width ≥44pt tap target; "Paste from Clipboard" is its own ≥44pt row.

---

## Layout

Top → bottom. The screen renders exactly ONE of five states off `TelegramLinkStore.status` (with the `isMutating` blocking overlay layered above any state). Realistic content throughout: handle `@jane_appleseed`, code `K7M2-9QXP`, linked `24 Jun 2026 at 09:41`.

### State 1 — Loading (`.unknown` / `.loading`, cold read)

The initial `GET /assistant/link` is in flight with nothing prior to show. A centered `LoadingStateView`.

```
┌─────────────────────────────────────────────┐
│ ‹ Back            Telegram                    │  ← inline glass nav bar
├─────────────────────────────────────────────┤
│                                               │
│                                               │
│                   ◌  (spinner, --primary)     │  ← ProgressView .large, primary tint
│              Checking status…                 │  ← callout, --text-secondary
│                                               │     (telegram.status.loading)
│                                               │
└─────────────────────────────────────────────┘
            ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯
```

### State 2 — Not connected (`.notConnected`) — the core flow

Explanation → code field + paste → Connect. The **one rationed clay moment lives on the Connect button** (and the seal it stamps).

```
┌─────────────────────────────────────────────┐
│ ‹ Back            Telegram                    │
├─────────────────────────────────────────────┤
│                                               │
│  Your assistant, on Telegram                  │  ← titleL Fraunces (screen lead)
│                                               │
│ ┌───────────────────────────────────────────┐ │  ← explanation CueCard (--surface, letterpress)
│ │ ✦  Message the Cue bot on Telegram to get  │ │  ← body, --text-primary; ✦ in --accent-text
│ │    a one-time code, then paste it here to  │ │     (telegram.explanation)
│ │    link your chat.                         │ │
│ └───────────────────────────────────────────┘ │
│                                               │
│  LINKING CODE                                 │  ← label eyebrow (telegram.code.section)
│ ┌───────────────────────────────────────────┐ │  ← code field: --surface-sunken inset,
│ │ K7M2-9QXP                              ⌫   │ │     1pt --border, JetBrains Mono .code,
│ └───────────────────────────────────────────┘ │     placeholder "Paste your code" (muted mono)
│   ⎘  Paste from Clipboard                      │  ← .secondary row, doc.on.clipboard in --primary
│                                               │     (telegram.paste)
│                                               │
│·····(space)···································│
│                                               │
│ ┌───────────────────────────────────────────┐ │  ← THE clay moment, bottom thumb zone
│ │  ⬗   Connect                               │ │  ← CueButton .decisive (clay + cream),
│ └───────────────────────────────────────────┘ │     leading WaxSeal seal-well glyph
│            ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯          │     (telegram.connect) · disabled when code empty
└─────────────────────────────────────────────┘
```

- **Empty field → Connect disabled** (opacity 0.5): the button is gated on `viewModel.canSubmit` (`!trimmedCode.isEmpty`) `&& !store.isMutating`. The seal-well stays dashed/empty.
- **Placeholder** "Paste your code" (`telegram.code.placeholder`) renders in muted mono inside the inset; once typed/pasted, the live code is `--text-primary` mono.
- The field is **autocapitalization off + autocorrect off** (it's a nonce, not prose) — reflect that as a plain, unfussy mono field with no suggestion bar styling.

### State 2b — Deep-link prefill (same state, sheet chrome, code pre-filled)

Identical to State 2 but as a **sheet** with a grabber, and the field arrives carrying `K7M2-9QXP` from the link. **Never auto-submitted.** A faint `codeSmall` micro-label under the field can read **"Pre-filled from your link — tap Connect to confirm"** to make the no-auto-submit contract visible.

```
┌─────────────────────────────────────────────┐
│              ▁▁▁  (warm glass grabber)        │  ← --surface-sunken zone (sheet only)
│                 Telegram                      │  ← inline title under grabber
├─────────────────────────────────────────────┤
│  Your assistant, on Telegram                  │
│ ┌── explanation card (as above) ───────────┐ │
│ └───────────────────────────────────────────┘ │
│  LINKING CODE                                 │
│ ┌───────────────────────────────────────────┐ │
│ │ K7M2-9QXP                              ⌫   │ │  ← arrives PRE-FILLED from the deep link
│ └───────────────────────────────────────────┘ │
│   Pre-filled from your link — tap Connect      │  ← codeSmall, --text-secondary (no-auto-submit)
│   ⎘  Paste from Clipboard                      │
│ ┌───────────────────────────────────────────┐ │
│ │  ⬗   Connect                               │ │  ← .decisive; on success the SHEET dismisses
│ └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### State 3 — Connected (`.connected(username, linkedAt)`) — the celebration + the ticket

The successful-link "receipt": a stamped **WaxSeal**, the `@handle`, the linked-at timestamp, and Disconnect. **This is where the seal lives after it stamps.**

```
┌─────────────────────────────────────────────┐
│ ‹ Back            Telegram                    │
├─────────────────────────────────────────────┤
│                                               │
│                 ⬗  (stamped WaxSeal, clay)    │  ← centered, cream `link` glyph — THE seal
│                                               │
│        ✦ ASSISTANT ACTIVE                     │  ← label eyebrow, --accent-text + olive dot
│                                               │
│ ┌───────────────────────────────────────────┐ │  ← connected CueCard "ticket" (--surface)
│ │ ┌──────────────────  TELEGRAM  ───────────┐│ │  ← --surface-sunken header strip
│ │ │ (◍) ⌜paperplane⌟  @jane_appleseed       ││ │  ← CueAvatar(40, ring) + titleM Fraunces handle
│ │ │      ● Connected                         ││ │  ← olive dot + label (telegram.status.connected)
│ │ ├──────────────────────────────────────────┤│ │  ← 1pt --separator rule
│ │ │ Linked      24 Jun 2026 at 09:41         ││ │  ← LabeledContent: label + JetBrains Mono .code
│ │ │                                          ││ │     (telegram.linkedAt + formatted linkedAt)
│ │ └──────────────────────────────────────────┘│ │
│ └───────────────────────────────────────────┘ │
│                                               │
│  Forward a message to the Cue bot any time to  │  ← callout, --text-secondary (calm "what now")
│  capture it as a task.                         │
│                                               │
│·····(space)···································│
│ ┌───────────────────────────────────────────┐ │  ← lowest, highest-friction
│ │  🗑  Disconnect                            │ │  ← CueButton .destructive (brick + cream)
│ └───────────────────────────────────────────┘ │     (telegram.disconnect)
│            ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯          │
└─────────────────────────────────────────────┘
```

- **No-handle fallback:** when `username` is `nil`/empty the headline reads **"Connected"** (`telegram.connected.noHandle`) instead of an `@handle`; the avatar keeps its placeholder glyph.
- **No-timestamp fallback:** when `linkedAt` is `nil`/unparseable, the **"Linked …" row is hidden entirely** (the ticket just shows the handle + status).
- The **stamped WaxSeal is shown once on arrival** as the celebration; on a *cold* load of an already-connected account (returning to the screen later) it renders **already-stamped, no animation** (it's a state, not a fresh event).

### State 4 — Failed (`.failed(message)`) — status fetch failed

The `GET /assistant/link` itself errored. Full-state error (this is `Status.failed`, distinct from a transient link/unlink error which is a banner).

```
┌─────────────────────────────────────────────┐
│ ‹ Back            Telegram                    │
├─────────────────────────────────────────────┤
│                                               │
│              ⚠  wifi.exclamationmark          │  ← ContentUnavailableView glyph, --text-secondary
│            Couldn't load status               │  ← title (telegram.error.loadStatus)
│      <server message, e.g. "The network       │  ← message = the caught LocalizedError text
│       connection was lost.">                  │
│                                               │
│               Retry                           │  ← .ghost CueButton, --accent-text
│                                               │     (re-runs store.refreshStatus())
└─────────────────────────────────────────────┘
            ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯
```

### State 5 — Working… (the `isMutating` blocking overlay, layered over State 2 or 3)

While `link()` or `unlink()` is in flight, `store.isMutating` is true: the whole screen is `.disabled` and a **blocking `.loadingOverlay`** covers it — warm-ink scrim (`--text-primary` @0.08, NOT black) + a glass-backed spinner + label **"Working…"** (`telegram.working`). This is **distinct** from State 1's cold-read spinner.

```
┌─────────────────────────────────────────────┐
│ ‹ Back            Telegram   (all disabled)   │
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← warm-ink scrim @0.08 (NOT black)
│░░░░░░░░░┌─────────────────────┐░░░░░░░░░░░░░░│
│░░░░░░░░░│   ◌   Working…       │░░░░░░░░░░░░░░│  ← glass-backed spinner + label
│░░░░░░░░░└─────────────────────┘░░░░░░░░░░░░░░│
│░░░░░░░░░░░░ (Connect / form dimmed beneath) ░│
└─────────────────────────────────────────────┘
```

**The ONE wax-seal / clay moment:** the **Connect** decisive button (clay fill) and the **WaxSeal** it stamps on success — one continuous commit beat. Everything else is espresso structure, olive "active", brass warning, brick destructive. No second clay fill anywhere; no Telegram blue.

---

## Data & states

Bound to the real store + DTO + endpoints (`TelegramLinkStore`, `TelegramLinkStatusDTO`, `LinkTelegramRequest`, `DeepLink`):

- **Source of truth:** `TelegramLinkStore.status: Status` — an enum of exactly **five** cases: `.unknown`, `.loading`, `.notConnected`, `.connected(username: String?, linkedAt: String?)`, `.failed(message: String)`. `.unknown` + `.loading` both render the **loading** view (collapse to one). Plus the orthogonal `store.isMutating: Bool` → the blocking overlay.
- **Status read:** `GET /assistant/link` → `TelegramLinkStatusDTO { linked: Bool, telegramUsername: String?, linkedAt: String? }`. `linked == false` → `.notConnected`; `linked == true` → `.connected(telegramUsername, linkedAt)`. A cold read shows the spinner; a **refresh of already-known** `.connected`/`.notConnected` keeps the prior value until the new one lands (no flash to spinner).
- **Code field:** `ConnectTelegramViewModel.code` (the editable/pre-filled string), `trimmedCode` (whitespace/newlines stripped — what's sent), `canSubmit` (`!trimmedCode.isEmpty`). Realistic value `K7M2-9QXP`.
- **Connect:** `POST /assistant/link` body `LinkTelegramRequest { code }` → `TelegramLinkStatusDTO`. Success → `status = .connected(...)`, posts a **success NotificationBanner** ("Telegram Connected" / "Your Telegram chat is now linked to Cue.", `telegram.connected.title`/`.message`), and **dismisses** the deep-link sheet. Failure → posts an **error banner** ("Couldn't connect Telegram", `telegram.error.linkFailed`) and **leaves the prior status untouched** (you stay on the not-connected form with your code intact to fix + retry). Guarded re-entry: a second tap while `isMutating` is a no-op.
- **Disconnect:** `DELETE /assistant/link` → `status = .notConnected`, posts success ("Telegram Disconnected", `telegram.disconnected.title`). Failure → error banner ("Couldn't disconnect Telegram", `telegram.error.unlinkFailed`), status untouched.
- **Connected receipts:** handle = `@telegramUsername` (prefix `@` if the server didn't), else **"Connected"** (`telegram.connected.noHandle`). `linkedAt` = ISO-8601 string (tolerates fractional seconds) → formatted **abbreviated date + short time** (`24 Jun 2026 at 09:41`); hidden if `nil`/unparseable.
- **Deep-link prefill:** `DeepLink.telegramLink(code:)` parsed from **both** `cue://telegram/link?code=K7M2-9QXP` and `https://<host>/app/telegram/link?code=K7M2-9QXP`; blank codes are rejected at parse time. The parsed code seeds `ConnectTelegramView(prefilledCode:)` → the field is pre-filled, **never auto-submitted**, and the sheet dismisses on a successful Connect.

**Edge cases (render at least the bad-code + network ones):**
- **Bad / expired / already-redeemed code:** the `POST` 4xx → error banner (brick rail) **and** an inline **brass notice** above Connect — `--warning` @0.12 fill, 1pt `--warning` @0.4 border, radius `small`, **INK on brass**: "⚠ That code didn't work — get a fresh one from the bot." The code stays in the field; Connect re-enables. (Codes are single-use nonces — a re-tap of a burned code must read as recoverable, not fatal.)
- **Network failure on Connect/Disconnect:** transient → error banner only; the form/connected state stays put, inputs re-enable. (Full-screen `ErrorStateView` is reserved for the **status-read** failure → State 4.)
- **Already linked (deep link arrives while connected):** the sheet opens onto the **connected** state (status read wins) — the prefilled code is harmless because Connect isn't shown; the user sees their existing `@handle`. (If a *different* account's code is redeemed, the `POST` re-points the link and re-stamps.)
- **Offline cold open:** status read fails → State 4 (`.failed`) with Retry; not a blank form.
- **Sign-out mid-screen:** `store.clear()` resets to `.unknown` so a new session can't see stale link state.

---

## Interactions & motion

- **Paste:** "Paste from Clipboard" reads `UIPasteboard.general.string`, trims it, and fills the field. No-op (no error, no flash) when the clipboard holds no usable text. The field then shows the live mono code; Connect enables if non-empty. `.sensoryFeedback(.selection)` on a successful paste.
- **Connect (the signature):** tap → `isMutating` true → the **blocking "Working…" overlay** fades in (`.snappy`). On success: the overlay clears and the **WaxSeal stamps** — `.spring(response: 0.42, dampingFraction: 0.62)`, scale 0.4→1, opacity 0→1, rotation −8°→0° (~450ms settle), the dashed seal-well filling to clay with a cream `link` glyph. The screen cross-fades to the **connected** state over `.easeOut(0.16)`; the success banner slides in (olive rail). `.sensoryFeedback(.success)`. In the **deep-link sheet**, the seal stamps and the sheet **dismisses** right after (≈450ms so the stamp is seen). **Reduce-Motion fallback:** no spring/rotation — the seal **cross-fades** opacity-only from seal-well to stamped; the state swap is an instant cross-fade; the banner appears without slide. `.success` haptic still fires.
- **Connect failure:** overlay clears, the brass inline notice + error banner appear (`.snappy`); the code remains; the seal-well stays dashed (never stamps on failure). `.sensoryFeedback(.error)`.
- **Disconnect (confirm first):** Disconnect routes through a `.confirmationDialog` ("Disconnect Telegram? The Cue bot will stop capturing your messages." · destructive **Disconnect** / Cancel) — never a one-tap revoke. Confirm → `isMutating` overlay → on success the screen cross-fades back to the **not-connected** form (the seal is **not** shown — undo is calm, not a celebration), success banner (olive). `.sensoryFeedback(.impact)` on confirm.
- **Button press:** every CueButton depresses 1pt downward (`.easeOut(0.16)`) — no scale/glow/shadow; `.decisive` Connect adds the `--primary-pressed` multiply overlay @0.22.
- **Deep-link prefill:** the field animates in already-filled; no submit fires. The "Pre-filled from your link" micro-label fades with the field.
- **Retry (failed state):** tapping the `.ghost` Retry re-runs `refreshStatus()`; the error view cross-fades to the spinner, then to whatever the read returns.

The **160ms ease-out** (every press/toggle/cross-fade) and the **single seal spring** are the two recurring signatures — do not invent new curves.

---

## iOS specifics

- **Dynamic Type:** all roles are relative type styles — lead, explanation, handle, timestamp, button labels scale. The **mono code is exempt from re-flow tricks** but still scales; at AX sizes the code field grows to two lines rather than truncating, and the LabeledContent "Linked / timestamp" row stacks (label above value) instead of clipping. Buttons are already full-width. Never fix point sizes; never clip the code.
- **Haptics (`.sensoryFeedback`):** `.success` on a completed link · `.selection` on paste + on the confirm-dialog open · `.impact` on the Disconnect confirm · `.error` on a failed Connect/Disconnect. Respect the system haptic setting.
- **Paste affordance:** beyond the explicit "Paste from Clipboard" row, the field supports the **native iOS paste callout** (long-press → Paste) and, on iOS, the system "Paste" accessory; the explicit row exists so the action is **discoverable without a long-press** (the deep-link/clipboard handoff is the common path).
- **Keyboard:** the code field uses a plain keyboard, autocapitalization **off**, autocorrect **off**, no smart-dashes mangling of the nonce; a keyboard toolbar can carry a single **Done** to dismiss. The field is the only text input — focus it on a manual (non-prefilled) open.
- **Sheet (deep-link variant):** `.presentationDetents([.medium, .large])` is overkill for this short form — present at a **single height** sized to content (or `.medium`) with `.presentationDragIndicator(.visible)`; dismiss on swipe-down or on successful Connect.
- **VoiceOver labels:**
  - Lead: "Your assistant, on Telegram." Explanation read verbatim.
  - Code field: "Linking code, text field" + value spoken **grouped** ("K 7 M 2 dash 9 Q X P") so the nonce is dictatable; placeholder "Paste your code."
  - Paste row: "Paste from Clipboard, button."
  - Connect: "Connect, button" + `.accessibilityHint("Links your Telegram chat")`; disabled state announced. The WaxSeal itself is `.accessibilityHidden(true)` (decorative — the button carries the label).
  - Connected: the ticket speaks "Telegram connected as jane underscore appleseed, linked 24 June 2026 at 9:41 AM" — the **status word "Connected"** is spoken (color/dot is never the sole signal). Disconnect: "Disconnect, button" + destructive trait + the confirm dialog.
  - Failed: "Couldn't load status" + the message + "Retry, button."
  - Working overlay: announces "Working" via the overlay label; inputs report disabled.

---

## ✦ Claude Design prompt (paste this)

```
Design a single native iOS 26 screen: "Connect Telegram" for CUE, an AI-assisted calendar +
Telegram-assistant app. This is the app's HEADLINE integration — linking the Telegram AI assistant
by redeeming a one-time code. Use the published "Kraft & Ink" design system and its tokens ONLY —
no new colors, fonts, gradients, or pure white/black surfaces. Reference every token + component by
name. Render ALL FIVE STATES (separate frames), plus the blocking "Working…" overlay.

FRAME: Fixed iPhone 393×852pt @3x, NOT responsive — a native iOS screen, not a web page. Primary
entry is PUSHED from Settings: full screen on --background, inline warm Liquid-Glass nav bar titled
"Telegram" with a back chevron, status bar + Dynamic Island reserved (top safe area ~59pt), 34pt
home-indicator gutter, 16pt side margins, all tap targets ≥44pt. Also show the deep-link SHEET
variant: fill --surface-elevated, corner radius 12, a warm-glass grabber zone (--surface-sunken),
same inline title beneath — with the code field PRE-FILLED and a micro-label saying it was filled
from the link (it is NEVER auto-submitted; the user always taps Connect; the sheet dismisses on
success).

PURPOSE: Link / unlink the Telegram assistant. The user messages the Cue bot, gets a one-time code,
pastes it here, and taps Connect — celebrated with a single wax-seal stamp.

THE FIVE STATES (off TelegramLinkStore.status):
  1. LOADING (cold status read) — centered ProgressView (--primary tint) + "Checking status…"
     (callout, --text-secondary). Nothing else.
  2. NOT CONNECTED — top: lead "Your assistant, on Telegram" in Fraunces titleL. An explanation
     CueCard (--surface, letterpress): "Message the Cue bot on Telegram to get a one-time code,
     then paste it here to link your chat." (Public Sans body; a ✦ sparkle in --accent-text). Then
     a "LINKING CODE" label eyebrow + a code FIELD rendered as a --surface-sunken inset with a 1pt
     --border edge, the code in JetBrains Mono (.code) showing "K7M2-9QXP", placeholder "Paste your
     code" in muted mono. Below it a quiet ".secondary" row "Paste from Clipboard" with a
     doc.on.clipboard glyph in --primary. PINNED in the bottom thumb zone: CueButton .decisive
     "Connect" (--secondary clay fill + cream label) with a small dashed WaxSeal SEAL-WELL glyph at
     its leading edge — DISABLED (opacity 0.5) when the field is empty.
  3. CONNECTED — a centered STAMPED WaxSeal (irregular clay blob + cream `link` glyph). A
     "✦ ASSISTANT ACTIVE" label eyebrow with a small olive (--success) dot. A connected "ticket"
     CueCard with a --surface-sunken "TELEGRAM" header strip: a small CueAvatar (size 40, 1.5pt
     --primary ring, paperplane.fill glyph — NOT the Telegram logo) + the handle "@jane_appleseed"
     in Fraunces titleM, an olive dot + "Connected" beneath; a 1pt --separator rule; then a
     LabeledContent row "Linked    24 Jun 2026 at 09:41" (label + JetBrains Mono .code). A calm
     callout line "Forward a message to the Cue bot any time to capture it as a task." LOWEST,
     highest-friction: CueButton .destructive "Disconnect" (--danger brick fill + cream).
  4. FAILED (status read errored) — ContentUnavailableView: wifi.exclamationmark glyph
     (--text-secondary), title "Couldn't load status", a server message line, and a .ghost CueButton
     "Retry" (--accent-text).
  5. WORKING (isMutating, layered over state 2 or 3) — the whole screen disabled under a BLOCKING
     overlay: a warm-ink scrim (--text-primary @0.08, NOT black) + a glass-backed spinner + label
     "Working…".

COMPONENTS (by name): CueCard (--surface, radius 10, letterpress = 1pt --border + hard value-cut
shadow at --text-primary 6%, BLUR RADIUS 0, y:1), CueButton (.decisive/.destructive/.secondary/
.ghost; full-width, radius 6, label Public Sans 16 semibold, press = 1pt downward letterpress
offset), CueAvatar (circle, 1.5pt --primary ring), WaxSeal (irregular hand-pressed clay blob, NOT a
clean circle; a dashed seal-well that stamps to clay + cream `link` glyph on Connect), the warm
Liquid-Glass nav/grabber + the loadingOverlay scrim, and a NotificationBanner (olive rail success /
brick rail error).

REAL CONTENT (verbatim, no lorem, no "User 1"): code "K7M2-9QXP"; handle "@jane_appleseed"; linked
"24 Jun 2026 at 09:41"; explanation "Message the Cue bot on Telegram to get a one-time code, then
paste it here to link your chat."; success banner "Telegram Connected — Your Telegram chat is now
linked to Cue."; bad-code notice "That code didn't work — get a fresh one from the bot."

EDGE CASES to bake into the not-connected frame: a BAD-CODE inline notice above Connect — a brass
(--warning) tile, @0.12 fill + 1pt --warning @0.4 border, radius 6, INK on brass (never cream):
"⚠ That code didn't work — get a fresh one from the bot." The code stays in the field; Connect
re-enables. No-handle fallback = headline "Connected"; no-timestamp = the "Linked …" row hidden.

MOTION: Connect → "Working…" overlay (.snappy) → on success the WaxSeal STAMPS with spring(response
0.42, damping 0.62): scale 0.4→1, rotation −8°→0° (~450ms); screen cross-fades to Connected over
160ms ease-out; success banner slides in. In the deep-link sheet the seal stamps then the sheet
dismisses. Reduce-Motion fallback: seal cross-fades opacity-only, state swap is an instant
cross-fade, no rotation, no slide. Buttons depress 1pt on press (160ms ease-out); .decisive adds a
--primary-pressed multiply @0.22. Disconnect goes through a confirmationDialog first and does NOT
stamp the seal (undo is calm). Haptics: .success on link, .selection on paste, .impact on Disconnect
confirm, .error on failure.

iOS PATTERNS: inline nav title; grouped-inset feel; code field with autocapitalization OFF,
autocorrect OFF, native paste callout PLUS the explicit "Paste from Clipboard" row; deep-link sheet
at a single content height with a visible drag indicator that dismisses on success; VoiceOver speaks
the code grouped and the status word "Connected" (never color-only). Dynamic Type: relative styles,
the code field grows to two lines and the Linked row stacks at AX sizes — nothing clips.

ANTI-AI-SLOP GUARDRAILS (hard): NO Inter / Helvetica / SF Pro — pin Fraunces (titles ≥17pt), Public
Sans (body/labels), JetBrains Mono (the CODE, the handle, the timestamp — receipt voice). NO purple,
NO blue accents — and specifically NO Telegram brand blue: the integration wears Kraft & Ink, not
Telegram's colors. NO gradients, NO glassmorphism on the content cards (glass is chrome-only — the
nav bar, the sheet grabber, the Working overlay — and re-tinted WARM, never Apple cool blue). NO
soft uniform drop shadows — letterpress only (1px border + hard value-cut, blur 0). NO pure #FFFFFF
surface-on-white, NO pure #000000. NO generic evenly-spaced bento grid — this is a one-column
typesetter's page that breathes. Crisp 4–12px cut-paper corners, never 16–20px squircle bubbles. The
terracotta wax seal + the clay Connect button are the SINGLE rationed clay moment (one continuous
commit beat) — appearing once; "active" is olive, the warning is brass, Disconnect is brick, all
structure is espresso. Color presence, not a rainbow. Do not say "modern / clean / sleek /
beautiful". Honor Kraft & Ink exactly; native iOS, not a web page.
```
