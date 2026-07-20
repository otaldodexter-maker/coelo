---
source:
  - user-approved design in Codex conversation on 2026-07-20
  - user-provided institution directory screenshots
  - docs/superpowers/specs/2026-07-17-superadmin-institution-directory-visual-refactor-design.md
  - docs/design/design-system.md
  - specs/011-superadmin-database-rls.md
status: approved
generated_at: 2026-07-20
---

# Superadmin Institution Directory Contact and Comfort Refinement

## Objective

Refine the institution directory into a calmer, more breathable foundation for
future Superadmin and Admin screens. Preserve the existing feature layers,
protected route, fake preview, pagination, debounce, authorization, Coelo theme,
and empty real Supabase state while improving the card hierarchy, table density,
dependent filters, profile actions, and institutional contact model.

## Database Findings

The live `coelo` Supabase project already contains the applied migration
`20260717151609_institution_directory_foundation`. It has:

- `institution_addresses`, one legal address per institution;
- `unit_addresses`, one physical address per unit;
- separate `country`, `state`, `city`, `district`, `street`, `number`,
  `complement`, and `postal_code` fields;
- a `security_invoker` `institution_directory` view;
- no institution or unit contact fields suitable for displaying and copying a
  full e-mail, telephone, or mobile number.

`primary_contact_person_id` identifies a person. It must not be reused as the
public institutional contact because `person_contacts` intentionally stores
masked/hash-based personal contact data.

## Contact Model

Create two one-to-one optional contact tables:

- `institution_contacts`, keyed by `institution_id`;
- `unit_contacts`, keyed by `unit_id`.

Both tables contain `email`, `phone`, `mobile_phone`, `status`, `created_at`,
and `updated_at`. Contact values are nullable because the real catalog starts
empty and a future workflow may save partial records. If supplied, values must
be non-blank. A row must contain at least one contact value. Foreign keys use
`on delete cascade`.

The tables enable RLS, revoke implicit access from `public`, `anon`, and
`authenticated`, grant explicit read access only to `authenticated`, and apply
the existing `platform.read` policy. No write policy is added; institution and
unit creation remain future audited command workflows.

Update the schema catalog for both tables. Do not seed contacts, institutions,
units, or institution types.

Replace `institution_directory` while preserving `security_invoker`, explicit
grants, all current columns, and document privacy. Add `contact_email`,
`contact_phone`, and `contact_mobile_phone` from `institution_contacts`.

Create `institution_directory_locations` as a `security_invoker` view of
distinct active `state`, `city`, and `district` combinations for dependent
filters. It is readable only by `authenticated`; base-table RLS continues to
require `platform.read`.

## Card Refinement

Cards remain the default display and use initials until private branding media
is integrated. The avatar becomes visually quieter and keeps sufficient space
around its initials. The institution name uses a slightly smaller semibold
theme style. The status chip is compact and aligned at the top-right without
competing with the name.

The card header contains:

- initials fallback;
- institution public name;
- `Bairro, Municipio/UF`, falling back to `Municipio/UF`, then the available
  address portion;
- institution status.

Remove domain from cards. After a subtle divider, render a two-by-two detail
grid with comfortable row gaps:

- `Tipo` beside `Plano`;
- `Unidades` beside `Grupos (Turmas)`.

Labels use a restrained semibold style and values use normal body text. Icons
remain semantic Material icons, but their containers are smaller and quieter.
Cards retain the existing subtle primary border and shadow on hover/focus with
no scale or layout movement.

The create card uses the same height and grid width as institution cards.

## Table Refinement

In table mode, the create-institution banner and table share one minimum width
and one horizontal scroll context. The minimum width is large enough to avoid
compressing contact and address columns. Columns are:

1. Instituicao
2. Bairro
3. Municipio
4. UF
5. Dominio
6. E-mail
7. Telefone
8. Celular
9. Tipo
10. Plano
11. Unidades
12. Grupos (Turmas)
13. Status

Domain, e-mail, telephone, and mobile values have independent accessible copy
actions when present. Missing values display an em dash. The table retains the
semantic primary-container row hover and horizontal scrolling on compact
viewports.

## Filters

The toolbar order is fixed:

1. `Buscar por nome`
2. `Tipos`
3. `Status`
4. `UF`
5. `Municipio`, visible only after selecting UF
6. `Bairro`, visible only after selecting Municipio
7. Cards/Table display control

Remove Plan from the visible toolbar. Search remains name-only with 300 ms
debounce. Selecting UF clears municipality and district. Selecting municipality
clears district. Changing any filter resets pagination.

Replace `DropdownButtonFormField` with a small reusable pill menu based on
Material `MenuAnchor`. Menus open below their trigger, use Coelo theme surfaces,
rounded corners, constrained height, comfortable item padding, keyboard focus,
and semantic labels. No local HEX colors or new palette are allowed.

## Header and Navigation

Remove Settings from the sidebar. The page header adds, from left to right on
its action area:

- notification bell;
- bug-report icon;
- clickable circular avatar and user summary.

Remove the inline logout button. Clicking the profile summary opens a rounded
menu below it with `Perfil`, `Configuracoes`, and `Sair`. Profile and Settings
show safe future-flow feedback in this delivery; Logout invokes the existing
real `LogoutAction`. Bell and bug-report actions also show safe future-flow
feedback until their flows are specified.

The compact header preserves access to all three profile actions without
placing them in the drawer.

## Architecture

- Extend `InstitutionDirectoryItem` with district and institutional contacts.
- Extend `InstitutionDirectoryQuery` with city and district while retaining
  `planId` internally for compatibility.
- Extend filter options with locations and make repository option loading
  dependent on selected UF and municipality.
- Keep fake and Supabase repositories behind the existing interface.
- Keep `InstitutionDirectoryViewModel` responsible for dependent-filter resets.
- Keep display-only state in `InstitutionDirectoryPage`.
- Reuse themed Material primitives; add only focused private/reusable widgets.

## Validation

- SQL assertions for new tables, columns, primary/FK constraints, RLS, grants,
  policies, non-blank checks, at-least-one-contact checks, catalog entries, and
  both `security_invoker` views.
- Model JSON tests for district and all contact fields.
- Repository tests for state/city/district filtering and location options.
- View-model tests for cascading filter resets and pagination reset.
- Widget tests for card hierarchy, absence of domain on cards, table columns,
  copy actions, profile menu, removed sidebar Settings, menu placement, and
  conditional filters.
- Responsive and theme coverage at 375, 768, 1024, and 1440 logical pixels.
- Static analysis, full Flutter suite, SQL validation, web build, Supabase
  migration history, security advisor, performance advisor, and visual browser
  inspection.

## Acceptance Criteria

- Cards are visibly calmer and more breathable than the previous pass.
- Cards show `Bairro, Municipio/UF` and never show domain or contacts.
- Missing logos always fall back to readable initials.
- Table address fields are separate and all four contact/domain values can be
  copied independently.
- Municipality and district filters appear only when their parent selection is
  present.
- Filter menus open below rounded triggers and do not cover their own control.
- Header exposes bell, bug report, and profile menu; no standalone logout or
  sidebar Settings remains.
- Institution and unit contacts are modeled safely in Supabase without seed
  data or anonymous access.
