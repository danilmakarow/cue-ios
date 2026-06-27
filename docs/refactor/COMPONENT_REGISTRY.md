# CUE Refactor — Canonical Component Registry

**Purpose:** the single source of truth for every shared UI element. Page/feature
teams MUST consume from this registry and MUST NOT redefine any component listed
here. New shared components are built ONCE in the Foundation workstream (Phase 3),
before any page team starts. Page-specific components are owned by exactly one
workstream (named below).

Theme target: **CUE — Clean** (white surfaces, soft floating shadows, generous
clay `#BE4A28` + olive `#466234` accents [today/done = olive, now/brand = clay],
IBM Plex Serif titles-only + native system sans + JetBrains Mono, soft radii
8/10/12/14). Migrating FROM Kraft & Ink.

Key architectural fact: cue-ios uses semantic token roles everywhere — **zero
hardcoded Kraft hex outside `Theme.swift` and `BrandMark.swift`**. So the reskin
is overwhelmingly a token-file revaluation that cascades to every screen.

---

## 0. TOKEN FOUNDATION (Phase 3 · Foundation workstream · RESKIN)

These four edits drive ~90% of the visual migration. Cascade to all screens.

| File | Change |
|---|---|
| `cue/DesignSystem/Theme.swift` | Revalue the color table Kraft→Clean (see token map below). Rename `AppPalette.kraftInk` → `.clean` + the `theme.palette.kraftInk` localization keys + `ThemeSettings` default + `\.theme` @Entry default + `SettingsView` palette row. Retire/repoint legacy `TravelerColor`. |
| `cue/DesignSystem/Tokens/Radius.swift` | Soften: chip 4→8, button/field 6→10, card 10→12, add ceiling 14. |
| `cue/DesignSystem/Tokens/Depth.swift` | Replace blur-0 letterpress (`.letterpress`/`.valueCut`) with SOFT floating shadows: rest `0 1px 2px /.05`, float layered `0 1px 2px /.04 + 0 3px 7px /.05` (real blur radius). **Single biggest visual lever** — flows to every CueCard + UIKit cell. |
| `cue/DesignSystem/Tokens/Typography.swift` | `serifFamily` Fraunces→**IBM Plex Serif**; `bodyFamily` Public Sans→**native system** (.system); keep `monoFamily` JetBrains Mono. Serif only on titles ≥17pt. Register new fonts in `Resources/Fonts` + Info.plist; drop Fraunces/Public Sans. |
| `cue/Features/Calendar/UIKit/CalendarTheme.swift` + cells | Auto-tracks token colors/fonts, BUT bakes Kraft metrics (radiusSmall 6, hourHeight 36) and hand-built blur-0 shadow layers in `DayAgendaCell` etc. Re-author cells to soft shadows + new radii. **The one place outside token files needing real per-cell visual work.** |

`Spacing.swift` = unchanged (theme-agnostic, already 4pt grid).

**Color token map (Theme.swift):** background/surface `#FAF6EF`→`#FFFFFF`; add bg-grouped `#F7F6F4` + fill `#F0EEEB`; primary espresso `#5A3A24`→clay `#BE4A28`, primaryPressed→`#A53D22`; onAccent cream `#FBF5EA`→white `#FFFFFF`; success olive `#466234` (today/done/ON), warning brass `#C9A24B`, danger brick `#A8331F`, info espresso→ink `#1F1E1C`; separator `#D0BA98`→`#EFEDEA`, border `#8C7142`→`#E6E3E0`; text `#2E211A`→`#1F1E1C`, secondary→`#6B6864`, add tertiary `#9C9893`; add accent-soft `#FBEEE7`, success-soft `#E9EFE2`.
**Selection rule:** neutral selection = GRAY fill; semantic = accent (today/done/ON = olive, brand/now = clay). Chip-selected = clay WASH + clay text (was solid espresso). Toggle ON = OLIVE.

---

## 1. EXISTING DS COMPONENTS — RESKIN (Phase 3 · Foundation)

Reskin mostly cascades via tokens; per-component work noted. Owned by Foundation.

| Component | File | Per-component work beyond token cascade |
|---|---|---|
| CueButton | Components/CueButton.swift | Radius.small 6→10. Keep the 1pt press (still valid). Verify primary(clay) vs decisive(clay) read distinctly by context. |
| CueCard | Components/CueCard.swift | Default depth .letterpress→soft float; header strip bg → fill `#F0EEEB`; radius→12. |
| CueChip | Components/CueChip.swift | **Model change:** selected = clay WASH (accent-soft) + clay text, NOT solid fill. Radius 4→8. Unselected fill→gray `#F0EEEB`. |
| CueAvatar | Components/CueAvatar.swift | Ring→clay (auto); placeholder fill→gray. Optional: add initials fallback. |
| WaxSeal | Components/WaxSeal.swift | **DECISION (adopt):** the commit MOTION moves to RootsCommitView; the task done-marker becomes OliveCheck. WaxSeal narrows to brand/save-moment static mark; glyph font→IBM Plex Serif. |
| BrandMark | BrandMark.swift | Monogram font Fraunces→IBM Plex Serif. Keep fixed brand literals (clay/rim/cream). |
| NotificationBanner (+Store/Host/AppNotification) | Notifications/ | Glass tint warm→clean white-translucent; severity rail info→ink. Add expandable-error variant (show-more + mono HTTP detail) if absent. |
| LoadingStateView / InlineLoadingRow / .loadingOverlay | Components/LoadingStateView.swift | Spinner tint→clay (auto). Optional skeleton→content cross-fade. |
| ErrorStateView | Components/ErrorStateView.swift | Retry button .borderedProminent→`.cue(.secondary)`; title→serif. |
| ViewModeSwitcher | Features/Calendar/Components/ | Capsule colors follow tokens; verify under Clean. |
| FloatingAddButton / FAB | DesignSystem/Components/ | Fill→clay (auto), soft float shadow. Reconcile FAB vs tab-bar "+" (app uses tab-bar +). |
| TabBar / NavBar | system (AppNavigation) | Liquid Glass automatic — DO NOT hand-roll. Active tint→clay on gray pill; nav title→IBM Plex Serif ≥17pt. |

---

## 2. NEW SHARED COMPONENTS — BUILD ONCE (Phase 3 · Foundation, before any page team)

These have NO existing equivalent and are used by ≥2 screens. Build in
`cue/DesignSystem/Components/`. **Page teams consume these; never rebuild.**

| Component | Used by | Spec |
|---|---|---|
| **CueField** | Create/Edit Event, Group Edit, Search, Account | Labelled input: uppercase eyebrow label, gray fill `#F0EEEB`, 1px border→clay on focus (no glow), radius 10, optional mono variant, helper/error caption. |
| **CueBadge** | Today, Assistant, Groups, Settings, Notifications | Mono uppercase status stamp. Tones: done=olive, pending=brass(dark ink), info=ink, blocked=brick, neutral=gray. Outline variant. NEVER clay. |
| **CueToggle** | Settings, Account, Notifications, Create/Edit, Onboarding | Switch; ON=OLIVE, OFF=gray track, white knob. (Or tint native Toggle olive.) |
| **RootsCommitView** | Create Event (save), Event Detail/Today (task done) | The new signature commit animation: ~16-tendril root growth under a check mask, expo-out .78s, scale 0→1.045→1, color flood last 45%. GREEN on save, CLAY on done. `.success` haptic. Replaces WaxSeal spring-stamp. |
| **OliveCheck (done marker)** | Today, Calendar Day, Event Detail, Search | Olive filled circle + white check; the canonical "completed" marker (replaces clay seal). |
| **SegmentedControl** (generic) | Calendar scope bar, Notifications channel, Event Edit scope | Neutral track = gray (fill-selected); semantic = accent. Distinct from WeekStrip (which uses clay for today). |
| **InlineDateTimePicker** | Create/Edit Event | Inline date+time well (mono receipt values), expandable. |
| **OnboardingPageView** | Onboarding | One carousel page (illustration/brand + headline + body), driven by pager. |
| **ConfirmActionSheet** | Event Detail/Edit (delete series/occurrence), Account (delete/sign-out) | Destructive confirm sheet (brick CTA + cancel). |
| **EmptyStateView** (formalize) | Groups, Search, Today, Calendar | Thin glyph + serif title + message + optional secondary CTA, on ContentUnavailableView. |
| **SettingsRow / ListRow** (extract) | Settings, Account, Notifications, Detail | Label + optional mono sub + trailing control/chevron + hairline. Extract on 3rd caller. |
| **MiniMonth (SwiftUI)** *(build-if-needed)* | date pickers, possibly Year | UIKit `YearMiniMonthCell` already serves the calendar. Build a SwiftUI MiniMonth only if a date picker needs it; today=olive round, neutral-pick=gray, days in mono. |
| **IconGridPicker / ColorSwatchPicker** *(promote-if-shared)* | Group Edit (+ Create/Edit Event if per-task icon ships) | Built in Group Edit; PROMOTE to shared if Event icon picker ships. Avoid two copies. |

---

## 3. PAGE-SPECIFIC COMPONENTS — one owner each (Phase 4, NOT shared)

Built inside their feature folder by exactly one workstream. Listed so no two
teams build the same thing. (If any turns out to be needed by a 2nd screen,
promote it to §2 via the Foundation owner — do not copy.)

- **Today workstream:** TodayGreetingHeader, TodayNextHeroCard, MorningBriefCard, TodayLoadMeter, TodayAgendaRow.
- **Assistant Persona workstream:** PersonaReceiptTag, CharCountLabel (promote CharCountLabel if reused), AIContextTile (also Event Detail — consider shared).
- **Calendar workstream:** DayTimelineCanvas, AllDayBand, NowLine/NowIndicator, DayHeadingRule, DayDensityCell, DensityLegend, MonthWeekdayLegend, MonthTitleHeader, DayEventDots, JumpToTodayPill/FloatingTodayPill, YearTitleHeader, ZoomGhostTransition, WeekStrip (exists in UIKit). (Most already exist as UIKit cells — reskin, not new.)
- **Events workstream:** NaturalLanguageQuickCreateWell, ReminderRowEditor/ReminderRow, MonthlyRecurrenceModes, RecurrenceBuilderInline, InlineTimeWheelPicker, DetailHeaderBlock, DetailLedgerRow, RecurrenceErrorNotice.
- **Groups workstream:** GroupIconTile, InlineStepper, GroupColorSwatchPicker (→ promote if Events needs it).
- **Onboarding workstream:** OnboardingContainer, OnboardingProgressDots.
- **Notifications/Report workstream:** WeekDayBubbleCluster (if used), channel SegmentedControl (consume §2).

---

## RULES FOR PAGE TEAMS
1. Read this registry before writing any view. If a component exists in §1/§2, import it.
2. Need a shared component not in §2? STOP — request the Foundation owner add it; don't define it locally.
3. Page-specific component turns out to be needed elsewhere? Promote via §2, don't copy.
4. Never touch `Theme.swift`/`Radius.swift`/`Depth.swift`/`Typography.swift` in a page worktree — those are Foundation-owned and frozen after Phase 3 merges.
