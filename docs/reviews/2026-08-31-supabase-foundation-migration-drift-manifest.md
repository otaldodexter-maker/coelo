---
title: "Manifesto de drift da fundação Supabase — 2026-08-31"
source: "packages/coelo_database/migrations; mirror packages/coelo_database/supabase/migrations; ledger remoto coelo via plugin oficial Supabase; Git HEAD c9b7114bab681ddb3f47a93c6f215570327b15f0"
status: "read-only-inventory"
generated_at: "2026-08-31"
---

# Manifesto de drift da fundação Supabase

Inventário read-only. O ledger remoto expõe versão e nome, mas não o SQL nem SHA-256. Por isso, uma linha `name-version-match` prova somente a coincidência do par versão/nome, não equivalência de conteúdo; coincidência de nome lógico com versão diferente permanece `unresolved` e nunca autoriza restauração ou deploy.

## Resumo

- Canônico local: 112 migrations; mirror preparado e verificado em 112/112.
- Ledger remoto: 103 migrations; última `20260821200000_profile_about_remote_context_compatibility`.
- Classificações por linha do manifesto: `name-version-match` 50, `unresolved` 16, `local-only` 54, `remote-only` 45.
- Ambiente remoto: `blocked-environment`; nenhuma evidência classifica `coelo` como desenvolvimento, homologação ou produção.
- Dependências são marcadores textuais conservadores, não um grafo de execução. A ordem real continua sendo o ledger e os preflights do replay seguro.

## Linhas

| Origem | Migration | SHA-256 local | Marcadores de dependência | Classificação | Observação |
| --- | --- | --- | --- | --- | --- |
| local | `20260623191021_superadmin_foundation_v1.sql` | `1EC51807D2A1F0BBD5CDF7AD11C7EC6D3089CD613319A5954F4D912F45C4EDF3` | auth.users, platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, person_auth_links, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260623203230_schema_boundaries_catalog_v1.sql` | `A8985D8A1FD005C9DE23EA08C8DA916703C908DC891141599445BF3D0F86D1BE` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, person_auth_links, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260717151609_institution_directory_foundation.sql` | `C64E43C80F5994F99E66455F5A0572D18D99ECF7731EEDFAEBB423619FF849F5` | institutions, units, groups | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260720103023_institution_contact_directory_refinement.sql` | `971F61CDCDBBA5FCB077D323D823B76BA7D3C7B56FC3F1DA97FC9EEBEF993716` | institutions, units, groups | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260720180000_people_context_foundation.sql` | `B2D6EE36C1B75961C057230FF8879BB7979CE417AAB0D9662F028C22471B300D` | institutions, units, groups, people, person_auth_links | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260720190000_people_context_advisor_hardening.sql` | `916696126DDDD0B64AA4D8FCF484C8FE26B7191C48F990E7C51A5CDBBCDF893A` | people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724120307_contextual_activities_foundation.sql` | `6625F904248AB5A36E7D665616BD5B2CAB74DD31279442E0493968EA08EB5FD9` | institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724122545_contextual_activities_fk_index_hardening.sql` | `FECEC02870B5462B49001AFBE5AEA737AE439BEF76D493EE339BF78CF3747771` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724152628_contextual_authorization_core.sql` | `BCDC37B5CEDA56ECBE3D71F9C30A59F3D48C1A878519DA45CA37C2245D467795` | units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724152707_family_authorizations_and_transfers.sql` | `36168D2C22D9D2D08C433D26FC9E10164F6CC3DA8B38BDC916EC443655040F8F` | institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724152713_activity_governance_and_participation.sql` | `29D3682BFE4875557AD3C2B1A69D1DC92D076A46A709F8F161BCEDE2D8FEAD6C` | institutions, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724152722_contextual_chat_foundation.sql` | `D85B1B1EFA3A2690800CB0EE2E1F77509B45B76A67152E1D20DFA3C36908A117` | institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724152731_attendance_assiduity_foundation.sql` | `D8F99E587330EB4EC8F30525097A25667CC593B0CB03722DC89B1CDF47269AE6` | institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724161334_contextual_domains_compatibility_hardening.sql` | `9D73E2ABF73C76FD1C20573D8423B297E885CE670570604F65EC6905CAE0B4E7` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724161706_contextual_domains_advisor_hardening.sql` | `5621569F754A28C855386BF8A346A02E2D51FBC49FEB4F75558944444102421D` | groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724162210_contextual_chat_lifecycle_hardening.sql` | `A8F8AC522D74C0B31EBA89F1121A279243C27A457EB97A394832A89548CAD39B` | audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724162604_contextual_chat_trigger_hardening.sql` | `EF7E97F92E628A5C91157BB8CDC9DAE17576C39FF61DF944996E42DEE960733B` | units, groups | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260724162900_contextual_chat_audit_schema_hardening.sql` | `80AE137C545D21CF63C3A5FA3FD11A870A59A021DC59337B2DBA283553419549` | audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260727130433_remediate_schema_column_catalog_completeness.sql` | `FFA67D796D7586B2FCE8FF7682AC6349B35976F0509CDCE88001DCE0EB925606` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260728172333_institution_profile_and_legal_representatives.sql` | `6BE5F3EBB001D9F1C24AAC650A9762A10CAFDA099300127062DF629323F69F68` | institutions, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260728203000_cover_institution_legal_representative_membership_fk.sql` | `F14E603CCBDCBA05FBB7F1D9DF53B536361B7B0E58693E0BABA6E7E13427F8F9` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260729140915_unit_type_plan_foundation.sql` | `71673526884C563A3E44FC1F72FF99B33534F680EC1AC8681F82D58572C4519E` | institutions, units | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260729141839_superadmin_people_directory.sql` | `20CCE28127774F1403280DE351620B255590E60F4E842D2DA22FD897F6FB85BF` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, person_auth_links, audit_logs | unresolved | mesmo nome lógico no remoto em 20260729154458; exige proveniência/conteúdo |
| local | `20260729144440_profiles_permissions_governance.sql` | `D0E87F73C841C338C7DF7553F2C91E91F7287DA481B70501E0F9334FADCE385E` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260729153000_superadmin_people_directory_policy_hardening.sql` | `B938D5AC0399A7137DC764A48BAAFF32776C466C3C8259D0B170778B528C40CD` | — | unresolved | mesmo nome lógico no remoto em 20260729160052; exige proveniência/conteúdo |
| local | `20260729153100_child_context_lifecycle_trigger_hardening.sql` | `0B16D82755171A1AE26059455B8718162C390A54BAC7C1D81107DDCEFC3E6065` | — | unresolved | mesmo nome lógico no remoto em 20260729160103; exige proveniência/conteúdo |
| local | `20260804205732_access_profile_permission_matrix_metadata.sql` | `60992879E5F04EEBC3D368742B97BE7423B80F26AD73C6C3FCC1819A4A59F07F` | platform_roles, platform_permissions, platform_role_permissions, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811125345_institution_management_commands.sql` | `10D8BBBBCC8222F62C2E07E07B0886E1A85B54A6B4DD815965F1218D93417321` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811151254_group_management_security.sql` | `8666C997A8A04E13A404C20F46BFBCAAE0CB12B8B5DBB64623FBFFF4CFCD993F` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811192514_activity_management_security.sql` | `DCB4B5F0781AF2F3B0BB1B6A9B63D79A00549E371B7CA0FEB0AC5BE5BD3820F4` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811193838_activity_management_commands.sql` | `77FDAE731EB56DF04BD45F3B8F854495A422BB3230802B5BC4855840F436813B` | institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811194624_activity_aggregate_commands.sql` | `D28C0C7DAE5947806C4D2C300A14259CDC997DFB0C85E40C2E0D192BC70B15BA` | institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811194840_activity_files_identity_commands.sql` | `3AB6F64F3F2D00FB6FF99FA6F1F3C929753BCF29F5B6506F62C95B50107474E9` | units, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811195042_activity_file_workers.sql` | `B33BDAF0DB753FC7DC35F3E6DA2A5305A789DEA571C1B1F5EC9C12929DDFADD8` | institutions, units, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811195429_activity_management_hardening.sql` | `B0EE2C41376BD482CEAD99931A3FDD1F4AC70327C2615B4A1B879640F32819BA` | people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811200614_activity_read_model_contract_hardening.sql` | `9E99D589EC89975110D3FCAEF8C363701BD255B00072B99A4797A923458CEA26` | institutions, units, groups, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811201830_activity_file_job_authorization.sql` | `ACFEC92C0F1C2907591E76A7BC94B411E7B677013D14ABD3DFA5C5C8587B8A74` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811201945_activity_template_commands_hardening.sql` | `2C844D87A79A3808DF1E67A256481A8794FAC737F4D3B609AEA4A85B3528987F` | institutions, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811202030_activity_options_minimization.sql` | `540E02EB1217D1B177EFBD9A52B610FF698268892C2CA540D476CD719DD8079A` | institutions | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811215451_access_profile_management_v2.sql` | `04C1BEDD194B812EA753243DD95E400D39E0257F985506A8B703E68329D90208` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260811225000_activity_professional_search.sql` | `ECD387C6D810BEC289BE7D8B4FC65A796CAA68DB12A6A5DE15C230BECA79EECB` | institutions, people | local-only | não consta no ledger remoto |
| local | `20260811235900_activity_template_catalog_expansion.sql` | `DF0590D656CDF0692DCF17BB0E6D33CC6853A5C373D4D858470B269511C27DB7` | institutions | local-only | não consta no ledger remoto |
| local | `20260812000000_chat_production_contract.sql` | `75E18DE4D9108A55719ACAE93AF011221FDB81E8259772BB93C52DF37508FE47` | people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260812000847_audit_production.sql` | `5F5047292C7ED7BBD0F87C5F164628EE50AC211F481E018968469F0B3AD13D0E` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260812001000_import_export_hub_security.sql` | `3EAECD8E31F2C3BA6DD227AEFC8216AB1D91AC707FB202C4CFFF862B5F43BE5E` | institutions, units, groups, people | local-only | não consta no ledger remoto |
| local | `20260812001950_import_export_hub_lifecycle_closure.sql` | `CCA415EF3C7A26701B9B767ADCEB73CE8610F28D20ADACFB8B9DF007FD61CE52` | institutions, units, groups, people | local-only | não consta no ledger remoto |
| local | `20260812001975_import_export_hub_unit_lifecycle_bridge.sql` | `DD53AAB6CBE91043672EFEF567F6F6EE86BF23B169DD4F831D9FB1B2ED54593E` | units | local-only | não consta no ledger remoto |
| local | `20260812002000_child_safety_schema.sql` | `2912B2D52D46F1C87F1238DB1C16C296360AB89F1BE32B8EF1F375C513C41809` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, people | local-only | não consta no ledger remoto |
| local | `20260812002010_import_export_unit_source_retention.sql` | `7627B9C90D2C728207A0EB58A98B947687C45D1374DFF8CBF326538E3736539C` | — | local-only | não consta no ledger remoto |
| local | `20260812002020_import_export_hub_private_revokes.sql` | `161A382F0868402A7B41486D7D2C5A316CC7C51A500B7340753E48A10F8CEDF1` | — | local-only | não consta no ledger remoto |
| local | `20260812002100_child_safety_read_models.sql` | `FCACCBAEA2A4236EBB5D728D6B0AC9AD71D04F47FD662B22E4C80F6DE2487B28` | institutions, units, people | local-only | não consta no ledger remoto |
| local | `20260812002110_import_export_hub_server_listing_filters.sql` | `88D1B96BAED0D6CF780E03DE9FDDBD7613B0686B09B774D93C576577D2BA6D6F` | units | local-only | não consta no ledger remoto |
| local | `20260812002200_child_safety_security_closure.sql` | `94D8B1267E6186E8C9393584BF67FDBBD7DA6592560E15FBB118E5EB650F2E7C` | platform_permissions, institutions, units, people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260812002900_notices_status_values.sql` | `C2416311DC7CDF259990B68D795F486D3FDBB61E86285ED23C7676942DCE390C` | — | local-only | não consta no ledger remoto |
| local | `20260812003000_notices_production.sql` | `B520EE080A51EC44B78EE577AA1997465CDA8A3AEEEF267419C812667FE55D26` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people | local-only | não consta no ledger remoto |
| local | `20260812120244_chat_rpc_contract_hardening.sql` | `C352E493CE754FAFE98AA5D84496E97AD5ECC043624D98C2434B1C8F1721A7AA` | — | local-only | não consta no ledger remoto |
| local | `20260812121146_chat_typed_rpc_presentation_contract.sql` | `83CF6D229F267FBE7675F421C17D6AEAFF46932BD6055B684378F0F3696EFA0A` | people | local-only | não consta no ledger remoto |
| local | `20260812144500_activity_template_create_command.sql` | `581C8602B7891FAFEA50D11997CA52A70A631CF9576B45472C0A9C169D9D0D85` | institutions, people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260813120000_meal_plans_superadmin.sql` | `19961F34BFB493843522342513DC89E99807E9EAC5FF0679E3A3B0B8C5F4F0F6` | platform_permissions, institutions, units, groups, people | unresolved | mesmo nome lógico no remoto em 20260813181952; exige proveniência/conteúdo |
| local | `20260813123000_meal_plans_policy_hardening.sql` | `405F76C54F67513E5840B4D118D1DE4DC5D59B8FBC57557863AE47884DD37352` | — | unresolved | mesmo nome lógico no remoto em 20260813182036; exige proveniência/conteúdo |
| local | `20260813124500_meal_plans_rpc_grants_hardening.sql` | `80CE04DB14E4A6513A3A7010B56E479EB5141ACB98ADB7EEA3AA7415865A2270` | — | unresolved | mesmo nome lógico no remoto em 20260813182115; exige proveniência/conteúdo |
| local | `20260813155005_forms_definition_and_capabilities.sql` | `3A3D2BD348948CDEF78A3A0C712C9EAE8A6A6FB8BE59B8FD942A445F6CBB6E36` | platform_roles, platform_permissions, platform_role_permissions, institutions, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813155116_forms_distribution_and_occurrences.sql` | `AB79C2616FA74944F5213E9544E0033D438308CF4A44B33BCE34D7617421B2A0` | institutions, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813155118_forms_responses_and_private_media.sql` | `10D338D20948338F16170E3E95FDD3596562BE4E3F2056174087EDD6BC2A6EE2` | institutions, units, people | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813155121_forms_commands_and_projections.sql` | `CC4ABA66CD457862AD8F112876C9E030797BBBBEE85ACB2FAACFA1B0CAB7D24A` | institutions, units, groups, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813155124_forms_jobs_notifications_and_exports.sql` | `431BC871F2625F040EF51E49603905E0BB1696410FD90DE7EF9000A508EC71F0` | platform_roles, institutions, units, people, audit_logs | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813155126_forms_security_performance_closure.sql` | `2B2A40BCC4C8C85B41765FBECDE28DCFDC033F6791BD35313B2D3B8212B2E5E1` | units, groups | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260813170001_forms_monitor_hierarchy.sql` | `7758F30CC1F6BCBF7D5F726A7F84B9951C6CA92C2013BDDB461CBA169B6DA618` | institutions, units, groups | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260820150000_meal_plans_tenant_conflict_hardening.sql` | `04C9254094287405D6539DCDF6BEFE4101389F3A7B42056AE1A8E50F73090278` | platform_roles | local-only | não consta no ledger remoto |
| local | `20260820150500_meal_plans_scope_guard.sql` | `D824E0CBA683B2AFB193E711D7889B857B72DE59830600F36F3492D1371DD479` | platform_roles | local-only | não consta no ledger remoto |
| local | `20260820151000_meal_plans_invoker_rls.sql` | `242FF78106EA3C6BCDF3C72D15F39990D1D6B1492CBF80BEF7C1B945E38ADC3A` | — | local-only | não consta no ledger remoto |
| local | `20260820152528_forms_editor_application_capability_guard.sql` | `CA40B79327B8D61AC45D1914D6D8424EA2580F487205E91F5F3883F19ACBA81C` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260820154638_forms_distribution_cardinality_limits.sql` | `659D7EE37882398BA3D537C15F383EE65E45CFC4A570417B105535E0E6E7BF16` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260820160000_meal_plans_model_audience_availability.sql` | `F4E8C88BA3C92AFEADE49D969D625B124BF6196BC1D7DA58008BEA6BCEACC8E3` | institutions, units, groups, people | local-only | não consta no ledger remoto |
| local | `20260820171000_meal_plan_private_images.sql` | `E8E98677C8F4F24B827100F388E39F2BB26B2F9468E5BD5EDC9FF482749A317D` | institutions, people, audit_logs | unresolved | mesmo nome lógico no remoto em 20260820173350; exige proveniência/conteúdo |
| local | `20260820171100_meal_plan_fk_indexes.sql` | `1BD42F4C0504795BC2E2FFEF352B92BC3550E20E7CC02E2D66E2CCD5E699BDE4` | — | unresolved | mesmo nome lógico no remoto em 20260820174445; exige proveniência/conteúdo |
| local | `20260820182000_happens_publication_mvp.sql` | `A28A9F8F41412B09B7149205CB52F784CA1F80B7EB4AA761F91EA3A69B9A4B8D` | institutions, units, groups, people, person_auth_links | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260820182100_happens_media_security_closure.sql` | `DE945F39D64C5054F360B3FE38991296D56377E19DA23F5E4D18165372B4C5CC` | — | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260820204752_app_communications_types.sql` | `F5DE7815DC811772DEDE8116BA70D0683652DCD3F797B0FFF9A81E2AB840699A` | — | local-only | não consta no ledger remoto |
| local | `20260820204824_app_communications_contract.sql` | `2DCF1AEA80B85E865B2689AD798A0024CBF972E2CB563E1AEC3C63751FAD6852` | — | local-only | não consta no ledger remoto |
| local | `20260820212340_notice_publication_worker_runtime.sql` | `E0174219975BDF15A297CE7C94C2D1946E44148C6F067012E157715E635C1AC2` | — | local-only | não consta no ledger remoto |
| local | `20260820220000_now_publication_mvp.sql` | `3AF85B9196362CF41212E0C5E740DE37C356D8C3BC28550622FA9941D9196477` | institutions, units, groups, people, person_auth_links | local-only | não consta no ledger remoto |
| local | `20260820220500_notice_publication_receipts_versioning.sql` | `E565A14A00B1456586FC3E5CD3F6283C1602C8FFB3F90D724796FB37E5BA4F0F` | — | local-only | não consta no ledger remoto |
| local | `20260820230000_meal_plan_media_lifecycle_receipts.sql` | `2FE0400D59ED9AF08454F1D0AE2696730E7C5C2FCA0D6CD601349370D0622CD4` | people | local-only | não consta no ledger remoto |
| local | `20260821112822_moments_publication_mvp.sql` | `3F1459BCF1673184D4B64F0A2589B6BC08DAFADF9B5295BD651E2E4F62C81910` | institutions, units, groups, people, person_auth_links | local-only | não consta no ledger remoto |
| local | `20260821130000_now_custom_role_audience_hardening.sql` | `E57259325223CF09AB2A9F150FA9FBDE2D38945D59600A80494D9748983D3832` | institutions, units, groups, people, person_auth_links | local-only | não consta no ledger remoto |
| local | `20260821190000_circulars_production.sql` | `FF2818B9FDCC17EE9DF349D977FE6A6DFCF5A6B60DEEB64B874D3108019F8CD8` | institutions, units, groups, people, person_auth_links | name-version-match | versão e nome coincidem; conteúdo remoto não é exposto pelo ledger |
| local | `20260825171221_attendance_responsive_dashboard.sql` | `E3A93182083FE3EE80A500D1FB91DBEB7195E9C01A6D239C3D5EB4F0DA9C1128` | platform_permissions, institutions, units, groups, people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825173604_harden_public_client_privileges.sql` | `9D97238A14AB72C373D6E99B3CC0CAC37DC981922E2B97571FEBBA7D5E9DAA7E` | — | local-only | não consta no ledger remoto |
| local | `20260825173938_close_legacy_unit_import_export_gateways.sql` | `5DC6966D350EABE3CFD80F11F71E54DD4B07A073A5840373E8F792A2E1A5DD6E` | — | local-only | não consta no ledger remoto |
| local | `20260825174300_expose_scoped_unit_failure_gateway.sql` | `F949C9992D3BAD10137A35FD0A20700263750E27B9D8CCC5EB6605D7B99794AC` | — | local-only | não consta no ledger remoto |
| local | `20260825180000_revoke_student_tracking_normalizer_client_execute.sql` | `487A6F8EA35699C88508DE78FC5605C59C1E8978B92FE8B1B02E0EA9E5EC4552` | — | local-only | não consta no ledger remoto |
| local | `20260825180500_repair_unit_import_export_runtime_contract.sql` | `65EE86DF923848942CE12508F40DF0F6EF98D327F6B1F2C4EBAB1313F1056847` | units, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193102_final_review_import_workers_lint_hardening.sql` | `3BBE26DB251D532FF94AF2C886F4463318A856E1491A662D965AC070A9DF956B` | institutions, units, groups, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193105_final_review_unit_identity_lint_hardening.sql` | `425312795A69EAEC5F5076C54FE7A573E991154A9E3F7E688B95D3F990439C77` | units, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193109_final_review_access_profiles_lint_hardening.sql` | `CB2362A133C22BBFCE3153D9ACDC71171AE72C19C1BB535B8E12EB90D20AEA6F` | platform_roles, institutions, units, groups, people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193112_final_review_daily_routine_lint_hardening.sql` | `3366D0A7FB15C08372A3F12D5958A5B4BDD3AB2BC04FB3CD2AD4327AADB5FEB3` | audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193116_final_review_child_safety_lint_hardening.sql` | `C9991FDC9CF3414F4461608FF3F10D56CB494006EF868BE628E0B96D8F8DC759` | people, audit_logs | local-only | não consta no ledger remoto |
| local | `20260825193120_final_review_forms_runtime_hardening.sql` | `916FE399CB326D7DB36F1B232AA1C1E2EBE0556C93C5546A3422F28060E38EE7` | institutions, units, groups | local-only | não consta no ledger remoto |
| local | `20260825193123_final_review_student_tracking_read_fix.sql` | `4F0D799A4C81C7C6EA2102BBB365D0FE063BE5407106AA658CF496267A39BB12` | institutions, people | local-only | não consta no ledger remoto |
| local | `20260825193128_final_review_chat_inbox_lint_hardening.sql` | `CA735B7F1D06F38EB10D8800A3B8D4272E76A5F7964CB367F530B5FB775E3622` | — | local-only | não consta no ledger remoto |
| local | `20260825193131_final_review_profile_about_lint_hardening.sql` | `0FD30EE067C698DEEE5FB8719F51D96AF5DF552332232D152988EBD82D9B4086` | institutions, units, groups | local-only | não consta no ledger remoto |
| local | `20260827214000_harden_default_function_execute_privileges.sql` | `FE77AD1DAA41477CEB15A91D8080A866B8A23ED470E585C5685F575123BFD5FF` | — | local-only | não consta no ledger remoto |
| local | `20260827222000_unit_import_export_private_acl_closure.sql` | `D3F5BBF8EBF51BF09FA9CAE249F92BF98978DA35CC6F03F3EB0A82D0841AE296` | — | local-only | não consta no ledger remoto |
| local | `20260827222500_harden_platform_notice_table_access.sql` | `ADA41560F39F0544435AF45920A585CC1BDBBC40450E8D55035E3989CB5A6732` | — | local-only | não consta no ledger remoto |
| local | `20260827233000_superadmin_internal_auth_context.sql` | `87D03CD1E75D9859438C82ABBF3C59424680BDD64B57741F10740A5AC7007A33` | auth.users, auth.sessions, platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, person_auth_links, audit_logs | local-only | não consta no ledger remoto |
| local | `20260827234500_superadmin_internal_institution_detail.sql` | `AC3592F2B6F2A03D0A1531865069FEB344BB047DDFE9308C6801D83FEC4AF652` | — | local-only | não consta no ledger remoto |
| local | `20260827235500_superadmin_internal_institution_list_filter.sql` | `C4496229E2D004907B1C878E9719CADFA60169307EEB92BE67CD76C3AD5551AA` | units, groups | local-only | não consta no ledger remoto |
| local | `20260828000500_superadmin_internal_institution_edit_core.sql` | `102A543E5C5E2C8EFCC30C39F69FEF8D8749EE207A3A3BE934F1EFDBB4FA96FB` | institutions | local-only | não consta no ledger remoto |
| local | `20260828002000_superadmin_internal_unit_detail.sql` | `445BA2E1F4D948124BB20D72775AA131C92BA290643D9EB477996EFD72E4C3B6` | institutions, units | local-only | não consta no ledger remoto |
| local | `20260828003500_superadmin_internal_group_detail.sql` | `F4F3CCACF25B28F0C1FD1BEF3F32FD25EBD572549FEBB04FDBA74DADF549C334` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups | local-only | não consta no ledger remoto |
| local | `20260828005000_superadmin_internal_person_detail.sql` | `E197304BACBF7E3A44A47DCA1D2EA75110D25CBA4CA68538615B6799E6D3E39E` | platform_roles, platform_permissions, platform_role_permissions, institutions, units, groups, people, person_auth_links | local-only | não consta no ledger remoto |
| remoto | `20260729154458_superadmin_people_directory` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260729141839; não inferir equivalência |
| remoto | `20260729160052_superadmin_people_directory_policy_hardening` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260729153000; não inferir equivalência |
| remoto | `20260729160103_child_context_lifecycle_trigger_hardening` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260729153100; não inferir equivalência |
| remoto | `20260811180804_group_management_idempotency_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811190000_group_security_advisor_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811193000_group_create_replay_idempotency` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811194500_group_client_table_grants_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811200000_group_foreign_key_indexes` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811201500_group_read_policy_consolidation` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811203000_institution_management_security_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811213000_institution_management_authorization_order` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811214000_unit_management_security` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811214500_unit_identity_storage` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811214600_unit_management_contract_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811215621_unit_performance_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811220631_institution_identity_storage_and_handles` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811220646_institution_import_export` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811221002_institution_storage_rls_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811221316_access_profile_management_v2_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811221810_access_profile_management_v2_security_gate` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811222209_unit_contract_security_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811222316_access_profile_management_v2_security_closure` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811222844_access_profile_assignment_and_worker_closure` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811223000_unit_import_export` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811223100_unit_import_export_cursor` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811223200_unit_export_filter_contract` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811224500_people_identity_safe_foundation` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811230000_database_lint_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811230100_database_lint_hardening_followup` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811230200_database_lint_count_variables` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260811235155_unit_export_snapshot_fk_index` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260812131952_unit_edge_execution_scope` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260813181952_meal_plans_superadmin` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260813120000; não inferir equivalência |
| remoto | `20260813182036_meal_plans_policy_hardening` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260813123000; não inferir equivalência |
| remoto | `20260813182115_meal_plans_rpc_grants_hardening` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260813124500; não inferir equivalência |
| remoto | `20260820114916_meal_plans_scope_guard_20260820` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820114935_meal_plans_invoker_rls_20260820` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820121005_meal_plans_conflict_precedence_20260820` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820124500_forms_route_context` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820143725_forms_editor_application_projection` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820153750_forms_performance_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820154917_meal_plans_model_audience_availability_v2` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820164500_forms_export_download_authorization` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820164600_forms_export_download_capability_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820171018_forms_trigger_dispatch_hardening` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820171200_forms_download_token_actor_fk_index` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820172043_forms_response_revision_qualification` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820173350_meal_plan_private_images` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260820171000; não inferir equivalência |
| remoto | `20260820174445_meal_plan_fk_indexes` | não exposto pelo ledger | — | unresolved | mesmo nome lógico local em 20260820171100; não inferir equivalência |
| remoto | `20260820182229_forms_edge_rpc_argument_names` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260820183250_forms_duplicate_index_cleanup` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260821192000_profile_about_production` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |
| remoto | `20260821200000_profile_about_remote_context_compatibility` | não exposto pelo ledger | — | remote-only | ausente do HEAD canônico |

## Regras de uso

1. `equivalent` significa somente versão e nome iguais no ledger; o hash remoto continua indisponível.
2. `unresolved` exige comparação de conteúdo/proveniência antes de qualquer ação.
3. `local-only` e `remote-only` não são candidatos automáticos a aplicação, repair ou restauração.
4. Migrations já aplicadas remotamente nunca são editadas; qualquer correção é forward-only.
