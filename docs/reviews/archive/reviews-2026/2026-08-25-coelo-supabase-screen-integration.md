---
source: "Integração funcional tela a tela Coelo + Supabase"
status: "open"
generated_at: "2026-08-25"
---

# Integração funcional Coelo + Supabase

## 1. Ambiente validado

- Supabase local em `127.0.0.1`, com 148 migrations aplicadas, foi o único ambiente usado para escrita e dados sintéticos `codex-e2e-*`.
- O projeto remoto Coelo foi identificado pelo ref mascarado `evvbom…gvpt`, região `sa-east-1`, Postgres 17 e estado saudável. Não existe fonte canônica que o classifique como desenvolvimento, staging ou produção; por isso toda mutação remota permaneceu bloqueada.
- Nenhuma migration, Edge Function, repair ou dado foi aplicado remotamente.
- O cliente usa configuração publishable/anon. A busca por `service_role`, `sb_secret_*` e JWTs não encontrou segredo no bundle; o único marcador em código de app é um verificador que procura esse tipo de vazamento.
- No inventário final, Postgres estava saudável e o gateway local respondia; dois servidores de aplicação permaneciam ouvindo nas portas 7357 e 7358. O container de telemetria `vector` reiniciava e `analytics` ainda inicializava após o reset concorrente; nenhuma correção ou teardown foi feito por esta frente.
- Após o reset coordenado, não restaram usuários, pessoas nem jobs de importação `codex-e2e-*` no banco local (contagens `0/0/0`).

## 2. Matriz de rotas

Inventário extraído de `superadmin_routes.dart`, `superadmin_router.dart`, shell e composição de autenticação: 175 `GoRoute` (79 normais, 96 `/dev` e 66 pares exatos) mais 1 `ShellRoute`, totalizando 176 objetos de rota. “Revisada” abaixo nunca significa executada quando a evidência foi somente estática.

| Família | Rota `/dev` | Rota Supabase | Fonte `/dev` | Fonte real | Operações esperadas | Spec produtiva | Status |
|---|---|---|---|---|---|---|---|
| Auth/sessão | `/dev/login`, recuperação | `/login`, recuperação | auth de desenvolvimento | Supabase Auth | login, sessão, recuperação, logout | parcial; reset segue com questão aberta | parcialmente integrada |
| Home | `/dev/home` | `/` | fixtures | sessão real + superfícies locais | leitura/navegação | home/ajuda ainda prototípicas | parcialmente integrada |
| Instituições | `/dev/institutions*` | `/institutions*` | fake | repositories Supabase | CRUD, arquivos | existente | não revisada |
| Unidades | `/dev/units*` | `/units*` | fake | Supabase/RPC/Edge/Storage | CRUD, import/export | existente | parcialmente integrada |
| Grupos | `/dev/groups*` | `/groups*` | fake | Supabase | CRUD, arquivos | existente | não revisada |
| Atividades | `/dev/activities*` | `/activities*` | fake | Supabase | CRUD, detalhe | existente | não revisada |
| Avaliações | `/dev/assessments*` | `/assessments*` | development | Supabase/RPC | gradebook/fechamento | existente | não revisada |
| Pessoas | `/dev/people*` | `/people*` | fake | Supabase/RPC | diretório/criação/edição | existente | não revisada |
| Perfis/permissões | `/dev/profiles*` | `/profiles*`, `/profile-models*` | development | Supabase/RPC/Storage | CRUD/atribuição/modelos | existente | não revisada |
| Segurança infantil | `/dev/safety*` | `/safety*` | development | Supabase/Storage privado | CRUD/autorizações | existente | não revisada |
| Saúde/cuidado | `/dev/health-care*` | `/health-care*` | development | bloqueado pelos gates canônicos | perfis/medicação | decisões incompletas | bloqueada por decisão |
| Rotina diária | `/dev/daily-routine*` | `/daily-routine*` | development | Supabase/RPC | modelos/aplicações | existente | não revisada |
| Alunos | `/dev/students*` | `/students*` | development | Supabase/RPC | diretório/gestão | existente | não revisada |
| Planos | `/dev/plans*` | — | in-memory | — | CRUD | protótipo | somente /dev |
| Cardápios | `/dev/meal-plans*` | — | in-memory | — | CRUD/modelos | protótipo | somente /dev |
| Formulários | `/dev/forms*` | `/forms*` | development | RPCs/Edge/Storage privado | lifecycle/respostas/arquivos | existente | parcialmente integrada |
| Importações | `/dev/imports*` | `/imports*` | development | RPC/Edge/Storage privado | upload/preview/confirmar | somente Unidades aprovado | parcialmente integrada |
| Convites | `/dev/invites*` | `/invites*` | development | Supabase/RPC/Edge | criar/revogar/reenviar | existente | não revisada |
| Avisos | `/dev/notices*` | `/notices*` | development | Supabase/RPC | CRUD/publicação | existente | não revisada |
| Conversas | `/dev/conversations` | `/communication/conversations` | development | RPCs/Edge aprovadas | listar/enviar/anexar | existente | parcialmente integrada |
| Agenda | `/dev/agenda*` | — | in-memory | — | eventos/solicitações | protótipo | somente /dev |
| Suporte | `/dev/support` | `/support` | protótipo | nenhum backend aprovado | tickets | explicitamente protótipo | bloqueada por decisão |
| Auditoria | `/dev/audit` | `/audit` | development | Supabase/RPC | leitura/filtros | existente | não revisada |
| Perfil/configurações | `/dev/profile`, `/dev/settings` | `/profile`, `/settings` | in-memory | perfil sem backend; preferências locais | perfil/senha/preferências | parcial | bloqueada por decisão |
| Acontece/Momentos/Agora | `/dev/principal-*` | — | development | R2 apenas quando contratado | publicação/mídia | protótipos | somente /dev |
| Erros | `/dev/errors/:code` | — | development | — | 403/404/500/503 | rota produtiva ausente | rota inexistente |
| Assiduidade | `/dev/attendance*` | `/attendance*` | development | RPCs Supabase | dashboard/chamadas/export | spec 038 | aprovada no lote reduzido |

## 3. Comparação `/dev` versus Supabase

- A composição produtiva não cria mais `SupportPrototypeController`, `InMemoryAccountProfileRepository` nem senha demonstrativa como fallback silencioso.
- `/support` e `/profile` normais agora falham fechados com 503 enquanto não houver backend aprovado. As rotas `/dev` preservam seus controllers de referência.
- Preferências de `/settings` permanecem locais por contrato, agora via `SharedPreferencesUserPreferencesRepository` em vez de memória volátil.
- Saúde/cuidado permanece indisponível em produção; nenhuma fixture é apresentada como dado real.
- Conversas, Formulários e Importações possuem adapters Supabase cobertos por testes focados, mas não receberam prova completa de CRUD binário tela + banco neste lote.
- O inventário encontrou 40 rotas `/dev` que reutilizam repositories injetados e podem atingir Supabase quando a aplicação está configurada. Isso viola a separação esperada de previews e permanece bloqueador de configuração; nenhuma rota normal caiu para fake.
- O default de `allowDevelopmentPreview` foi endurecido: `/dev` agora só habilita em build não-release com `COELO_APP_ENV=local`. Builds release permanecem fail-closed mesmo se o define de ambiente for omitido.

## 4. CRUD por tela

| Família | Create | Read | Update | Delete/ação equivalente | Reload | Evidência |
|---|---|---|---|---|---|---|
| Auth | login válido/ inválido comprovado | sessão protegida comprovada | refresh indireto por reload | logout não acionável pelo driver semântico | sessão persistiu | navegador + Supabase local |
| Home | n/a | carregou após login real | n/a | n/a | sim | navegador |
| Unidades import/export | contratos de job/preview cobertos | paginação/RPC coberta | confirmação coberta em SQL | falha/expiração cobertas por contrato | não comprovado em tela | 133 pgTAP + testes Dart/Edge |
| Formulários | adapter coberto | lifecycle coberto | adapter coberto | regras lifecycle cobertas | não comprovado em tela | testes Dart/SQL existentes |
| Conversas | envio no adapter coberto | leitura no adapter coberta | conforme contrato | conforme contrato | não comprovado em tela | teste repository |
| Suporte/perfil | bloqueado | 503 fail-closed | bloqueado | bloqueado | consistente | testes de composição |
| Alunos | comandos cobertos | RPCs instaladas, mas lint falha | comandos cobertos | conforme contrato | pendente | pgTAP 42/42; duas RPCs de leitura referenciam coluna inexistente |
| Demais famílias | pendente | pendente | pendente | pendente | pendente | não houve dupla evidência |
| Assiduidade | fora do dashboard | RPC read instalada e lint focado limpo | fora do dashboard | fora do dashboard | dashboard validado | pgTAP real 24/24 após correção dos ramos inválidos |

Não houve exclusão remota nem exclusão de dado não criado por esta execução.

## 5. Autenticação e sessão

- Login inválido exibiu mensagem genérica; login válido com identidade sintética local abriu a home protegida.
- A sessão permaneceu válida após reload da rota `/`.
- A rota protegida não foi usada sem sessão para carregar dados antes de autorização.
- O logout foi comprovado em teste focado: chama `auth.signOut()` antes de limpar a sessão e preserva a sessão com erro seguro quando o gateway falha. O clique real no navegador permanece pendente porque os controles Flutter deixaram de expor semântica após reload.
- Recuperação/reset não foi declarado completo; a questão canônica continua aberta.

## 6. RLS e grants

- As 180 tabelas remotas do schema exposto consultadas estavam com RLS habilitada; isso não prova, por si só, policies corretas ou `FORCE ROW LEVEL SECURITY` em todos os objetos.
- A migration local `20260825173604_harden_public_client_privileges.sql` revoga `TRUNCATE`, `REFERENCES` e `TRIGGER` de `anon`/`authenticated` e endurece privilégios padrão.
- O pgTAP comprova CRUD mínimo autorizado e negação de `TRUNCATE` no conjunto focado.
- RPCs de Assiduidade usam `SECURITY DEFINER`, `search_path=''`, implementação privada sem grant de cliente e wrappers públicos somente para `authenticated`.
- `student_tracking_normalize_assessment` não é mais executável por `PUBLIC`, `anon` ou `authenticated`; a função permanece interna às RPCs autoritativas.
- Não foi feita revogação global cega de RPCs.

## 7. Cross-tenant e IDOR/BOLA

- Import/export de Unidades possui testes negativos de grants, gateways legados e escopo do worker.
- Perfis passou 8/8 casos negativos e Convites passou 60/60, incluindo IDs de unidade, criança e perfil fora do tenant.
- A matriz A/B de Formulários foi executada, mas abortou no setup: `validate_form_tenant_links()` acessa `NEW.application_id` para uma tabela cujo registro não contém o campo. Download/capability/application não podem ser declarados aprovados enquanto o trigger não for corrigido.
- Assiduidade foi revalidada após corrigir os ramos reais: pgTAP 24/24, lint focado sem achados e migration canônica/espelho com SHA-256 `DF580EBBE884E03C3B7513495844F52611870826E96D785C699340C51A58A985`.
- Permanecem sem prova dinâmica completa os atores tenant A/B, guardian, teacher, admin institucional, usuário sem capability e alteração de IDs por todos os níveis.
- Os guards de assignments de Assiduidade foram revalidados nas seis combinações; a matriz cross-tenant ampla além do lote reduzido permanece dívida registrada.

## 8. Importação

- Domínio produtivo aprovado no hub: Unidades.
- Edge Functions aceitam upload binário e não payload base64; checksum usa `ArrayBuffer` compatível com Deno 2.9.
- Testes cobrem limites de ZIP/XLSX (quantidade de entradas, tamanho descompactado e dimensões), reautorização e contratos de preview/job. O gate final local de privilégios/hub/Unidades passou 133/133 e Deno passou 5/5.
- A rota `/imports` foi aberta com sessão real, mas não houve upload binário completo, preview confirmado, criação de registros e reload da tela correspondente. Nenhum arquivo com PII foi usado.
- Resultado: parcialmente integrada; gate E2E de importação real permanece pendente.

## 9. Exportação

- `unit-export` e o bridge passaram type-check; CSV/XLSX real não foi gerado, aberto nem comparado com consulta autorizada neste lote.
- No remoto somente leitura existem `unit-import@8` e `unit-export@8`, mas a Edge genérica `import-export-jobs` e as RPCs de hub chamadas pelo Flutter não estão implantadas. O fluxo produtivo atual falha fechado; não há infraestrutura remota compatível para um E2E sem aplicar migrations/deploy proibidos.
- O guard XLSX passou três cenários sintéticos de ZIP malicioso. Neutralização de fórmula está coberta por implementação/testes existentes, não por inspeção de arquivo baixado nesta execução.
- Assiduidade não possui `attendance-export` local/remota, UI de exportação, status ou download. O request RPC exige capability e cria job auditado, mas não produz sucesso aparente nem URL/download; a lacuna contra a spec 038 está fail-closed no lote reduzido.
- Resultado: gate E2E de exportação real pendente.

## 10. Storage/R2

- Contratos preservados: identidade e arquivos operacionais aprovados em Storage privado; Agora, Acontece e Momentos em R2 conforme ADR 0022.
- Import/export de Unidades usa fluxo privado e worker reautorizado. Não houve prova manual de URL assinada, expiração, download de outro tenant ou compensação de órfão.
- Nenhum bucket foi tornado público e nenhuma URL permanente foi criada.

## 11. Migrations

- Estado consolidado: 147 migrations canônicas e 147 no espelho, sem nome ausente ou divergência SHA-256. A execução local registrada acima chegou a 148 enquanto o cherry-pick isolado de Chat ainda estava presente; ele foi abortado pela coordenação após falhar nos próprios testes e não integra esta entrega.
- Histórico remoto: 103 registros; antes de qualquer `push/repair`, permanecem 68 migrations locais ausentes remotamente e 26 registros remotos sem nome local reconciliado.
- Migrations criadas neste lote: endurecimento de privilégios públicos, fechamento de gateways legados de import/export, gateway de falha escopado ao worker, revogação do normalizador de Alunos e reparo runtime de import/export de Unidades.
- Nenhuma migration remota foi aplicada.

## 12. Advisors

- Local: o gate global de `supabase db lint` manteve achados em funções de Conversas, Segurança infantil, Formulários, Alunos, Perfis, Atividades, Rotina e Perfil. Os três erros de import/export de Unidades e os três erros reproduzidos de Assiduidade foram corrigidos; o lint focado das duas funções de Assiduidade terminou com zero achados.
- Remoto, somente leitura: 207 achados de segurança (50 informativos de RLS sem policy, 156 warnings de funções `SECURITY DEFINER` executáveis por authenticated e 1 proteção contra senha vazada desabilitada) e 505 de performance (128 FKs sem índice e 377 índices não usados).
- Nenhum advisor foi silenciado. A classificação desconhecida do remoto bloqueia correção nele.

## 13. Correções realizadas

- Produção fail-closed para Suporte, Perfil, senha e saúde/cuidado; preferência local persistente para Configurações.
- Regras raiz de `.gitignore` para patches e artefatos `modified/generated`, preservando exemplos e migrations canônicas.
- Revogação de privilégios perigosos de tabelas públicas e defaults futuros.
- Fechamento dos gateways legados de import/export e exposição do gateway de falha apenas ao worker `service_role` server-side.
- Compatibilidade de digest no Deno e vínculo de falha ao `request_id` real do job.
- Correções de pgTAP para introspecção de RLS e contrato do gateway Edge; correção da fixture ZIP central directory.
- Revogação de execução pública do normalizador de avaliações de Alunos.
- Reparo forward-only do cast de auditoria, colunas válidas e overload legado do worker de Unidades.
- Testes de Rotina deixaram de tratar índices como tabelas e passaram a inspecionar a função real de hierarquia; teste de Suporte agora exige 503 fail-closed.
- Previews `/dev` foram bloqueados em qualquer build release, inclusive quando o ambiente usa o default `local`.

## 14. Arquivos alterados por esta frente

- Configuração: `.gitignore` e `apps/superadmin/lib/core/config/superadmin_app_config.dart`.
- Flutter: `superadmin_router.dart`, `account_controller.dart` e `profile_page.dart`.
- Testes Flutter: `support_routes_test.dart`, `superadmin_app_config_test.dart`, `superadmin_auth_scope_test.dart`, `account_controller_test.dart` e `profile_page_test.dart`.
- Migrations canônicas: `20260825173604`, `20260825173938`, `20260825174300`, `20260825180000` e `20260825180500`; os cinco espelhos gerados correspondentes permanecem ignorados pelo Git.
- Edge Functions: `import-export-jobs/index.ts`, `import-export-jobs/xlsx_guard_test.ts` e seu lock atualizado; `unit-import` e `unit-export` com `index.ts`, `deno.json` e `deno.lock`.
- pgTAP: `public_client_privileges_test.sql`, `import_export_hub_security_contract_test.sql`, `unit_contract_security_hardening_test.sql`, `unit_import_export_security_test.sql`, `student_tracking_security_test.sql`, `daily_routine_foundation_test.sql`, `daily_routine_scope_closure_test.sql` e `profiles_permissions_governance_test.sql`.
- Relatório: `docs/reviews/2026-08-25-coelo-supabase-screen-integration.md`.

Arquivos de Assiduidade foram apenas lidos/testados após liberação; não foram editados por esta frente. O worktree contém muitas mudanças concorrentes que não pertencem a esta lista.

## 15. Testes executados

- Flutter focado: primeira execução 31 aprovados/1 falho; após corrigir o contrato obsoleto de Suporte, 32/32 aprovados.
- Gate de configuração/router `/dev`: primeira compilação RED; após a correção, 14/14 aprovados.
- Gate cross-tenant: Perfis 8/8 e Convites 60/60 aprovados. Os três arquivos de Formulários abortaram por erro runtime do trigger antes de executar 25 dos 28 casos planejados.
- pgTAP de privilégios e import/export: 133/133 aprovados no gate final.
- pgTAP de Alunos: 42/42 aprovados após revogar o grant herdado.
- pgTAP de Rotina: 40/40 aprovados nos dois arquivos corrigidos. Perfis executou 33 casos, com 29 aprovados e 4 falhos por divergência entre o teste e as funções instaladas.
- Matriz ampla das demais famílias: 622 casos executados, 597 aprovados e 25 falhos, com 3 arquivos interrompidos por erro de fixture/assert. Esses números não são declarados como gate verde.
- Assiduidade: pgTAP real 24/24 após reset, cobrindo access/export reais e as seis combinações de assignments; lint focado das duas funções com zero achados.
- Deno: 5/5 aprovados; `deno check` aprovou as três Edge Functions.
- Analyzer focado: 9 arquivos, zero issues após remover um import redundante detectado na primeira execução.
- Formatação aplicada somente aos seis Dart da frente; quatro precisaram alteração mecânica.
- Falhas intermediárias resolvidas: 1 pgTAP de contrato desatualizado; 4 caminhos Flutter inexistentes no comando; 2 testes Deno invocados inicialmente sem `--allow-read`. Nenhuma dessas falhas permanece no gate final.
- `git diff --check` dos arquivos da frente: aprovado. O diff global emite apenas avisos de normalização de linha de mudanças concorrentes.

## 16. Pendências

- CRUD tela a tela e dupla evidência para a maioria das famílias.
- Importação binária real com preview/confirm/reload.
- Exportação CSV/XLSX real com conteúdo, quantidade, encoding, fórmulas, expiração e cross-tenant.
- Logout real no navegador; ausência de capability e matriz tenant A/B por tela.
- Corrigir os erros globais remanescentes de `supabase db lint`, com prioridade para RPCs alcançáveis por rotas normais.
- Corrigir `validate_form_tenant_links()` e repetir a matriz A/B de Formulários; o gate atual está bloqueado antes dos asserts de autorização.
- Reconciliar histórico remoto antes de qualquer operação de migration.

## 17. Bloqueios

- Ambiente remoto não classificado por fonte canônica: qualquer escrita/deploy remoto bloqueado.
- Suporte e Perfil não têm backend produtivo aprovado; rotas normais permanecem 503 fail-closed.
- Saúde/cuidado depende de decisões/gates canônicos.
- Planos, cardápios, agenda, usuários internos e superfícies Principal continuam somente `/dev`.
- Exportação de Assiduidade não tem materializador/status/download; aceita-se como lacuna do lote reduzido, sem exposição de sucesso.
- O remoto não possui a Edge/RPCs genéricas de import/export consumidas pelo Flutter; sem mutação remota, o E2E produtivo de Unidades está bloqueado e permanece fail-closed.

## 18. Riscos

- **Bloqueador:** nenhuma rota produtiva pode ser marcada como comprovada sem tela + backend; a maioria continua não revisada. Permanecem erros locais de lint em RPCs alcançáveis fora do pacote de Assiduidade.
- **Bloqueador:** 40 rotas `/dev` reutilizam repositories injetados e podem atingir Supabase local/configurado, contrariando a separação fake esperada. A exposição em release foi corrigida.
- **Alto:** importação/exportação real não completou E2E; remoto possui grande dívida de advisors e divergência de migrations.
- **Alto:** cobertura dinâmica cross-tenant/IDOR de Assiduidade ainda não cumpre a matriz da spec.
- **Médio:** logout não foi provado pelo navegador e há três índices duplicados locais.
- **Baixo:** ruído de line endings e grande worktree concorrente aumentam o risco de consolidação indevida.

## 19. Próxima ação recomendada

1. Coordenador consolidar somente os arquivos inventariados e preservar os demais owners.
2. Classificar formalmente o remoto; até lá, manter somente leitura.
3. Executar lote local E2E de Unidades com arquivo CSV/XLSX sintético, dois tenants e download expirado.
4. Completar rotas normais por família com CRUD + reload, sem ampliar protótipos.
5. Corrigir os erros de lint por família e substituir asserts estruturais por execuções dos ramos reais.
6. Preservar o contrato fail-closed de Assiduidade até existir worker, status e download de exportação aprovados.

## Gate de conhecimento

A integração não alterou regra durável aprovada além das fontes canônicas já existentes. Nenhum novo documento de memória foi criado. A revalidação de Assiduidade confirmou a conformidade técnica das regras já registradas na spec e na projeção de conhecimento.
