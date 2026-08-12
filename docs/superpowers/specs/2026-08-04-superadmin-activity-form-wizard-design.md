---
source: approved user plan for Superadmin Activities UI
status: approved
generated_at: 2026-08-04
---

# Superadmin Activity Form Wizard

Create and Edit Activity use a responsive four-step production flow: Identity,
Structure and locations, Links, and Professionals and review. Draft save and
completion are typed, idempotent, audited backend commands authorized by
server-side capabilities; no enabled action is callback-only or a no-op.

Draft save requires name, institution, and at least one unit; completion also
requires at least one class. Internal locations belong to a selected unit and
are persisted transactionally. Professional assignments belong to activity
plus class; Happens, Now, Moments, Chat, and Attendance use normalized
permissions, while authorization is recalculated from the institutional
hierarchy. Editing keeps institution fixed and preserves legacy `Fixa`
governance as read-only.

## Approved production amendment - 2026-08-11

The presentation baseline remains approved. Create, draft save, update, submit,
location creation, identity upload, links, import and export use typed,
idempotent and audited backend commands.
Access is granted by platform capabilities and recalculated server-side; Owner has
all Activity capabilities and Operations manages taxonomy.

Activity identity does not inherit institution branding. It supports a private
Supabase Storage photo, initials plus approved color picker, or an allowlisted
Material icon. Editorial media for Now, Happens and Moments remains in R2.

The form separates student and professional links. Locations belong to one unit;
applying a location to multiple units creates sibling records transactionally.
New governance values are Optional and Mandatory, while unknown/legacy values are
preserved without silently coercing them.

Professional lookup is currently productive by display name and private `@`,
always constrained to active adult memberships in the selected institution and
authorized by `activities.assign_people` with MFA. CPF, email and mobile lookup
remain blocked by OQ-038: the identity schema has protected digests but no
approved server-side keyed lookup contract. Those inputs fail closed with
SQLSTATE `0A000`; the UI must not present them as available until Identity owns
and approves that command.

The initial catalog contains 40 versioned models distributed across filterable
categories. It includes the original 21 plus Coral, Fotografia, Cerâmica,
Futebol, Basquete, Vôlei, Handebol, Atletismo, Ginástica, Francês, Libras,
Matemática, Física, Química, Biologia, Astronomia, Cultura maker,
Alfabetização and Educação financeira. The catalog therefore covers sports,
arts, languages, exact and natural sciences, technology, pedagogical support,
well-being, sustainability, practical life and socioemotional development.

Starting from a model is one atomic `superadmin_upsert_activity` mutation:
the server validates the model and institution, applies versioned defaults,
merges explicit form overrides, persists immutable model provenance, and writes
the audit trail in the same transaction. A retry with the same key returns the
same result and cannot leave an orphan draft. Duplicating the model itself is a
separate command that creates an institution-scoped model copy; it must not
create an Activity.

Loading, empty options, validation failure, authorization failure, conflict and
backend failure remain honest states. The form never injects local catalogs,
fixtures or synthetic success when a relation is empty or unavailable.
