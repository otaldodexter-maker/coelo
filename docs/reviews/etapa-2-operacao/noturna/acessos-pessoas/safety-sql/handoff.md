---
source: "parent /root assignment; 48141c195; f84db0412; 963796ddf; R02 D04-child-safety-internal-reads.md; specs/030-superadmin-child-safety-production.md; ADR0019; Auth45 manifest; ChildDirectoryEnvelope profile"
status: "materialized-and-statically-parsed; runtime-unexecuted; remote-held"
generated_at: "2026-09-09"
---

# Safety SQL e adapter — revisão 1

Etapa2 → apps/superadmin → Acessos → Segurança infantil → diretório/detalhe/busca → `child-safety.list`, `child-safety.child`, dependência de `child-safety.create`. Provedor: Supabase/Postgres. Trabalho adicional atribuído ao filho `/root/safety_visual`, na worktree/branch noturna Acessos. Pai mantém runner SQL e Git; nenhum SQL, container, recurso remoto, bootstrap ou shared foi executado/alterado pelo filho.

Recorte: materializar três SQL nominais e dois Dart, identificar dependências reais e preparar ensaio local; corrigir exclusivamente o preflight do candidato ainda não aplicado para recusar envelope incompatível. Fora: escrita Safety, lookup adulto, cursor com política nova, Forms, exportação real, Storage/R2 e ativação de UI. Parada: fixture nominal revisável e primeiro gate executável definido. Resultado atual é preparação e parse, não PASS de banco.

## Materialização e delta

Reuso de `48141c195`: migration `20260909190000_d04_child_safety_internal_reads.sql` e teste `d04_child_safety_internal_reads_test.sql`. Reuso de `f84db0412`: `child_safety_production_test.sql`, com somente três wrappers v2 excluídos da assertion histórica invoker. Reuso de `963796ddf`: `supabase_internal_child_safety_repository.dart` e teste homônimo. Todos nos paths Safety próprios, sem snapshot global/cherry-pick.

Única alteração nova de produção é seis linhas no preflight da migration candidata. A existência de `superadmin_internal_error_envelope(text,uuid)` não prova que suporta `SAI_INVALID_ARGUMENT`: Auth45 contém uma versão anterior que o transforma em `SAI_INTERNAL_ERROR`. O guard agora executa o helper com código não sensível e recusa o pacote com mensagem nominal se o resultado não preservar esse código. Nenhum helper compartilhado é redefinido pelo pacote.

O handoff R02 citava `20260908195512_forms_superadmin_operations_read_v2.sql` como dependência, mas esse arquivo apenas consome o envelope. A definição com `SAI_INVALID_ARGUMENT` está em `20260827235500_superadmin_internal_institution_list_filter.sql`, linhas20–57, fora de Auth45. Não trazer Forms ou a listagem inteira para suprir um helper. A fixture reutiliza o bridge já revisado de `ChildDirectoryEnvelope`, que extrai esse corpo exato e verifica seus hashes antes/depois.

## Fixture local exata

`prepare.py` não acessa banco/rede. Verifica manifesto Auth45 e hashes da base/bridge, materializa cópias byte-idênticas em `fixture/` (ignorada por Git, fontes preservadas), extrai o DO real do candidato para os testes nominais e emite `manifest-before.json`/`manifest-after.json` com ordem,53 paths e SHA256 bruto/CRLF. Executar a partir da worktree com `rtk proxy python docs/reviews/etapa-2-operacao/noturna/acessos-pessoas/safety-sql/prepare.py`.

Plano:50 migrations canônicas = Auth45 +4 históricas Safety + candidato1; dois preflights herdados; bridge1. Total53. Ordem por versão, conforme manifesto-after:

1. Auth45 e preflights herdados, intercalando os quatro históricos Safety abaixo na ordem nominal.
2. `20260812002000_child_safety_schema.sql`: schema, capacidades e triggers. A omissão histórica de labels depende do bridge de labels local já herdado. Não presumir essa omissão permitida em produção.
3. `20260812002100_child_safety_read_models.sql`: guard e wrappers legados usados pela closure/teste legado.
4. `20260812002200_child_safety_security_closure.sql`: integridade mais estrita, revoke direto, policies, comandos e leituras legadas.
5. `20260825193116_final_review_child_safety_lint_hardening.sql`: versão atual de edição/decisão legadas. Não é exigida pelas três queries v2, mas mantém a regressão legado no estado real em vez de provar versão obsoleta.
6. Completar os quatro arquivos Auth mais novos, até `20260901200206`, sem mudar política AAL1 vigente.
7. Bridge `replay/profiles/ChildDirectoryEnvelope/20260908051499_child_directory_error_envelope_bridge.sql` (SHA256 CRLF `6f9342ccad9ce145158e1667a84c5bd58e4577af022204194280b4d8cfaad17a`), somente após Auth45.
8. Rodar `preflight-before-test.sql` (controle RED esperado: lives passa e ausência do guard faz a assertion de rejeição falhar) e `preflight-after-test.sql` (P2 esperado). Ambos usam o DO real extraído e restauram o envelope Auth45 somente dentro de transação com rollback; não são migrations de produção.
9. Aplicar o candidato `20260909190000`, incluindo pre/postflight; rodar teste interno43 e legado63 transacionais. Não rodar import/export ou objetos Storage reais.

O wrapper central atual não aceita históricos anteriores à boundary via AdditionalMigration. Pai/coordenador precisa integrar essa seleção nominal sob reserva; este filho não alterou `Prepare-SafeMigrationReplay.ps1`, `Invoke-SafeLocalMigrationReplay.ps1` nem profiles compartilhados. Os53 arquivos estão materializados, mas não houve tentativa de contornar seus guards ou iniciar replay independente.

## Produção e invariantes preservadas

A lista histórica acima existe somente para recriar uma base local descartável. **Não é uma lista de deploy remoto.** Produção exige comprovar Safety schema/closure atuais, Auth039/AAL1 e audit interno, RLS forçada, ausência de grants diretos, triggers, owner/ACL e envelope compatível, então autorizar nominalmente apenas o novo pacote e eventual prerequisite de envelope ainda ausente. Nenhuma autorização remota foi herdada.

Os históricos criam bucket Storage/export legado para fidelidade da fixture. Isso não reativa esses fluxos no MVP e não redefine ADR0032. O candidato novo não cria/altera buckets, policies Storage, objetos, jobs ou RPC de exportação. Seu preflight exige RLS/no-direct-grants e seu snapshot/postflight compara definições/owners/ACLs legadas, incluindo funções de exportação Safety, para impedir alteração silenciosa. O adapter só consome as três leituras v2 e delega todos os comandos ao repository indisponível, sem rede/fallback, forçando `canCreate=false`. A composição de edição/suspensão ainda deve mostrar indisponibilidade antes de ativação produtiva.

Cursor: tipo/chaves/UUIDs e filtros têm validação; `cursor.name` segue `people.display_name` sem teto físico conhecido. Não introduzido limite arbitrário que invalide cursor emitido pelo servidor. Limite coerente do contrato permanece gate anterior à ativação. Lookup de adulto global continua ausente; não há criação de conta ou ponte de realms. Escrita exige atores/receipts internos porque as FKs existentes apontam People; não basta trocar o helper de identidade. Aprovação/rejeição contextual e política MFA permanecem próprias.

## Evidências e estado

`manifest-before.json` registra os bytes originais R02 antes da correção. `manifest-after.json` registra fonte atual e fixture53. Parse pglast8.4: migration16 statements, teste interno107, legado72, cada teste preflight8. Parse SQL não compila todos os corpos PL/pgSQL nem prova grants efetivos, RLS ou execução. Runtime atual separado: interno P0/F0/B0/S0/U43; legado P0/F0/B0/S0/U63; guard P0/F0/B0/S0/U2. Controle before não foi executado nem contado como falha comprovada. O filho não repetiu os34 HTTP verdes da R02.

- Migration antiga SHA256: `0e451a3b6d0c0f398ac4efa243d4c1896f4925d12a50a0d3638bd22a6c3bca51`.
- Migration nova SHA256: `6fa99c60eb0343e4539a876b74d89a3121ed8fce0a0640051c41ff8f52fe5999`.
- Teste interno43 SHA256: `c4ab2c919dfc18e55c0d513658cf9f8df0e4e4edf7364a3418a14ef1cb2a0e50`.
- Teste legado63 SHA256: `6d6c53a69b5abf9c1ae79a40c86673984fba7516a419859223ff65d03d0fbe01`.
- Adapter SHA256: `e587c09130c55f4ba3e26d38f70d849711e11a900adb48a72602b43138eae8e2`.
- Teste adapter SHA256: `49609d2c66f98e25a6ed7e54ef801128011cffe862846b624de69da79eb3fd69`.

Os dois Dart foram comparados ao commit963796ddf, conteúdo idêntico com normalização de finais de linha. P34 histórico continua evidência reutilizada, separado de qualquer resultado novo. Diff-check atual sem erro. Nenhuma ação FE/BE/E2E promovida; próximos gates: replay serializado e erros descobertos nele, review independente, contrato cursor e operação remota nominal, composição normal read-only e provas reais de negação/reload.

MCP Supabase descoberto com `search_docs`, `execute_sql`, `apply_migration` e demais ferramentas; apenas documentação consultada, sem acesso ao projeto ou credenciais. Skill oficial e boas práticas lidas; [documentação de funções](https://supabase.com/docs/guides/database/functions) consultada para EXECUTE/search_path, changelog obtido. Nenhuma API nova ou alteração temporal relevante foi introduzida. Cloudflare fora do pacote. Memória no-op: correção técnica de dependency guard não altera regra de produto; pai centraliza validações de memória.

## Complemento da entrega visual publicada

Pai publicou visual em `3a96ca535` e inspecionou as imagens. Após pedido dele, os três logs UTF16 foram convertidos para UTF8 sem BOM, sem rerun. Comparação textual com `git show 3a96ca535:<path>` decodificado em UTF16 foi verdadeira nos três; nenhum conteúdo foi alterado. Hashes UTF8: `analyze.txt`=`a525d89ca8ab64b6910324a30d0e75c49d10cc452a544491866486aacc92c416`; `focal-before.txt`=`eca680ba166d4292a036ce8091cac9537830fd94af9852f91ed08aeb00b97efa`; `presentation-green.txt`=`27110571bdfc42137452f918cffeedc94fb1d42b3267fecc964f4f8a284f9cc4`.

Filho sem runner/servidor/container/porta/stash próprios. WIP atual identificado: cinco paths Safety SQL/Dart, correction guard e artefatos desta pasta, mais conversão dos três logs visuais. Commit/push do novo lote pertencem ao pai; não declarados publicados por este handoff. Fixture ignorada é regenerável de fontes/hash nominais e não contém dados nem credenciais.
