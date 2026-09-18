---
source:
  - user-approved design in Codex conversation on 2026-07-27
  - docs/superpowers/specs/2026-07-17-superadmin-institution-directory-visual-refactor-design.md
  - specs/013-ui-packages-componentization.md
  - docs/design/design-system.md
status: approved
generated_at: 2026-07-27
---

# Coelo Admin Numbered Pagination

## Objective

Evolve the shared administrative pagination and apply it to both views of the
Superadmin institution directory. The directory must load 10 institutions by
default, offer page sizes of 10, 50, 100, and 500, and provide direct numbered
page navigation with adaptive ellipses.

## Scope

- Evolve the public `CoeloAdminPagination` component in `coelo_ui_admin`.
- Add direct page selection and a page-size selector.
- Make the institution directory query page size dynamic.
- Apply the same pagination state to Cards and Table.
- Keep pagination server-side for the Supabase and fake repositories.
- Update the Coelo UI index, catalog example, tests, and visual references.

## Out Of Scope

- An unrestricted `Todas` option.
- Cursor-based pagination.
- Persisting the selected page size between sessions.
- Changing institution filters, sorting, card content, or table columns.
- Applying the new component to unrelated screens in this change.

## Approved Behavior

The initial page size is 10 institutions. The selector offers exactly 10, 50,
100, and 500. Changing the page size resets the current page to the first page
before loading again. The maximum supported page size is 500.

The Cards and Table views share the query and loaded page. Switching display
mode preserves the selected page, page size, search, and filters. The
`Criar instituição` affordance is presentation-only and is not included in the
institution count or page size.

The footer remains visible for a successful non-empty result even when there is
only one page, so the page-size selector remains available. Empty, no-results,
failure, and unauthorized states do not show pagination.

## Pagination Composition

The expanded footer contains:

- a labeled page-size selector;
- previous-page control;
- numbered page controls;
- adaptive ellipses for omitted ranges;
- next-page control.

The numbered sequence always includes the first and last pages and favors the
current page with adjacent context. Omitted consecutive ranges become a single
non-interactive ellipsis. Examples include `1 2 3 … 7 8 … 20` when the active
region and total allow it; the exact visible set may contract responsively
without hiding the current, first, or last page.

Previous and next controls are disabled at their respective boundaries.
Selecting the current page performs no new request. During a load, the current
content may remain visible with the existing progress indicator, and pagination
must not issue duplicate requests from disabled or current controls.

## Responsive Behavior

The component uses available constraints rather than device detection.
Expanded layouts keep the selector and navigation in one footer row when space
allows. Narrow layouts wrap into readable runs without introducing page-level
horizontal scrolling. Touch targets remain at least 48 logical pixels where
interactive.

Both Cards and Table place the footer directly below their result surface with
the existing Coelo spacing tokens. The table's own horizontal scrolling does
not move or clip the footer.

## Accessibility And Visual Rules

- Use Coelo semantic colors, spacing, radius, typography, and Material states;
  do not add local HEX colors or speculative tokens.
- Expose the selected page with selected semantics and an accessible label such
  as `Página 7, selecionada`.
- Give every direct page control an accessible label such as `Ir para a página
  8`.
- Keep previous, next, and page-size labels available to assistive technology.
- Preserve visible keyboard focus and support activation with Enter and Space.
- Ellipses are text, not buttons, and do not receive focus.
- Do not rely on color alone to communicate the selected page.
- Validate light and dark themes and widths 375, 768, 1024, and 1440.

## Architecture And Public API

`CoeloAdminPagination` remains a domain-neutral, stateless public widget owned
by `coelo_ui_admin`. Its public inputs describe pagination state and callbacks:
current page, total pages, selected page size, allowed page sizes, direct page
selection, page-size change, previous, and next. Internal focus management may
remain stateful behind the public stateless boundary.

The institution feature owns domain behavior through
`InstitutionDirectoryQuery` and `InstitutionDirectoryViewModel`. The query
stores `pageSize`, defaults it to 10, validates the allowed range, and derives
its offset from `page * pageSize`. Repositories consume the query value rather
than a static constant. The view model exposes page-size selection and resets
the page index to zero when it changes.

No new dependency, route, permission, database schema, or token is introduced.

## Error And Boundary Handling

- Public pagination assertions reject non-positive pages, totals, and sizes,
  a current page beyond the total, or a selected size absent from the options.
- The feature accepts only the approved sizes 10, 50, 100, and 500.
- A page-size change that results in fewer pages resets to page one before the
  repository request, avoiding an out-of-range intermediate page.
- Existing safe loading, retry, failure, unauthorized, empty, and no-results
  behavior remains unchanged.

## Tests And Documentation

- Unit tests cover query equality, offset, default size, and each approved size.
- View-model tests cover direct navigation, page-size change, reset to page one,
  and preservation across display-mode changes.
- Repository tests verify server ranges for 10, 50, 100, and 500.
- `coelo_ui_admin` widget tests cover compact and expanded sequences, ellipses,
  direct selection, disabled boundaries, page-size callbacks, keyboard, focus,
  and semantics.
- Institution page tests cover the shared footer in Cards and Table, the
  presentation-only create card, and footer visibility with one page.
- Goldens cover light and dark themes at the established responsive widths.
- The component catalog and `admin.pagination` index entry document the new
  approved API and states.

## Acceptance Criteria

- Institution Cards and Table initially show no more than 10 institutions.
- The footer offers exactly 10, 50, 100, and 500 institutions per page.
- Direct numbered navigation and adaptive ellipses work at all supported widths.
- Page-size changes return to page one and load the selected server-side range.
- Switching Cards/Table preserves pagination state.
- The shared component is reusable without institution-domain imports.
- Focus, keyboard, semantics, light/dark, responsive tests, static analysis, and
  focused suites pass without overwriting unrelated user changes.
