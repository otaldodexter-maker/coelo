create index if not exists agenda_events_updated_by_idx
  on public.agenda_events(updated_by_person_id);
create index if not exists agenda_publication_requests_requested_by_idx
  on public.agenda_publication_requests(requested_by_person_id);
create index if not exists agenda_publication_requests_decided_by_idx
  on public.agenda_publication_requests(decided_by_person_id)
  where decided_by_person_id is not null;
create index if not exists agenda_guardian_requests_decided_by_idx
  on public.agenda_guardian_requests(decided_by_person_id)
  where decided_by_person_id is not null;
create index if not exists agenda_guardian_requests_linked_event_idx
  on public.agenda_guardian_requests(linked_event_id)
  where linked_event_id is not null;
create index if not exists agenda_responses_institution_idx
  on public.agenda_responses(institution_id);
create index if not exists agenda_history_institution_idx
  on public.agenda_history_receipts(institution_id);
