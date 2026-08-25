-- Keep the assessment normalizer internal to authorized tracking RPCs.
revoke execute on function public.student_tracking_normalize_assessment(
  text,
  jsonb,
  numeric,
  boolean,
  text
) from public, anon, authenticated;
