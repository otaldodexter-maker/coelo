---
source: "specs/030-superadmin-child-safety-production.md; specs/039-superadmin-internal-auth-session-context.md; decisions/0019-superadmin-internal-identity.md; migrations 20260812002200, 20260901200206 e 20260908195512; autorização nominal do pai D04 em 2026-09-09"
status: "local-candidate; sql-runtime-unexecuted; remote-and-frontend-activation-held"
generated_at: "2026-09-09"
---

Pacote D04 de leituras internas de Segurança infantil. Recorte adicional autorizado às 15:25 BRT, depois do fechamento visual local. Não modifica o candidato Flutter held-golden nem seu manifesto de 17 arquivos. Migração nominal: `packages/coelo_database/migrations/20260909190000_d04_child_safety_internal_reads.sql`. Teste nominal: `packages/coelo_database/supabase/tests/d04_child_safety_internal_reads_test.sql`.

Apps/superadmin → Acessos → Segurança infantil → lista, detalhe e busca de criança → `child-safety.list`, `child-safety.child` e dependência de `child-safety.create`. Objetivo: preparar a leitura pelo realm interno, sem pessoa sintética nem concessão nova. Fora: ativação Flutter, mutações, lookup de adulto, evidência assinada, exportação, SQL remoto e contas reais. Parada: pacote nominal revisável, testes locais definidos e gates explícitos. Execução SQL continua U porque o slot local pertence a D00.

### Contrato executável

| RPC nova | Entrada | Resultado de sucesso |
| --- | --- | --- |
| `superadmin_child_safety_directory_v2` | Mesmos seis parâmetros tipados da directory legada: busca, instituições, unidades, segmento, limite e cursor. | Envelope interno com agregado anterior, contagens antes do cursor, segmentos exclusivos e `can_create=false`. |
| `superadmin_child_safety_search_children_v2` | Busca de 2–120 caracteres e limite de 1–20. | Envelope interno com lista minimizada de crianças e contextos. |
| `superadmin_child_safety_get_v2` | `p_child_id uuid`. | Envelope interno com detalhe solicitado; não existência e indisponibilidade de recurso retornam negação equivalente. |

Cada wrapper possui `SECURITY DEFINER`, `search_path=''` e EXECUTE somente para authenticated. O dispatcher e as três queries privadas não concedem execução a PUBLIC, anon, authenticated ou service_role. A autorização deriva exclusivamente de `require_superadmin_internal_context('child_safety.read')`, antes da primeira consulta de domínio. Não exige papel Owner: o teste positivo usa papel sintético com somente essa capacidade. Escopo plataforma global preserva o limite anterior de `has_platform_permission`; memberships institucionais ficam negadas até contrato de consultas filtradas. O helper vigente aceita AAL1/AAL2, conforme aditivo de 01/09 da ADR 0019.

O dispatcher revalida contexto/sessão antes da resposta, registra sucesso com ator interno tipado e negação com o helper canônico v2/v3. Falha de audit aborta a RPC. Nenhuma busca, nome, payload infantil, locator de mídia ou segredo vai para o audit. O envelope usa `ok/data/error` e códigos SAI existentes; o transporte não presume que HTTP 200 significa sucesso.

As consultas derivam de 20260812002200, sem chamar seus guards legados. Diretório reforça o join unidade/instituição. Filtros de IDs aceitam até 100 entradas por array, uma dimensão e nenhum elemento nulo. Cursor preserva null e `{}` como primeira página; exige chaves conhecidas e strings para os três campos quando presente. Não foi inventado máximo de `cursor.name`: ele provém de `people.display_name`, sem máximo físico encontrado. Impor 120/4096 quebraria cursor válido emitido pelo servidor. Um limite total coerente de nome/cursor permanece item de revisão contratual de payload antes de ativação; não é disfarçado como prova de segurança concluída.

Restrições e alertas agora usam allowlists explícitas dos campos retornados pelo contrato anterior. Evidência permanece somente metadado: sem bucket, object_path, checksum ou ator legado. Não há assinatura/download novo. Preflight verifica contexto, helpers de audit, RLS forçada e ausência de grants diretos sensíveis, triggers de integridade ativos e ACL privada do helper. Postflight verifica proprietário alinhado à fundação interna, definer, search_path e ACLs dos sete objetos novos. Snapshot transacional compara definição/proprietário/ACL das funções legadas para provar que o pacote não as alterou.

### Aceites e testes

O arquivo pgTAP contém fixtures sintéticas transacionais e rollback: leitor interno sem papel Owner em AAL1; nove crianças entre duas instituições; página de oito mais cursor final; filtros/segmentos; detalhe; restrição, alerta e evidência não vazios; minimização; audit sem busca/nome; falta de capacidade; instituição negada antes da validação de busca; membership suspensa; auth link revogado; sessão expirada; ausência de identidade; ator global separado em AAL2 com grant legado negado na v2; ACLs privadas/públicas. Não executa convite, provisionamento real nem objeto remoto.

P/F/B/S/U do runtime SQL: P0/F0/B0/S0/U43, base do candidato local desta retomada. Esse N não inclui nem altera os 112 casos Flutter anteriores. Parse externo SQL é verificação estática, não runtime: migration e teste parseados com pglast. As três funções privadas de dados também passam pelo parser PL/pgSQL; o dispatcher usa tipo composto app_private que o parser isolado não resolve (`LookupExplicitNamespace only supports pg_catalog and public`). Compilação dessa função no Postgres continua U. Nenhum teste Flutter, golden, Docker ou SQL foi repetido.

Revisão independente final de `/root/profiles_models`: sem bloqueante estático adicional no delta de pre/postflight, ACL, allowlists e fixtures. Pai complementou o parse: oito blocos CREATE/DO aceitos; somente dispatcher limitado pelo namespace do parser. Nenhum corpo foi substituído para mascarar a limitação. Hash final da migration: `0e451a3b6d0c0f398ac4efa243d4c1896f4925d12a50a0d3638bd22a6c3bca51`; teste: `c4ab2c919dfc18e55c0d513658cf9f8df0e4e4edf7364a3418a14ef1cb2a0e50`. Metadados em `D04-safety-internal-reads-static.json`. Rechecados também os 17 Dart do manifesto anterior, zero alterações.

### Gates antes de aplicação e ativação

1. Revisão independente do delta SQL e replay local serializado completo, incluindo os pre/postflights e os 43 aceites pgTAP. Confirmar fixtures e semântica no schema integrado; parse não substitui compilação nem execução.
2. Ajustar nominalmente o teste histórico `child_safety_production_test.sql`: sua assertion ampla de que todo wrapper Safety é SECURITY INVOKER inclui os v2 por prefixo. O contrato v2 canônico exige definer com helpers privados. Preservar a assertion para as interfaces legadas e testar as novas separadamente, sem enfraquecer ACL. Proposta executável em `D04-safety-legacy-test-proposal.patch`, validada com `git apply --check`, ainda não aplicada. Esse arquivo não foi alterado fora da propriedade autorizada.
3. Resolver o limite coerente do cursor com o contrato de nomes sem rejeitar nomes válidos existentes. Não alterar People ou políticas de produto silenciosamente.
4. Autorizar nominalmente a aplicação remota forward-only deste arquivo, na ordem/dependências comprovadas. Não foi solicitada nem executada mutação remota pelo filho.
5. Somente depois de RPCs disponíveis e comprovadas, ativar adapter FE próprio: trocar apenas as três leituras por nomes v2 e desempacotar o envelope; mapear erros SAI antes de decoder; não converter erro em lista vazia. Fazer teste focal de transporte/envelope/contexto. O código FE atual permanece intacto, pois essas RPCs ainda não existem no ambiente produtivo conhecido.
6. A ativação de leitura deve apresentar honestamente indisponibilidade dos comandos ainda legados, inclusive editar/suspender no detalhe e links diretos. `can_create=false` por si só não cobre essas ações. Não alegar fechamento de criação/edição/suspensão com este pacote.

### Gate de escrita e lookup adulto

Spec 030 autoriza criação administrativa reutilizando adulto global existente; para responsável, exige ownership/verificação institucional. Não foi criada política de descoberta de adultos ou ponte entre realms. O cutover de escrita exige colunas de ator interno explícitas e receipts internos: `child_safety_command_receipts.actor_person_id`, `created_by_person_id`, `decided_by_person_id` e atores de restrição/alerta/evidência referenciam People. Substituir somente `current_person_id()` por UUID interno viola as FKs e a ADR 0019.

Próximo pacote mínimo de escrita deve manter caminho contextual de responsável/unidade separado, introduzir receipt interno com ator/request_hash/response próprios e audit v2, preservar lock/versão/idempotência e criar wrappers internos nominais de solicitar/editar pendente/suspender. A transição não pode usar `OR` entre grants legados e internos. Aprovar/rejeitar permanece comando de unidade conforme spec 030. Lookup administrativo de adulto deve reutilizar contrato de Pessoas somente se houver interface minimizada aprovada e disponível; o repository global indisponível não constitui essa interface. Essas dependências estão abertas, não certificadas.

Conclusão FE/BE/E2E adicional: 0/0/0 ações promovidas. Ganho local concreto: pacote independente de leitura interna materializado e testes nominais preparados. Sem conhecimento de produto novo aprovado; gate de memória no-op, fontes canônicas preservadas.
