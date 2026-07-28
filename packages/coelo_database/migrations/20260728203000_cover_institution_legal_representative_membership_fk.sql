begin;

drop index if exists
  public.institution_legal_representatives_membership_idx;

create index institution_legal_representatives_membership_idx
  on public.institution_legal_representatives(
    membership_id,
    institution_id,
    person_id
  );

commit;
