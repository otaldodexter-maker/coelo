-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION app_private.superadmin_finalize_unit_identity_upload(request_id uuid, checksum text, replace_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();intent app_private.unit_identity_upload_intents%rowtype;
 metadata jsonb;previous public.unit_identity_media%rowtype;active public.unit_identity_media%rowtype;begin
 if(select auth.uid())is null or actor is null or checksum!~'^[0-9a-f]{64}$'then raise invalid_parameter_value using message='invalid identity finalization';end if;
 select*into intent from app_private.unit_identity_upload_intents i where i.request_id=superadmin_finalize_unit_identity_upload.request_id for update;
 if intent.request_id is null then raise no_data_found using message='identity upload intent not found';end if;
 if intent.actor_person_id<>actor or not app_private.has_scoped_platform_permission('units.update',intent.institution_id)or not app_private.has_mfa_aal2()
 then raise insufficient_privilege using message='units.update and AAL2 required';end if;
 if intent.consumed_at is not null then select*into active from public.unit_identity_media where id=intent.media_id;return to_jsonb(active);end if;
 if intent.expires_at<=now()then raise invalid_parameter_value using message='identity upload intent expired';end if;
 select o.metadata into metadata from storage.objects o where o.bucket_id='coelo-unit-identities'and o.name=intent.storage_path;
 if metadata is null or coalesce((metadata->>'size')::bigint,-1)<>intent.size_bytes or coalesce(metadata->>'mimetype','')<>intent.mime_type
 then raise invalid_parameter_value using message='uploaded object metadata mismatch';end if;
 if replace_id is not null then select*into previous from public.unit_identity_media m where m.id=replace_id and m.unit_id=intent.unit_id
  and m.media_kind=intent.media_kind and m.status='active'for update;
  if previous.id is null then raise invalid_parameter_value using message='replacement media is invalid';end if;
 elsif intent.media_kind in('profile','cover')then select*into previous from public.unit_identity_media m where m.unit_id=intent.unit_id
  and m.media_kind=intent.media_kind and m.status='active'order by activated_at desc nulls last limit 1 for update;end if;
 if previous.id is not null then update public.unit_identity_media set status='pending_delete',pending_delete_at=now()where id=previous.id;end if;
 update public.unit_identity_media set status='active',checksum_sha256=checksum,replaced_media_id=previous.id,activated_at=now()
 where id=intent.media_id returning*into active;
 if intent.media_kind='profile'then insert into public.unit_branding(unit_id,logo_media_asset_id,inherit_institution_branding,updated_by)
  values(intent.unit_id,intent.media_id,false,actor)on conflict(unit_id)do update set logo_media_asset_id=excluded.logo_media_asset_id,
  inherit_institution_branding=false,updated_by=actor,updated_at=now();
 elsif intent.media_kind='cover'then insert into public.unit_branding(unit_id,cover_media_asset_id,inherit_institution_branding,updated_by)
  values(intent.unit_id,intent.media_id,false,actor)on conflict(unit_id)do update set cover_media_asset_id=excluded.cover_media_asset_id,
  inherit_institution_branding=false,updated_by=actor,updated_at=now();end if;
 update app_private.unit_identity_upload_intents upload_intent set consumed_at=now()where upload_intent.request_id=intent.request_id;
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
 values(actor,auth.jwt()->>'aal','unit.identity.upload.finalize','unit_identity_media',active.id,active.institution_id,'success',
 case when previous.id is null then null else to_jsonb(previous)end,to_jsonb(active));
 return to_jsonb(active)||jsonb_build_object('cleanup_media_id',previous.id,'cleanup_path',previous.storage_path);end$function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_confirm_unit_identity_delete(media_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare actor uuid:=app_private.current_person_id();media public.unit_identity_media%rowtype;begin
 select*into media from public.unit_identity_media m where m.id=media_id for update;if media.id is null then raise no_data_found using message='unit identity media not found';end if;
 if(select auth.uid())is null or actor is null or not app_private.has_scoped_platform_permission('units.update',media.institution_id)or not app_private.has_mfa_aal2()
 then raise insufficient_privilege using message='units.update and AAL2 required';end if;if media.status='deleted'then return to_jsonb(media);end if;
 if media.status<>'pending_delete'then raise invalid_parameter_value using message='unit identity deletion was not requested';end if;
 if exists(select 1 from storage.objects o where o.bucket_id=media.storage_bucket and o.name=media.storage_path)
 then raise check_violation using message='object still exists';end if;
 update public.unit_identity_media set status='deleted',deleted_at=now()where id=media.id returning*into media;
 update app_private.unit_identity_delete_requests delete_request set confirmed_at=now()where delete_request.media_id=media.id and delete_request.confirmed_at is null;
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
 values(actor,auth.jwt()->>'aal','unit.identity.delete.confirm','unit_identity_media',media.id,media.institution_id,'success',to_jsonb(media));return to_jsonb(media);end$function$;

