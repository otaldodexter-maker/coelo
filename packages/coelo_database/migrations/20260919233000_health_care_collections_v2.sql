-- Perfis de cuidado — spec 065 (coleções redesenhadas). Lote 93.
--   * public.health_care_catalog_items: catálogo read-only (food | restriction | guidance)
--     com categoria, rótulo, termos de busca e ordem; RLS deny, leitura só pela RPC.
--   * health_care_allergies: catalog_item_id, other_text (obrigatório só com 'other'),
--     position (ordem persistida) e what_to_do ("o que fazer se consumido/exposto").
--     label passa a derivar do catálogo (ou do other_text) quando o item vem informado.
--   * health_care_profile_items: position; unicidade por item só fora de 'other'.
--   * superadmin_health_care_catalog_v1(p_collection, p_search): categorias e itens
--     (busca ≥ 2 caracteres, ≤ 50 itens), sem PII.
--   * superadmin_health_care_save_profile: allergies/items com lista ORDENADA
--     (position = índice), valida catálogo e other_text; alergias ativas ausentes da
--     lista são inativadas com a justificativa da revisão. Limite 100 (trigger do lote
--     63) e PT409 preservados.
--   * superadmin_health_care_profile_detail: coleções na ordem persistida.
begin;

create table if not exists public.health_care_catalog_items (
  id text primary key,
  collection text not null check (collection in ('food', 'restriction', 'guidance')),
  category_code text not null,
  category_label text not null,
  label text not null check (btrim(label) <> ''),
  search_terms text[] not null default '{}',
  sort_order integer not null default 0,
  status text not null default 'active' check (status in ('active', 'inactive'))
);
alter table public.health_care_catalog_items enable row level security;
alter table public.health_care_catalog_items force row level security;
revoke all on public.health_care_catalog_items from public, anon, authenticated;
create index if not exists health_care_catalog_items_collection_idx
  on public.health_care_catalog_items(collection, sort_order, id);

insert into public.health_care_catalog_items(id, collection, category_code, category_label, label, search_terms, sort_order)
values
  -- Alimentos ----------------------------------------------------------------------------------
  ('food_milk','food','dairy','Leite e derivados','Leite de vaca','{leite,lactose,laticinio,apl}',10),
  ('food_cheese','food','dairy','Leite e derivados','Queijo','{queijo,laticinio}',11),
  ('food_yogurt','food','dairy','Leite e derivados','Iogurte','{iogurte,laticinio}',12),
  ('food_butter','food','dairy','Leite e derivados','Manteiga','{manteiga,laticinio}',13),
  ('food_egg','food','egg','Ovos','Ovo','{ovo,clara,gema}',20),
  ('food_wheat','food','grain','Cereais e glúten','Trigo','{trigo,gluten,farinha,pao}',30),
  ('food_gluten','food','grain','Cereais e glúten','Glúten','{gluten,cevada,centeio,celiaco}',31),
  ('food_oat','food','grain','Cereais e glúten','Aveia','{aveia}',32),
  ('food_corn','food','grain','Cereais e glúten','Milho','{milho,fuba,pipoca}',33),
  ('food_soy','food','legume','Leguminosas','Soja','{soja,tofu}',40),
  ('food_peanut','food','legume','Leguminosas','Amendoim','{amendoim,pacoca}',41),
  ('food_bean','food','legume','Leguminosas','Feijão','{feijao}',42),
  ('food_lentil','food','legume','Leguminosas','Lentilha','{lentilha}',43),
  ('food_chickpea','food','legume','Leguminosas','Grão-de-bico','{grao de bico,homus}',44),
  ('food_walnut','food','nut','Oleaginosas','Nozes','{nozes,noz}',50),
  ('food_cashew','food','nut','Oleaginosas','Castanha-de-caju','{castanha,caju}',51),
  ('food_brazil_nut','food','nut','Oleaginosas','Castanha-do-pará','{castanha,para}',52),
  ('food_almond','food','nut','Oleaginosas','Amêndoa','{amendoa}',53),
  ('food_hazelnut','food','nut','Oleaginosas','Avelã','{avela,nutella}',54),
  ('food_pistachio','food','nut','Oleaginosas','Pistache','{pistache}',55),
  ('food_sesame','food','seed','Sementes','Gergelim','{gergelim,tahine}',60),
  ('food_sunflower','food','seed','Sementes','Semente de girassol','{girassol}',61),
  ('food_chia','food','seed','Sementes','Chia','{chia}',62),
  ('food_fish','food','seafood','Peixes e frutos do mar','Peixe','{peixe,tilapia,salmao,atum}',70),
  ('food_shrimp','food','seafood','Peixes e frutos do mar','Camarão','{camarao,crustaceo}',71),
  ('food_crab','food','seafood','Peixes e frutos do mar','Caranguejo e siri','{caranguejo,siri,crustaceo}',72),
  ('food_shellfish','food','seafood','Peixes e frutos do mar','Moluscos','{molusco,lula,polvo,marisco,ostra}',73),
  ('food_beef','food','meat','Carnes','Carne bovina','{carne,boi,bovina}',80),
  ('food_pork','food','meat','Carnes','Carne suína','{porco,suina,presunto,bacon}',81),
  ('food_chicken','food','meat','Carnes','Frango','{frango,ave}',82),
  ('food_banana','food','fruit','Frutas','Banana','{banana}',90),
  ('food_apple','food','fruit','Frutas','Maçã','{maca}',91),
  ('food_strawberry','food','fruit','Frutas','Morango','{morango}',92),
  ('food_kiwi','food','fruit','Frutas','Kiwi','{kiwi}',93),
  ('food_mango','food','fruit','Frutas','Manga','{manga}',94),
  ('food_pineapple','food','fruit','Frutas','Abacaxi','{abacaxi}',95),
  ('food_citrus','food','fruit','Frutas','Cítricos (laranja, limão)','{laranja,limao,citrico,tangerina}',96),
  ('food_peach','food','fruit','Frutas','Pêssego','{pessego}',97),
  ('food_avocado','food','fruit','Frutas','Abacate','{abacate}',98),
  ('food_melon','food','fruit','Frutas','Melão e melancia','{melao,melancia}',99),
  ('food_tomato','food','vegetable','Legumes e verduras','Tomate','{tomate}',110),
  ('food_carrot','food','vegetable','Legumes e verduras','Cenoura','{cenoura}',111),
  ('food_potato','food','vegetable','Legumes e verduras','Batata','{batata}',112),
  ('food_celery','food','vegetable','Legumes e verduras','Aipo (salsão)','{aipo,salsao}',113),
  ('food_pepper','food','vegetable','Legumes e verduras','Pimentão','{pimentao}',114),
  ('food_cocoa','food','sweet','Doces e aditivos','Chocolate e cacau','{chocolate,cacau}',120),
  ('food_honey','food','sweet','Doces e aditivos','Mel','{mel}',121),
  ('food_sugar','food','sweet','Doces e aditivos','Açúcar','{acucar,doce}',122),
  ('food_food_dye','food','sweet','Doces e aditivos','Corantes artificiais','{corante,tartrazina}',123),
  ('food_sulfite','food','sweet','Doces e aditivos','Sulfitos','{sulfito,conservante}',124),
  ('food_msg','food','sweet','Doces e aditivos','Glutamato monossódico','{glutamato,msg}',125),
  ('food_soda','food','drink','Bebidas','Refrigerante','{refrigerante}',130),
  ('food_juice_industrial','food','drink','Bebidas','Suco industrializado','{suco,caixinha}',131),
  ('food_coffee','food','drink','Bebidas','Café e cafeína','{cafe,cafeina}',132),
  ('food_coconut','food','other','Outros alimentos','Coco','{coco}',140),
  ('food_mustard','food','other','Outros alimentos','Mostarda','{mostarda}',141),
  ('food_lupin','food','other','Outros alimentos','Tremoço','{tremoco}',142),
  -- Restrições ---------------------------------------------------------------------------------
  ('restriction_latex','restriction','contact','Contato e ambiente','Látex','{latex,luva,balao,bexiga}',10),
  ('restriction_insect','restriction','contact','Contato e ambiente','Picada de inseto','{abelha,vespa,formiga,inseto,picada}',11),
  ('restriction_dust','restriction','contact','Contato e ambiente','Poeira e ácaros','{poeira,acaro,rinite}',12),
  ('restriction_pet','restriction','contact','Contato e ambiente','Pelos de animais','{pelo,gato,cachorro,animal}',13),
  ('restriction_pollen','restriction','contact','Contato e ambiente','Pólen','{polen,flor}',14),
  ('restriction_mold','restriction','contact','Contato e ambiente','Mofo','{mofo,fungo,umidade}',15),
  ('restriction_perfume','restriction','contact','Contato e ambiente','Perfumes e produtos de limpeza','{perfume,cheiro,produto,limpeza}',16),
  ('restriction_sun','restriction','contact','Contato e ambiente','Exposição ao sol','{sol,fotossensibilidade}',17),
  ('restriction_cold','restriction','contact','Contato e ambiente','Frio intenso','{frio,urticaria}',18),
  ('restriction_paint','restriction','contact','Contato e ambiente','Tinta e cola','{tinta,cola,guache}',19),
  ('restriction_dipyrone','restriction','medication','Medicamentos','Dipirona','{dipirona,novalgina}',30),
  ('restriction_penicillin','restriction','medication','Medicamentos','Penicilina e amoxicilina','{penicilina,amoxicilina,antibiotico}',31),
  ('restriction_ibuprofen','restriction','medication','Medicamentos','Ibuprofeno','{ibuprofeno,alivium,anti-inflamatorio}',32),
  ('restriction_aspirin','restriction','medication','Medicamentos','AAS (aspirina)','{aas,aspirina}',33),
  ('restriction_paracetamol','restriction','medication','Medicamentos','Paracetamol','{paracetamol,tylenol}',34),
  ('restriction_sulfa','restriction','medication','Medicamentos','Sulfa','{sulfa,bactrim}',35),
  ('restriction_iodine','restriction','medication','Medicamentos','Iodo e contraste','{iodo,contraste}',36),
  ('restriction_no_sugar','restriction','diet','Dieta por regra','Sem açúcar','{acucar,diabetes,dieta}',50),
  ('restriction_no_lactose','restriction','diet','Dieta por regra','Sem lactose','{lactose,intolerancia}',51),
  ('restriction_no_gluten','restriction','diet','Dieta por regra','Sem glúten','{gluten,celiaco}',52),
  ('restriction_vegetarian','restriction','diet','Dieta por regra','Vegetariana','{vegetariano}',53),
  ('restriction_vegan','restriction','diet','Dieta por regra','Vegana','{vegano}',54),
  ('restriction_halal','restriction','diet','Dieta por regra','Halal','{halal}',55),
  ('restriction_kosher','restriction','diet','Dieta por regra','Kosher','{kosher}',56),
  ('restriction_no_pork','restriction','diet','Dieta por regra','Sem carne suína','{porco,suina}',57),
  ('restriction_low_sodium','restriction','diet','Dieta por regra','Pouco sal','{sal,sodio}',58),
  ('restriction_pasty','restriction','diet','Dieta por regra','Textura pastosa','{pastosa,disfagia,textura}',59),
  ('restriction_physical','restriction','activity','Atividade física','Esforço físico limitado','{esforco,fisico,educacao fisica}',70),
  ('restriction_water','restriction','activity','Atividade física','Sem atividade aquática','{piscina,agua,natacao}',71),
  ('restriction_height','restriction','activity','Atividade física','Sem altura (brinquedos altos)','{altura,brinquedo}',72),
  ('restriction_screen','restriction','activity','Atividade física','Tempo de tela limitado','{tela,tablet}',73),
  -- Orientações de cuidado ---------------------------------------------------------------------
  ('guidance_asd','guidance','neurodevelopment','Neurodesenvolvimento','Transtorno do espectro autista (TEA)','{tea,autismo,autista}',10),
  ('guidance_adhd','guidance','neurodevelopment','Neurodesenvolvimento','TDAH','{tdah,atencao,hiperatividade}',11),
  ('guidance_dyslexia','guidance','neurodevelopment','Neurodesenvolvimento','Dislexia','{dislexia,leitura}',12),
  ('guidance_intellectual','guidance','neurodevelopment','Neurodesenvolvimento','Deficiência intelectual','{intelectual,cognitivo}',13),
  ('guidance_down','guidance','neurodevelopment','Neurodesenvolvimento','Síndrome de Down','{down,trissomia}',14),
  ('guidance_speech','guidance','communication','Comunicação','Atraso de fala e linguagem','{fala,linguagem,fono}',20),
  ('guidance_hearing','guidance','communication','Comunicação','Deficiência auditiva','{auditiva,surdez,libras,aparelho}',21),
  ('guidance_visual','guidance','communication','Comunicação','Deficiência visual','{visual,baixa visao,cegueira,oculos}',22),
  ('guidance_aac','guidance','communication','Comunicação','Usa comunicação alternativa (CAA)','{caa,pecs,prancha}',23),
  ('guidance_mobility','guidance','mobility','Mobilidade','Mobilidade reduzida','{mobilidade,cadeira de rodas,andador}',30),
  ('guidance_cerebral_palsy','guidance','mobility','Mobilidade','Paralisia cerebral','{paralisia,pc}',31),
  ('guidance_prosthesis','guidance','mobility','Mobilidade','Usa prótese ou órtese','{protese,ortese}',32),
  ('guidance_sensory','guidance','sensory','Sensorial e regulação','Sensibilidade sensorial (som, luz, toque)','{sensorial,barulho,luz,toque}',40),
  ('guidance_routine','guidance','sensory','Sensorial e regulação','Precisa de rotina previsível','{rotina,previsivel,antecipacao}',41),
  ('guidance_calm_space','guidance','sensory','Sensorial e regulação','Precisa de espaço de calma','{calma,crise,regulacao}',42),
  ('guidance_asthma','guidance','chronic','Saúde crônica','Asma','{asma,bombinha,falta de ar}',50),
  ('guidance_diabetes','guidance','chronic','Saúde crônica','Diabetes','{diabetes,glicemia,insulina}',51),
  ('guidance_epilepsy','guidance','chronic','Saúde crônica','Epilepsia','{epilepsia,convulsao,crise}',52),
  ('guidance_heart','guidance','chronic','Saúde crônica','Cardiopatia','{cardiopatia,coracao}',53),
  ('guidance_anaphylaxis','guidance','chronic','Saúde crônica','Risco de anafilaxia (adrenalina)','{anafilaxia,adrenalina,epipen}',54),
  ('guidance_sickle','guidance','chronic','Saúde crônica','Anemia falciforme','{falciforme,anemia}',55),
  ('guidance_gastrostomy','guidance','chronic','Saúde crônica','Sonda ou gastrostomia','{sonda,gastrostomia}',56),
  ('guidance_toilet','guidance','daily','Rotina diária','Apoio no uso do banheiro','{banheiro,fralda,desfralde}',60),
  ('guidance_feeding','guidance','daily','Rotina diária','Apoio na alimentação','{alimentacao,comer,ajuda}',61),
  ('guidance_sleep','guidance','daily','Rotina diária','Rotina de sono específica','{sono,soneca}',62),
  ('guidance_medication','guidance','daily','Rotina diária','Medicação em horário na instituição','{medicacao,remedio,horario}',63)
on conflict (id) do update set
  collection = excluded.collection, category_code = excluded.category_code,
  category_label = excluded.category_label, label = excluded.label,
  search_terms = excluded.search_terms, sort_order = excluded.sort_order;

-- "Outro" não é linha do catálogo: é o id virtual 'other' (exige other_text),
-- devolvido pela RPC em cada coleção.

alter table public.health_care_allergies
  add column if not exists catalog_item_id text,
  add column if not exists other_text text,
  add column if not exists position integer not null default 0,
  add column if not exists what_to_do text not null default '';
alter table public.health_care_allergies
  drop constraint if exists health_care_allergies_other_text_check,
  add constraint health_care_allergies_other_text_check check (
    catalog_item_id is distinct from 'other' or btrim(coalesce(other_text, '')) <> '');
alter table public.health_care_profile_items
  add column if not exists position integer not null default 0;
-- Várias linhas "Outro" (texto livre) na mesma coleção são legítimas; o item de
-- catálogo continua único por perfil.
alter table public.health_care_profile_items
  drop constraint if exists health_care_profile_items_profile_id_catalog_item_id_key;
create unique index if not exists health_care_profile_items_profile_catalog_uidx
  on public.health_care_profile_items(profile_id, catalog_item_id) where catalog_item_id <> 'other';

-- Rótulo derivado do catálogo (ou do other_text). Sem item, mantém o rótulo enviado.
create or replace function app_private.health_care_catalog_label(
  p_collection text, p_catalog_item_id text, p_other_text text, p_fallback text
) returns text language sql stable security definer set search_path = '' as $$
  select case
    when p_catalog_item_id is null then btrim(coalesce(p_fallback, ''))
    when p_catalog_item_id = 'other' then btrim(coalesce(p_other_text, ''))
    else coalesce((select item.label from public.health_care_catalog_items item
      where item.id = p_catalog_item_id and item.collection = p_collection and item.status = 'active'),
      '') end
$$;
revoke all on function app_private.health_care_catalog_label(text, text, text, text) from public, anon, authenticated;

create or replace function public.superadmin_health_care_catalog_v1(
  p_collection text, p_search text default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  search text := lower(btrim(coalesce(p_search, '')));
  categories jsonb;
begin
  perform app_private.require_health_care_actor('health_care.read');
  if p_collection not in ('food', 'restriction', 'guidance') then
    raise invalid_parameter_value using message = 'unsupported catalog collection',
      detail = 'HEALTH_CARE_CATALOG_INVALID';
  end if;
  if char_length(search) = 1 then search := ''; end if;
  with matched as (
    select item.*
    from public.health_care_catalog_items item
    where item.collection = p_collection and item.status = 'active'
      and (search = ''
        or lower(item.label) like '%' || search || '%'
        or exists (select 1 from unnest(item.search_terms) term where term like '%' || search || '%'))
    order by item.sort_order, item.id
    limit 50
  ), grouped as (
    select category_code, category_label, min(sort_order) first_order,
      jsonb_agg(jsonb_build_object('id', id, 'label', label) order by sort_order, id) items
    from matched group by category_code, category_label
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'code', category_code, 'label', category_label, 'items', items) order by first_order), '[]'::jsonb)
    into categories from grouped;
  return jsonb_build_object('collection', p_collection, 'categories', categories,
    'other', jsonb_build_object('id', 'other', 'label', 'Outro'));
end
$$;
alter function public.superadmin_health_care_catalog_v1(text, text) owner to postgres;
revoke all on function public.superadmin_health_care_catalog_v1(text, text) from public, anon, service_role;
grant execute on function public.superadmin_health_care_catalog_v1(text, text) to authenticated;

create or replace function app_private.superadmin_health_care_save_profile(
  p_request_id uuid, p_profile_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_profile_id, gen_random_uuid());
  profile_row public.health_care_profiles;
  child_context uuid;
  child_institution uuid;
  before_json jsonb;
  after_json jsonb;
  justification text := btrim(coalesce(p_payload->>'justification', ''));
  response jsonb;
  revision_no integer;
  item_entry jsonb;
  allergy_entry jsonb;
  entry_index integer;
  entry_collection text;
  entry_catalog text;
  entry_other text;
  entry_label text;
  kept_ids uuid[] := '{}';
  saved_id uuid;
begin
  actor := app_private.require_health_care_actor('health_care.manage');
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'save_profile');
  if response is not null then return response; end if;
  if justification = '' then
    raise check_violation using message='justification required';
  end if;

  if p_profile_id is not null then
    select * into profile_row
    from public.health_care_profiles
    where id = aggregate_id
      and app_private.health_care_scope_allowed(
        'health_care.manage', institution_id, null, null, child_context_id)
    for update;
    if profile_row.id is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if profile_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='HEALTH_CARE_STALE_VERSION';
    end if;
    before_json := to_jsonb(profile_row);
  else
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='HEALTH_CARE_STALE_VERSION';
    end if;
    child_context := app_private.health_care_resolve_child_context(
      (p_payload->>'child_context_id')::uuid,
      (p_payload->>'child_person_id')::uuid,
      (p_payload->>'institution_id')::uuid);
    child_institution := app_private.health_care_child_institution(child_context);
    if child_institution is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if not app_private.health_care_scope_allowed(
      'health_care.manage', child_institution, null, null, child_context) then
      raise insufficient_privilege using message='health_care.manage required';
    end if;
    before_json := null;
  end if;

  if profile_row.id is null then
    insert into public.health_care_profiles(
      id, institution_id, child_context_id, operational_status,
      important_signs, adaptations, created_by_person_id
    ) values (
      aggregate_id, child_institution, child_context,
      coalesce(p_payload->>'operational_status','implementation'),
      coalesce(p_payload->>'important_signs',''),
      coalesce(p_payload->>'adaptations',''),
      actor
    ) returning * into profile_row;
  else
    update public.health_care_profiles set
      operational_status = coalesce(p_payload->>'operational_status', operational_status),
      important_signs = coalesce(p_payload->>'important_signs', important_signs),
      adaptations = coalesce(p_payload->>'adaptations', adaptations),
      management_version = management_version + 1,
      updated_at = now()
    where id = aggregate_id returning * into profile_row;
  end if;

  -- Orientações: lista ordenada; item do catálogo (coleção guidance) ou 'other' com texto.
  if p_payload ? 'items' then
    if jsonb_typeof(p_payload->'items') <> 'array' then
      raise invalid_parameter_value using message='items must be a list';
    end if;
    delete from public.health_care_profile_items where profile_id = aggregate_id;
    entry_index := 0;
    for item_entry in select value from jsonb_array_elements(p_payload->'items') loop
      entry_catalog := item_entry->>'catalog_item_id';
      entry_other := nullif(btrim(coalesce(item_entry->>'other_text','')), '');
      if entry_catalog is null then
        raise invalid_parameter_value using message='catalog item required', detail='HEALTH_CARE_CATALOG_INVALID';
      end if;
      if entry_catalog = 'other' then
        if entry_other is null then
          raise invalid_parameter_value using message='other requires text', detail='HEALTH_CARE_OTHER_TEXT_REQUIRED';
        end if;
      elsif not exists (select 1 from public.health_care_catalog_items c
          where c.id = entry_catalog and c.collection = 'guidance' and c.status = 'active') then
        raise invalid_parameter_value using message='unknown guidance item', detail='HEALTH_CARE_CATALOG_INVALID';
      end if;
      insert into public.health_care_profile_items(profile_id, catalog_item_id, other_text, position)
      values (aggregate_id, entry_catalog, entry_other, entry_index);
      entry_index := entry_index + 1;
    end loop;
  end if;

  -- Alimentos × restrições: lista ordenada; ausentes (ativas) são inativadas.
  if p_payload ? 'allergies' then
    if jsonb_typeof(p_payload->'allergies') <> 'array' then
      raise invalid_parameter_value using message='allergies must be a list';
    end if;
    entry_index := 0;
    for allergy_entry in select value from jsonb_array_elements(p_payload->'allergies') loop
      entry_catalog := allergy_entry->>'catalog_item_id';
      entry_other := nullif(btrim(coalesce(allergy_entry->>'other_text','')), '');
      entry_collection := case coalesce(allergy_entry->>'allergy_type', 'other')
        when 'food' then 'food' when 'restriction' then 'restriction' else null end;
      if entry_catalog is not null then
        if entry_collection is null then
          raise invalid_parameter_value using message='catalog items need food or restriction type',
            detail='HEALTH_CARE_CATALOG_INVALID';
        end if;
        if entry_catalog = 'other' then
          if entry_other is null then
            raise invalid_parameter_value using message='other requires text', detail='HEALTH_CARE_OTHER_TEXT_REQUIRED';
          end if;
        elsif not exists (select 1 from public.health_care_catalog_items c
            where c.id = entry_catalog and c.collection = entry_collection and c.status = 'active') then
          raise invalid_parameter_value using message='unknown catalog item', detail='HEALTH_CARE_CATALOG_INVALID';
        end if;
      end if;
      entry_label := app_private.health_care_catalog_label(
        entry_collection, entry_catalog, entry_other, allergy_entry->>'label');
      if allergy_entry ? 'id' and nullif(allergy_entry->>'id', '') is not null then
        update public.health_care_allergies set
          label = case when entry_label <> '' then entry_label else label end,
          allergy_type = coalesce(allergy_entry->>'allergy_type', allergy_type),
          catalog_item_id = coalesce(entry_catalog, catalog_item_id),
          other_text = case when entry_catalog is null then other_text else entry_other end,
          what_to_do = coalesce(allergy_entry->>'what_to_do', what_to_do),
          position = entry_index,
          status = coalesce(allergy_entry->>'status', status),
          active = coalesce((allergy_entry->>'active')::boolean, active),
          last_episode_at = coalesce(
            (allergy_entry->>'last_episode_at')::timestamptz, last_episode_at),
          episode_severity = coalesce(
            allergy_entry->>'episode_severity', episode_severity),
          observed_reaction = coalesce(
            allergy_entry->>'observed_reaction', observed_reaction),
          guidance = coalesce(allergy_entry->>'guidance', guidance),
          notes = coalesce(allergy_entry->>'notes', notes),
          inactivated_at = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else coalesce(inactivated_at, now()) end,
          inactivation_reason = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else justification end,
          updated_at = now()
        where id = (allergy_entry->>'id')::uuid
          and profile_id = aggregate_id
        returning id into saved_id;
        if saved_id is null then
          raise no_data_found using message='allergy unavailable';
        end if;
      else
        if entry_label = '' then
          raise invalid_parameter_value using message='allergy label required', detail='HEALTH_CARE_LABEL_REQUIRED';
        end if;
        insert into public.health_care_allergies(
          profile_id, label, allergy_type, catalog_item_id, other_text, what_to_do, position,
          status, last_episode_at, episode_severity, observed_reaction, guidance, notes,
          created_by_person_id
        ) values (
          aggregate_id, entry_label,
          coalesce(allergy_entry->>'allergy_type','other'),
          entry_catalog, case when entry_catalog is null then null else entry_other end,
          coalesce(allergy_entry->>'what_to_do',''), entry_index,
          coalesce(allergy_entry->>'status','active'),
          (allergy_entry->>'last_episode_at')::timestamptz,
          allergy_entry->>'episode_severity',
          coalesce(allergy_entry->>'observed_reaction',''),
          coalesce(allergy_entry->>'guidance',''),
          coalesce(allergy_entry->>'notes',''),
          actor
        ) returning id into saved_id;
      end if;
      kept_ids := kept_ids || saved_id;
      entry_index := entry_index + 1;
    end loop;
    -- Removidas da lista: inativa com a justificativa da revisão (histórico preservado).
    update public.health_care_allergies set
      active = false, status = 'history',
      inactivated_at = coalesce(inactivated_at, now()),
      inactivation_reason = justification,
      updated_at = now()
    where profile_id = aggregate_id and active and not (id = any(kept_ids));
  end if;

  after_json := to_jsonb(profile_row);
  select coalesce(max(existing.revision_no), 0) + 1 into revision_no
  from public.health_care_profile_revisions existing
  where existing.profile_id = aggregate_id;
  insert into public.health_care_profile_revisions(
    profile_id, revision_no, subject, justification,
    before_json, after_json, changed_by_person_id
  ) values (
    aggregate_id, revision_no,
    coalesce(p_payload->>'subject','care_profile'), justification,
    before_json, after_json, actor
  );

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', profile_row.management_version,
    'revision', revision_no
  );
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'save_profile', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'health_care.profile.save', 'health_care_profile',
    aggregate_id, profile_row.institution_id, 'success', justification,
    before_json, after_json
  );
  return response;
end
$$;

create or replace function app_private.superadmin_health_care_profile_detail(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid;
  profile_row public.health_care_profiles;
  child_person_id uuid;
  child_display_name text;
begin
  actor := app_private.require_health_care_actor('health_care.read');
  select * into profile_row
  from public.health_care_profiles
  where id = p_profile_id
    and app_private.health_care_scope_allowed(
      'health_care.read', institution_id, null, null, child_context_id);
  if profile_row.id is null then
    raise no_data_found using message='health care profile unavailable';
  end if;
  select child_row.child_person_id, child_person.display_name
    into child_person_id, child_display_name
  from public.child_contexts child_row
  join public.people child_person on child_person.id = child_row.child_person_id
  where child_row.id = profile_row.child_context_id;

  return jsonb_build_object(
    'id', profile_row.id,
    'institution_id', profile_row.institution_id,
    'child_context_id', profile_row.child_context_id,
    'child_person_id', child_person_id,
    'display_name', child_display_name,
    'operational_status', profile_row.operational_status,
    'important_signs', profile_row.important_signs,
    'adaptations', profile_row.adaptations,
    'management_version', profile_row.management_version,
    'can_manage', app_private.health_care_scope_allowed(
      'health_care.manage', profile_row.institution_id, null, null,
      profile_row.child_context_id),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'catalog_item_id', item_row.catalog_item_id,
        'other_text', item_row.other_text,
        'label', app_private.health_care_catalog_label('guidance', item_row.catalog_item_id, item_row.other_text, item_row.catalog_item_id),
        'position', item_row.position) order by item_row.position, item_row.created_at, item_row.catalog_item_id)
      from public.health_care_profile_items item_row
      where item_row.profile_id = profile_row.id), '[]'::jsonb),
    'allergies', coalesce((
      select jsonb_agg(to_jsonb(allergy_row) order by allergy_row.position, allergy_row.created_at)
      from public.health_care_allergies allergy_row
      where allergy_row.profile_id = profile_row.id), '[]'::jsonb),
    'revisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'revision_no', revision_row.revision_no,
        'subject', revision_row.subject,
        'justification', revision_row.justification,
        'created_at', revision_row.created_at) order by revision_row.revision_no desc)
      from public.health_care_profile_revisions revision_row
      where revision_row.profile_id = profile_row.id), '[]'::jsonb)
  );
end
$$;

commit;
