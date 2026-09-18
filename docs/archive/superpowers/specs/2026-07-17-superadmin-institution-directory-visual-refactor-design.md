---
source:
  - user-approved design in Codex conversation on 2026-07-17
  - user-provided institution directory screenshots and Flutter prototypes
  - specs/003-superadmin-core.md
  - docs/design/design-system.md
status: approved
generated_at: 2026-07-17
---

# Superadmin Institution Directory Visual Refactor

## Objective

Refactor the Superadmin institution directory so its visual hierarchy, density,
responsive behavior, cards, table, navigation shell, and controls follow the
screenshots and prototype code supplied by the user. Preserve the existing
Supabase integration, repository contract, view model, server pagination,
debounced search, filters, authorization behavior, and load states.

The screenshots and attached prototype are the visual contract. Their local
colors, obsolete imports, monolithic structure, institution status `trial`, and
generic use of the word "escola" are not implementation contracts.

## Scope

- Refactor `SuperadminShell` into the compact desktop/mobile composition shown
  in the references.
- Make the sidebar reusable and collapsible on desktop, with a drawer on compact
  layouts.
- Align the brand divider with the page-header divider and keep sufficient
  breathing room around the official Coelo logo.
- Keep the user summary and logout action in the page header, not the sidebar.
- Refactor the institution toolbar, card grid, create affordance, data table,
  pagination placement, and responsive layout.
- Keep Cards as the initial view and allow switching between Cards and Table
  without resetting the current query.
- Retain the floating developer menu on every screen.
- Update widget tests to describe the approved behavior.

## Out of Scope

- Database or Supabase schema changes.
- New institution and import workflows; their controls continue to show a safe
  future-flow message.
- Media integration for institution logos.
- Catalog population for institution types.
- Changes to authentication, recovery-password work, or unrelated features.

## Visual Structure

### Shell

On expanded layouts, the shell uses an 88 logical pixel brand/header row. The
sidebar is 260 logical pixels when expanded and 88 logical pixels when
collapsed. Its 24 logical pixel circular collapse control overlaps the sidebar
divider in both states. The selected Institutions item uses a solid semantic
primary background with `onPrimary` content; other destinations remain
available for hover feedback using semantic primary-container colors without
navigating to unfinished screens.

The brand area places the official project mark, recolored through Flutter's
`ColorFiltered`, inside a 48 logical pixel graphite block and shows only
`Superadmin` beside it when expanded. Its bottom divider is aligned with the
bottom divider of the institution page header. The page header contains the
title, subtitle, user avatar/name, and logout action. On compact layouts, the
sidebar becomes a drawer and the page header remains visually economical.

The primary navigation contains Institutions, Plans, Internal users, Notices,
Import, Support, and Audit. The sidebar footer contains only Settings. The
developer menu remains exclusively in the global floating control, and user
profile content never appears in the sidebar.

### Page Header

- Title: `Instituições`.
- Subtitle: `Gerencie as instituições da plataforma.`
- No use of `escola` as a generic institution term.
- No import action is shown in this directory; its future flow is deferred.

### Filter and View Toolbar

The toolbar is placed directly on the page background, not inside a large Card.
It uses 40-48 logical pixel pill-shaped Material controls themed by Coelo
tokens. The search is 300 logical pixels on desktop:

- search by public, trade, or legal name only;
- status filter;
- plan filter;
- UF filter;
- institution type filter;
- segmented Cards/Table control.

Controls wrap according to available width. The search keeps its existing
300 ms debounce. Changing a filter resets server pagination; switching the view
does not change the query. Active filters retain a compact clear action.

### Card View

Cards are the initial presentation. A responsive builder grid uses available
width rather than device-type checks. The first grid item is the dashed
`Criar instituição` affordance. It shows `Adicionar nova instituição ao
sistema.` and triggers the existing future-flow message.

Institution cards follow the exact information hierarchy approved on
2026-07-17:

- initial-based avatar, public name, municipality/UF, and status chip in the
  header;
- domain immediately below, with an accessible copy-to-clipboard action;
- divider;
- Type beside Plan;
- Unidades beside `Grupos (Turmas)`.

Legal name is not rendered in cards or table. The create-institution affordance
has a transparent background and dashed semantic border. In rest state its
circle is a neutral surface with a primary plus icon; hover/focus animates the
border, circle, and a subtle primary-colored shadow.

Hover and focus animate for 200-220 ms and use semantic primary/primary-container
colors from the theme: a light primary border and subtle primary shadow. No
local HEX values or invented palette entries are allowed.

### Table View

In table mode, a full-width transparent dashed create-institution banner appears
before the table. The table includes Institution, Municipality/UF, Domain with
copy action, Tipo, Plano, Unidades, `Grupos (Turmas)`, and Status. It scrolls
horizontally on narrow viewports. Rows are interactive so the theme's existing
`primaryContainer` hover is applied rather than a local gray.

### Responsive Behavior

- Compact: drawer navigation, wrapped toolbar, one card per row, horizontal
  table scrolling.
- Medium: wrapped toolbar and two-card layout when space permits.
- Expanded and larger: collapsible sidebar and as many approximately 330-400
  logical pixel cards as the available content width supports, including five
  tiles in the widest supplied reference.
- Touch targets and keyboard focus remain accessible.

## Architecture and Components

Keep the existing UI/logic/data boundaries:

- `InstitutionDirectoryPage` owns only transient display mode and controller
  lifecycle.
- `InstitutionDirectoryViewModel` remains the query/load-state owner.
- `InstitutionDirectoryRepository`, fake repository, and Supabase repository
  remain unchanged unless a test exposes a genuine contract defect.

Small private or reusable widgets may be extracted where they clarify layout or
remove duplication, including the view toggle, compact filter control, create
institution tile/banner, institution card, status chip, and collapsible shell
navigation. Do not introduce a new package, dependency, or speculative design
system abstraction. Existing themed Material components are preferred because
`CoelloButton`, `CoelloCard`, and `CoelloAvatar` do not exist in the repository.

## Data and Status Rules

- Keep all existing query fields and server-side pagination of 20 records.
- Search must not match domain.
- Institution statuses remain `draft`, `onboarding`, `active`, `inactive`,
  `suspended`, and `archived`.
- `trial` remains a subscription concept and must not be rendered as an
  institution status.
- The real type filter may be empty until the catalog is populated.
- CNPJ remains absent from the directory listing.

## States and Interaction

Preserve loading, initial empty, no results, safe error, unauthorized, success,
retry, and pagination states. Changing between Cards and Table preserves the
search text, filters, loaded page, and results. The Create control shows the
existing informational SnackBar until that flow is implemented.

## Validation

- Widget tests for Cards as default and Cards/Table state preservation.
- Widget tests for create message, shell header/profile/logout, sidebar
  collapse/drawer behavior, active and hover navigation states, and the
  Settings-only footer.
- Widget tests for filter labels, absence of domain search, and UF/type filters.
- Responsive tests at widths representative of 375, 768, 1024, and 1440.
- Clipboard-copy coverage for card and table domains.
- Table horizontal-scroll and semantic hover-color coverage.
- Existing view-model, repository, domain-model, auth, and route tests remain
  green.
- Run Dart formatting, static analysis, the Flutter test suite, and a web build.

## Acceptance Criteria

- The implementation is visibly faithful to the supplied screenshots at the
  target widths while using Coelo theme tokens exclusively.
- Cards are selected on first load and the segmented control switches to Table.
- The header no longer consumes 180 logical pixels.
- The toolbar is compact and is not wrapped in a large filter Card.
- All required fields and filters remain available.
- The shell divider alignment, official logo, top-right profile, responsive
  navigation, orange hover, and floating developer menu match the approved
  behavior.
- Supabase integration and unrelated authentication changes are preserved.
