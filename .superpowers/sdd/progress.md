# Superadmin Support Prototype

Baseline: branch `codex/superadmin-support-prototype`; focused reused-component and shell/router tests passing.

Task 1: complete (commits 4b17526..ed14784, review clean).

Task 2: complete in working tree (modal, protected routes, active navigation, shared session controller).

Task 3: complete in working tree (responsive Kanban/table/detail, approved popup and hover rules, 24 goldens).

Final verification: focused analysis clean; 61 relevant tests passed; UI index, package-boundary, and catalog-sync validators passed; localhost 8769 visually inspected.

# Coelo UI Surface Interaction Contracts

Task 1: complete (commits 84929e2..84169be, review clean).
Task 2: complete (commits 84169be..f7cba44, review clean).
Task 3: complete in working tree (isolated snapshot review clean; index overlap preserved).
Task 6: complete (commit f7cba44..a53acc3; table RED/GREEN and documentary contract test passing).
Task 5: complete (commit 1a646cf..5d1aa4f, review clean; external Task 4 analyzer warning recorded separately).

# Support Operations Redesign

Plan: `docs/superpowers/plans/2026-07-27-support-operations-redesign.md`
Execution: subagent-driven in the current checkout, explicitly approved by the user.
Task 1: complete (commits a7d061f..bc9f082, review clean; 15 focused tests passed).
Task 2: complete (commits bc9f082..ac178a5, review clean; 24 focused tests and focused analysis passed).
Task 3: complete (commits 3288a4a and cc0022c, review clean; 6 focused and 33 package tests passed; concurrent commit 0abeece excluded from review).
Task 4: complete (creation partly captured by concurrent checkpoint aaabbcf, final commit ceb345e; review approved with Minor coverage note for SupportAssigneeView; golden interaction deferred explicitly to Task 7; 4 focused tests and focused analysis passed).
Task 5: complete (commits 9538281, 817dcb6 and ecef8b6; review clean; 37 controller/page tests and focused analysis passed; goldens deferred to Task 7).

# Shared Admin Operational Foundation

Decision: implement code and visual preview first; update catalog, design system, specs and coelo-ui skill only after user visual approval.
Consumers: Admin and Superadmin.

# Superadmin Screen Corrections

Task 1 Home: complete (commits d42e89b..0abc0f4, review clean; 11 focused tests and focused analysis passed before an unrelated concurrent Activity Center compile break; golden baselines intentionally pending visual approval).
Task 2 Institutions listing: complete (commits 0abc0f4..001bbbb, review clean; 62 shared-package tests and 27 independent institution tests passed; integrated page test pending resolution of unrelated concurrent shell compile work).
Task 3A Institution profile form: complete (commits 001bbbb..360d764, review clean; enriched local branding/profile/address/contact/trial/edit-save flow, ViaCEP/IBGE hardening, focused widget/service tests and analysis passed; visual candidates remain pending integrated approval).
Task 3B Institution people workflow: complete (commits 360d764..2f75038, review clean; multiple legal representatives, explicit Admin Master confirmation, local invitation lifecycle/history and responsive validation; 43 baseline controller/page tests plus focused review regressions passed).
Task 3C Institution Supabase schema: complete (migrations 20260728172333 and 20260728203000 applied to project coelo; functional SQL passed with rollback, pgTAP 21/21 passed, RLS/cross-tenant checks passed, and the migration-related unindexed FK advisor finding was remediated).
Task 4 Support corrections: complete (equivalent multi-assignees, in-progress guard, create actions in Kanban/table, neutral shared Kanban, explicit full-screen detail, enriched local history, sortable pagination 9/20/50/100, and page clamping after filtered mutations; focused tests and analysis passed).
Task 5 Persistent menu and motion: complete (one protected shell host, short content fade, reduced-motion bypass, stable geometry, distinct parent/child hierarchy, Units active, Activities future destination, distinct communication icons, centralized Support/Catalog routing, and protected `/dev/support`; focused tests and analysis passed).

# Superadmin Profile and Settings Refinement

Plan: `docs/superpowers/plans/2026-07-28-superadmin-profile-settings-refinement.md`
Task 1: complete (commits bfeeeee..814fec3, review clean; 14 domain/controller tests plus failure-retry coverage and focused analysis passed).
Task 2: complete (commits 814fec3..50b73f8, review clean; shared advanced color picker, Institutions/Units integration, 3 focused tests and analysis passed).
Task 3: complete (commits 50b73f8..51921fb, review clean; phone field, draft reset, aligned responsive layout, 200% text fix, 6 focused tests and analysis passed). Minor: update Task 3 report commit reference from 45ae56e to 51921fb during final bookkeeping. Cross-task: update account goldens in Task 5.
Task 4: complete (commits 51921fb..099c1fa, review clean; canonical password close, neutral accessibility row, wide 50/50 actions, compact/200% stacked actions, 10 focused tests and analysis passed).
Task 5: complete (commit c6623f7, review approved; 34 account tests, 8 golden cases, full analysis and knowledge validators passed; unrelated pre-existing Institutions test failure at institution_form_page_test.dart:812 remains documented).
Final review fixes: complete (commits f2ef952, fb7cccb and a9e1ad4, re-review approved; recoverable save errors, accessible SV/hue controls with visible focus, keyboard and semantics, and delayed profile hydration without draft loss; 88 relevant tests and full analysis passed).
