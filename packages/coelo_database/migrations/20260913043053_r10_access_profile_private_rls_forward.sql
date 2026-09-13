-- R10: historical candidate reviewed by content; current production flags are false.
-- Forward-only application, no new grants/policies/owners.
ALTER TABLE app_private.access_profile_catalog_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_catalog_versions FORCE ROW LEVEL SECURITY;

ALTER TABLE app_private.access_profile_command_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_command_receipts FORCE ROW LEVEL SECURITY;

ALTER TABLE app_private.access_profile_command_receipts_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_command_receipts_v2 FORCE ROW LEVEL SECURITY;
