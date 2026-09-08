---
source:
  - "Coordenador Etapa 2: preparação nominal A01 seed HTTP/base55 e platform.read explícito para Operations102/Content106"
  - "f5b0e5bff1a9b9ba5a11f7c01f2fe8c2d91652b0: docs/reviews/evidence/etapa-2/agenda-operacoes/2026-09-08-a01-local-runtime-proposal.md"
  - "ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4: fixture97 superadmin_internal_activities_v2_directory_contract_test.sql"
  - "464a947dff729acfaabb5ee6fbdd7faa242b6b1e: A01DirectoryAuditGreen55"
status: preparacao_estatica_aguardando_gate_operacional
generated_at: "2026-09-08"
scope: "Seed SQL nominal e proposta de janela HTTP descartável A01; sem runner ou execução"
execution_performed: false
---

Esta entrega prepara packages/coelo_database/tests/fixtures/a01_local_http_seed.sql para tornar os dados sintéticos da fixture97 visíveis por HTTP em uma futura stack descartável **A01DirectoryAuditGreen55**, alvo20260907222911. O caminho real do roteiro no commit f5b0e5bff1a9b9ba5a11f7c01f2fe8c2d91652b0 é **agenda-operacoes**, não activities.

Recorte: extração semântica do setup, grants nominais de bootstrap, constraints/GUCs limpos antes de COMMIT, IDs/payloads, vínculo endpoint→banco55 e proposta de timeout/teardown próprios. Ordem: conferir fonte/pins → roteiro/fixture → seed/proposta → revisão estática. Parada: dois arquivos concretos para revisão central. A autorização recebida é de preparação e dos dois grants adicionais; **não autoriza SQL, Docker, HTTP, emissão de tokens ou operação da janela**. Prazo operacional é proposta abaixo, não execução realizada.

**Zero SQL, Docker, HTTP e mutações Git foram executados nesta tarefa.** Somente o SQL novo e este Markdown foram escritos. Nenhum wrapper, cleanup, runner, mecanismo genérico, helper persistente, RPC de inspeção ou arquivo cliente foi alterado. O seed é dados de teste separados, não migration e não perfil executável.

Base pinada:

| Campo | Valor |
|---|---|
| Perfil e commit | A01DirectoryAuditGreen;464a947dff729acfaabb5ee6fbdd7faa242b6b1e |
| Descriptor | packages/coelo_database/replay/profiles/A01DirectoryAuditGreen/profile.json |
| SHA descriptor UTF-8/CRLF | bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba |
| Manifesto Auth | packages/coelo_database/replay/foundation-migrations.sha256 |
| SHA manifesto UTF-8/CRLF | 4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59 |
| Contagem | Auth45 + oito adições =53 canônicas + dois preflights =55 |
| Fronteira Auth / alvo único | 20260901200206 /20260907222911 |
| Corretiva aprovada | 96de811b8ce02333f302117e9ee8c4e7d5dc445d |
| SHA corretiva CRLF | e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f |
| SHA corretiva LF | e4b02a2100030c36a0895d04036685cafae623326872f3141902d00043fe66f2 |

Foram conferidos os55 hashes de origem antes da escrita, além de descriptor/manifesto e contagens. A01DirectoryAuditRed também tem55/alvo22911, mas usa a corretiva anterior de hash77b248f6...; não é substituto. Foundation67 ou base genérica51 tampouco equivalem ao Green55.

| Posição canônica, sem preflights | Adição completa | SHA-256 UTF-8/CRLF |
|---:|---|---|
| 44 | 20260831192831_activities_v2_actor_attribution.sql | ad10aa26bd2c7c797ef606f9ee9cc9038c02bba10543b9930d14d36b9ad383bf |
| 45 | 20260831195118_activities_v2_actor_provenance_hardening.sql | 31f54a5b8bc1c8dde45f60903ae0c5ef1651db580169a83aba37fc5487af50c8 |
| 46 | 20260831195944_activities_v2_actor_provenance_semantics.sql | 19c3168014d7710b248da92100bb1b61528e9299150a54da74080315e8b99745 |
| 47 | 20260831203645_activities_v2_permissions_receipts.sql | 84bfc497aae6e4d8ad950fc03035896d6b9246c42531823e32ce34817b0d02b5 |
| 48 | 20260831211945_activities_v2_internal_gateways.sql | 443be75040ca103a7a6723aa90037359c11c1681afdc6a6361c2d81f667a6dfa |
| 49 | 20260831231645_activities_v2_rls_grants.sql | 0e156b3beb53ebbf1caca033908f0d6755f274b9fa9d38b26bcc4b7da7c65dc1 |
| 50 | 20260831234307_activities_v2_final_review_hardening.sql | 01663a89c55e5de081aa97b808cec0329ae4af9dd6a24ef2d80c87d6c0ddc898 |
| 53 | 20260907222911_superadmin_activity_directory_v2_client_contract.sql | e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f |

Os dois preflights herdados são20260811151253_assert_function_execute_preflight.sql, hash718c2de052e9df29abc42642806d9a5e4d98c8964665453de6f14f0f8b61ab75, e20260811215452_access_profile_labels_replay_bridge.sql, hashd97e02796fcd5897707b5657b7a1c1df690f831e09ed98df6ed21886f75f9ef3. Zero bridges adicionais; fontes canônicas e preflights permanecem intactos.

Proveniência do seed:

| Campo | Valor |
|---|---|
| Fixture | packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql |
| Commit | ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4 |
| Blob | 3d7d25ab24a738a03a1f1f11e4a500c13706ca6a |
| SHA fixture LF | fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1 |
| SHA fixture CRLF | f028b86a065f7ea50c1447a62a2b0131ec8cc9119f117c5947355979b1c9648f |
| Novo SQL | packages/coelo_database/tests/fixtures/a01_local_http_seed.sql |
| SHA SQL UTF-8/CRLF | 758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99 |

A fixture atual no worktree coincide com o blob aprovado após normalização. A extração usa anchors únicos de conteúdo: primeiro INSERT de institution_types até o DELETE final de activities.manage/link_units/link_groups de Operations. Inclui estruturas, Auth039, grants/deny, três atividades e vínculos, e exclui a troca de claims para o reader102 que antecede o TAP. Não depende de faixa numérica de linhas.

Diferenças nominais do seed em relação à fixture:

- Não contém pgTAP, no_plan, assertions, helpers TEMP de teste ou ROLLBACK. COMMIT é necessário para que outra conexão/PostgREST enxergue as linhas.
- O corpo extraído fica em DO transacional; sete SELECT set_config tornam-se PERFORM set_config para não emitir o conteúdo dos GUCs no resultado SQL. Os metadados de claims são sintéticos, não JWTs assinados.
- Acrescenta somente platform.read allow/active para os papéis existentes operations e content, autorização central posterior ao roteiro. Não acrescenta pessoa global, service role, grants de RPC/tabela/schema ou capacidades de comando.
- Preserva integralmente os dados/grants/deny e remoções de escrita do setup original. Guard final rejeita allow ativo Operations em activities.create/manage/link_units/link_groups/assign_people/manage_permissions; não revoga outra capability silenciosamente.
- Exige postgres, session_replication_role=origin, conexão inicialmente sem claims/marker, tabelas reais Auth039 e três RPCs da base, além dos papéis/catálogo existentes. Isso não prova isolamento nem igualdade da versão da corretiva; pins e destino são gates do operador.
- SET CONSTRAINTS ALL IMMEDIATE ocorre depois do setup, enquanto o contexto validado ainda existe, antes de limpar claims/marker e COMMIT. Nenhum trigger, FK, RLS ou check é desativado; nenhuma função persistente é criada.

Os grants adicionais são **por papel**, seguindo o modelo da fixture, não por auth_user. Operations também é o papel da membership504 revogada; H039 deve continuar negando104 apesar de platform.read no papel. Os papéis owner/operations/content só podem ser alterados neste banco descartável, nunca numa stack compartilhada. A Pessoa601 continua exclusivamente o controle People-only105, sem person_auth_link de102/104/106.

Achado concreto de limite: **Auth45/20260811192514_activity_management_security.sql:28–33 concede activities.taxonomy.manage a Operations**. A fixture97 não remove essa concessão, e esta extração a preserva. Não se afirma “zero escrita em todo domínio” nem se revoga a capability sem novo delta nominal.102 fica sem as seis capacidades de comando listadas no guard e a allowlist HTTP só contém bootstrap e os dois readers; taxonomia está fora da superfície exercitada. Se o Coordenador exigir retirar também esse grant, o seed precisa de alteração nominal explícita e novo hash antes de execução.

IDs usam o prefixo8a200000-0000-4000-8000- e sufixo decimal de12dígitos:

| Recurso | Sufixos e estado |
|---|---|
| Tipo / instituições | 001; A010/B020 |
| Unidades / grupos | A011/A012/B021; A013–017/B022 |
| Atividades | 701 Robótica A,703 Robótica Local A,702 Robótica B |
| Unidade links | 711/713→701;721→702;731→703 |
| Grupo links | 712/714/715→701;722→702;732→703 |
| Reader | auth102/session202/identity302/link402/membership502; Operations instituiçãoA |
| Revogado | auth104/session204/identity304/link404/membership504 revogada |
| Capability negada | auth106/session206/identity306/link406/membership506; Content plataforma; bootstrap válido e activities.read deny |
| Setup validado | auth101/session201/identity301/link401/membership501 Owner plataforma |
| Controles herdados | auth103/session203 AAL1; auth105/session205 People-only601; session209 expirada |

auth.users e auth.sessions são linhas sintéticas **nas tabelas reais do Supabase**, com not_after positivo de uma hora desde o início da transação, salvo session209 negativa. Isso prova apenas o estado necessário a H039 depois de aplicado; não constitui login GoTrue, senha, refresh ou reautenticação. Não são criadas views/stubs Auth. O operador deve confirmar tipo/colunas e not_after real antes da janela; atraso consome validade. O seed não contém senha, refresh token, JWT, anon/service key ou signing secret, nem imprime esses valores.

O roteiro pede credenciais locais sintéticas por ambiente de processo: COELO_A01_LOCAL_RUNTIME=1, COELO_A01_LOCAL_URL, COELO_A01_LOCAL_ANON_KEY e COELO_A01_READER_JWT/REVOKED_JWT/DENIED_JWT. Este seed não as produz. Nenhuma credencial deve ir para arquivo, Git, asset, dart-define, bundle, header log ou evidência. A URL deve ser http://127.0.0.1:porta-reservada, porta1024–65535, sem userinfo/query/fragmento/redirect. Os tokens dos atores102/104/106 devem ter sub/session_id exatos, role authenticated, aal2 e validade restante positiva ≤1h, limitada também à sessão; assinatura é validada pelo servidor. Validação do parser cliente não substitui assinatura/autorização.

Payloads conferidos no adapter do commit f5b0e5bff1a9b9ba5a11f7c01f2fe8c2d91652b0:

| POST sob /rest/v1/rpc | Payload | Expectativa |
|---|---|---|
| superadmin_auth_bootstrap_context | Sem parâmetros | 102 retorna contexto instituiçãoA com platform.read/activities.read;104 nega;106 passa bootstrap. |
| superadmin_activity_directory_v2 | p_filters: search vazio e arrays institution_ids/unit_ids/group_ids/statuses/origins vazios; p_limit11,p_offset0,p_sort=name,p_sort_ascending=true |102 recebe701/703; filtro institution_ids=[B020] retorna itens vazios/total0. |
| superadmin_activity_filter_options_v2 | Sem parâmetros |102 recebe1 instituição/2 unidades/5 grupos;106 é negado por activities.read. |

A fonte produtiva é apps/superadmin/lib/features/activities/data/supabase_activity_directory_repository.dart:15–76 **nesse commit cliente**. O adapter presente no worktree e1-replay-harness ainda retorna indisponibilidade em fetchPage/fetchFilterOptions. A janela deve selecionar explicitamente o checkout cliente que contém f5b0e5bf e dependências integradas; executar numa cópia antiga não prova o SQL. Nenhum arquivo cliente foi alterado aqui.

Endpoint→banco55 exige evidência operacional: identidade exclusiva da stack/banco/volumes/porta, mapeamento local e configuração efetiva PostgREST/Kong ligados ao mesmo banco onde foram conferidos descriptor/migrations/seed. Após COMMIT, reload de schema precisa ter evidência de conclusão. Nome de container, HTTP200 ou IDs iguais isoladamente não demonstram essa ligação. A correlação de chamada HTTP com audit.audit_logs nesse banco, ator/link/membership/instituição e hash de sessão esperados, reforça a prova. Não expor RPC privada de inspeção nem tabela direta para isso.

Proposta concreta de janela, ainda sem runner e dependente do gate central:

1. Root apresenta pacote do operador que reutilize o Green55 em stack/porta exclusivas com teardown próprio em finally. **Não remover, desativar ou contornar o cleanup de Invoke-SafeLocalMigrationReplay**; a execução normal desse wrapper desmonta o ambiente e não deixa lease HTTP.
2. A proposta específica de helper aprovada para preparação fixa180s para o processo Flutter filho e JWTs sintéticos de10min. Substitui os tetos preliminares de20min/10min desta nota; não é reserva executada. Timeout/falha/interrupção/sucesso devolvem controle ao finally de desmontagem do wrapper. As auth.sessions herdadas continuam com uma hora; o seed não foi alterado para essa duração.
3. Sob lease separado, operador verifica55 pins, target/corretiva Green, Auth real e ausência de colisões; aplica somente o seed pinado em conexão fresca com stop-on-error. Confere COMMIT, constraints, GUCs limpos, IDs/grants/not_after e captura baseline de atividades/vínculos/receipts depois do seed. Se faltar schema ou houver conflito, interrompe sem inventar DDL ou relaxar guards.
4. Prova endpoint/schema reload, fornece somente ambiente efêmero e executa o roteiro no checkout cliente correto. O cliente já tem timeout10s de request/body e espera UI10s; o helper nominal em preparação limita o filho a180s, com revisão e gate de execução separados.
5. Executa bootstrap real → rota normal /activities → saída/reentrada com novos HTTP → filtros/negativas102/104/106 → shell autorizado muda para104 e limpa itens. Sem opt-in, SKIP não é evidência de execução. Reentrada de rota não é reinício do app ou nova sessãoAuth.
6. Consulta audit separadamente por correlações UUID emitidas: ator/link/membership, permission/outcome/instituição/hash de sessão e after_json de sucesso somente row_count. Não usar reader legado de Auditoria. Confere domínio/receipts contra baseline, sem tratar correlação impressa como prova suficiente.
7. Teardown encerra somente recursos nominais e remove staging; conferência independente verifica recursos próprios ausentes e históricos preservados. O mecanismo/comandos, identificação dos recursos e comportamento sob interrupção são o próximo pacote do root, não implementados aqui.

O roteiro cita97TAP PASS anteriores da base55, mas isso não prova este seed persistente ou HTTP. Nesta entrega não houve compilação SQL, constraints/COMMIT executados, Auth HTTP, verificação de assinatura, UI, audit correlacionado, timeout ou teardown. O seed e a proposta estão prontos para revisão central; não autorizam CRUD/taxonomia, produção ou declaração verified-e2e. Nenhuma regra de produto ou projeção de conhecimento foi alterada.

Atualização nominal do root em2026-09-08: antes de qualquer escrita, o seed exige current_setting('coelo.local_replay',true) = 'a01-http-green55'; ausência ou valor diferente lança55000. O hash atualizado acima incorpora somente esse opt-in adicional. O helper deverá fixar essa GUC na mesma sessão psql do seed, após gates de identidade/base55. A autorização central preserva taxonomy.manage histórico e limita a verificação às três RPCs HTTP e comandos de UI exercitados; não requer revogação adicional.
