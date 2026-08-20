CREATE INDEX IF NOT EXISTS meal_plan_image_delete_requests_actor_person_idx
  ON app_private.meal_plan_image_delete_requests (actor_person_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_upload_intents_actor_person_idx
  ON app_private.meal_plan_image_upload_intents (actor_person_id);

CREATE INDEX IF NOT EXISTS meal_plan_audience_snapshots_person_fk_idx
  ON public.meal_plan_audience_snapshots (person_id);

CREATE INDEX IF NOT EXISTS meal_plan_audience_snapshots_plan_tenant_fk_idx
  ON public.meal_plan_audience_snapshots (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_audiences_activity_fk_idx
  ON public.meal_plan_audiences (activity_id);

CREATE INDEX IF NOT EXISTS meal_plan_audiences_class_fk_idx
  ON public.meal_plan_audiences (class_id);

CREATE INDEX IF NOT EXISTS meal_plan_audiences_institution_fk_idx
  ON public.meal_plan_audiences (institution_id);

CREATE INDEX IF NOT EXISTS meal_plan_audiences_plan_tenant_fk_idx
  ON public.meal_plan_audiences (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_audiences_unit_fk_idx
  ON public.meal_plan_audiences (unit_id);

CREATE INDEX IF NOT EXISTS meal_plan_availability_plan_tenant_fk_idx
  ON public.meal_plan_availability (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_created_by_fk_idx
  ON public.meal_plan_image_assets (created_by);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_institution_fk_idx
  ON public.meal_plan_image_assets (institution_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_meal_tenant_fk_idx
  ON public.meal_plan_image_assets (meal_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_item_tenant_fk_idx
  ON public.meal_plan_image_assets (meal_item_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_plan_tenant_fk_idx
  ON public.meal_plan_image_assets (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_replaced_asset_fk_idx
  ON public.meal_plan_image_assets (replaced_asset_id);

CREATE INDEX IF NOT EXISTS meal_plan_image_assets_template_tenant_fk_idx
  ON public.meal_plan_image_assets (template_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_meal_items_meal_tenant_fk_idx
  ON public.meal_plan_meal_items (meal_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_meals_plan_tenant_fk_idx
  ON public.meal_plan_meals (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_scopes_class_fk_idx
  ON public.meal_plan_scopes (class_id);

CREATE INDEX IF NOT EXISTS meal_plan_scopes_institution_fk_idx
  ON public.meal_plan_scopes (institution_id);

CREATE INDEX IF NOT EXISTS meal_plan_scopes_person_fk_idx
  ON public.meal_plan_scopes (person_id);

CREATE INDEX IF NOT EXISTS meal_plan_scopes_plan_tenant_fk_idx
  ON public.meal_plan_scopes (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_scopes_unit_fk_idx
  ON public.meal_plan_scopes (unit_id);

CREATE INDEX IF NOT EXISTS meal_plan_template_links_created_by_fk_idx
  ON public.meal_plan_template_links (created_by);

CREATE INDEX IF NOT EXISTS meal_plan_template_links_plan_tenant_fk_idx
  ON public.meal_plan_template_links (meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_template_links_version_fk_idx
  ON public.meal_plan_template_links (template_id, tenant_id, template_version);

CREATE INDEX IF NOT EXISTS meal_plan_template_versions_created_by_fk_idx
  ON public.meal_plan_template_versions (created_by);

CREATE INDEX IF NOT EXISTS meal_plan_templates_created_by_fk_idx
  ON public.meal_plan_templates (created_by);

CREATE INDEX IF NOT EXISTS meal_plan_templates_institution_fk_idx
  ON public.meal_plan_templates (institution_id);

CREATE INDEX IF NOT EXISTS meal_plan_templates_source_plan_tenant_fk_idx
  ON public.meal_plan_templates (source_meal_plan_id, tenant_id);

CREATE INDEX IF NOT EXISTS meal_plan_templates_updated_by_fk_idx
  ON public.meal_plan_templates (updated_by);

CREATE INDEX IF NOT EXISTS meal_plans_class_fk_idx
  ON public.meal_plans (class_id);

CREATE INDEX IF NOT EXISTS meal_plans_created_by_fk_idx
  ON public.meal_plans (created_by);

CREATE INDEX IF NOT EXISTS meal_plans_inheritance_origin_fk_idx
  ON public.meal_plans (inheritance_origin_id);

CREATE INDEX IF NOT EXISTS meal_plans_institution_fk_idx
  ON public.meal_plans (institution_id);

CREATE INDEX IF NOT EXISTS meal_plans_person_fk_idx
  ON public.meal_plans (person_id);

CREATE INDEX IF NOT EXISTS meal_plans_source_template_fk_idx
  ON public.meal_plans (source_template_id, tenant_id, source_template_version);

CREATE INDEX IF NOT EXISTS meal_plans_unit_fk_idx
  ON public.meal_plans (unit_id);

CREATE INDEX IF NOT EXISTS meal_plans_updated_by_fk_idx
  ON public.meal_plans (updated_by);
