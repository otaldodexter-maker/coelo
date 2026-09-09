---
source: "R02 D04 assignment r3; specs/030-superadmin-child-safety-production.md; R01-fechamento-integracao.json; git 720f739e"
status: "local-corrections-tested; visual-gate-open; internal-read-sql-candidate-unexecuted"
generated_at: "2026-09-09"
---

R02 D04 Segurança infantil, revisão 4. Início 14:19 BRT; checkpoint 14:59 BRT. Agente filho /root/child_safety, modelo não exposto/confirmado. Worktree C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d04-acessos, branch codex/e2-r02-d04-acessos, base inicial 56eb3f19d. Sem commits próprios; pai serializa Git/push/integração. Sem acesso/mutação remota. Slot Flutter liberado; nenhum processo próprio ativo.

Recorte: apps/superadmin → Acessos → Segurança infantil → lista, criança, criar, editar e suspender → child-safety.list/child/create/edit/suspend. Família administrativa: Instituições para diretório e Criar/Editar Instituição para formulário. Objetivo: reutilizar cadeia preservada e fechar inconsistências executáveis. Fora: compartilhados, SQL, outros apps, produção, contas/convites reais e exportações adiadas. Ordem: cadeia/contratos, RED, correção, testes focais, handoff. Corte 16:30; depois somente consolidação. Delta funcional local inspecionado concluído; E2E depende de personas, cutover de identidade e operação nominal remota.

### Reuso e alterações

Reutilizados oito paths Safety finais de 720f739e: controller/decoder/pages e cinco testes. Cadeia nominal do manifesto R01: e2224800,0548c65f,7dd2deea,288171ca,27e48477,6c03563f,7aede603,f8c83929,720f739e. Motivo held: revisão/integração conjunta pendente. Histórico 103PASS não convertido em resultado atual. Helpers novos são internos, sem dependências novas de features/contratos externos.

Reuso inclui invalidação por contexto/dispose/negação, limpeza de opções, payload inválido, preservação de intenção idempotente e recuperação da recarga sem reenviar comando confirmado. Wrap da cadeia segue institution_directory_cards.dart e elimina crash IntrinsicHeight/LayoutBuilder; golden permanece aberto, sem atualização.

| ID | Delta local | Primeiro gate aberto |
| --- | --- | --- |
| child-safety.list | Tabela usa authorizationCount autoritativo sem depender de detalhes ausentes; reuso busca/debounce. | Golden 2,47%; pessoas autorizadas e leituras reais cruzadas. |
| child-safety.child | Reuso descarta criança/controlador anterior e conteúdo após negação; decoder não atribui contexto desconhecido à primeira unidade. Lifecycle desconhecido não vira ativo; inactive permanece Inativa. | Detalhe/negação/reload no app normal e backend. |
| child-safety.create | Reuso protege buscas, callbacks, saves confirmados e recarga sem duplicação. | Seleção produtiva de adulto global: ainda exige UUID manual, lookup contratado ausente. |
| child-safety.edit | Somente pendente abre edição; criança/pessoa imutáveis, conforme RPC que só altera relação/capacidades/validade/motivo. | Mutação/reload/auditoria reais; identidade legível sem UUID técnico. |
| child-safety.suspend | Reuso protege contexto após negação; fluxo existente confirmar/cancelar/versão/reload passa localmente. | Persistência, negações por autoridade e auditoria reais. |

Novidades R02 sobre cadeia: enum lifecycle inativo/indisponível, decoder lifecycle/context fallback, tabela count, guard pending e identidade imutável na edição; oito novos testes. Nenhuma rota/bootstrap/SQL/tracker/global/golden alterado.

### Evidências e métricas

Logs nesta pasta, Flutter/Dart local Windows, fixtures sintéticas; não certificam E2E. Logs ignorados por Git precisam preservação nominal pelo pai.

- D04-safety-red.log: oito cenários, seis RED de produto, um PASS já atendido pela cadeia e um RED de expectativa de título corrigida para estado existente.
- D04-safety-green.log: produção Wrap com novidades R02; 112 cenários P110/F2. Uma falha finder RawTooltip/IconButton, outra golden 2,47%/35525px.
- D04-safety-edit-rerun.log: somente correção finder, P1/F0. Contagem única combinada da revisão Wrap P111/F1/B0/S0/U0, N112; execução112/112; aprovação111/112=99,11%. Não somar reruns.
- D04-safety-analyze.log: lib/features/safety e test/features/safety, sem problemas.
- D04-safety-golden-original-layout.log: experimento para preservar HEAD, IntrinsicHeight causou 21 exceções de dimensões intrínsecas de LayoutBuilder; dois cenários F2 (golden/responsividade). Experimento removido, não é produção final. Wrap restaurado; prova golden única final concluída em D04-safety-golden-final.log, F1 por 2,47%/35525px, exit1.
- D04-safety-visual-contracts.log: bloqueio global preexistente location_schedule_section.dart:292 DropdownButtonFormField cru, fora ownership Safety; nenhuma ocorrência Safety, allowlist intacta.
- git diff --check Safety sem erro.

Capturas inspecionadas em apps/superadmin/test/features/safety/presentation/failures/child_safety_directory_light_1440_{masterImage,testImage,isolatedDiff,maskedDiff}.png. Actual 14:33:16 ainda Wrap (reinspeção confirmou); experimento IntrinsicHeight terminou 14:33:54 antes de escrever nova imagem. Bounds dos cards preservados; conteúdo interno desloca 2–4px e status cerca de 24px à esquerda; divergência também menu inferior. Fonte Ahem de teste não prova tipografia real. Baseline não atualizada. Nova captura final preservada após rerun em handoffs/D04-safety-visual-evidence/{masterImage,testImage,isolatedDiff,maskedDiff}.png; esta é a evidência final a revisar.

FE/BE/E2E novos certificados 0/5,0/5,0/5; manter pending-verification nos cinco IDs. Plano E2E mínimo: cinco fluxos/reload/negações, todos bloqueados por personas/cutover/produção nominal; separado de N112 local. Backend histórico não revalidado. Geral Etapa2 não recalculado por filho; D00 centraliza inventário/matrizes.

### Contratos residuais

Create exige lookup server-side de adulto global existente, minimizado id/nome, reautorizado em criança/unidade, paginado e com mínimo de busca; validar novamente no request. Pai confirmou ausência produtiva reutilizável. Não criar picker fictício ou conta. Edit_pending não troca pessoa/criança/contexto.

Realm atual é legado: current_person_id somente foundation 20260623191021:782 lê person_auth_links por auth.uid; has_platform_permission última definição 20260729144440:51 usa platform_memberships.person_id. assert_child_safety_platform usa esses helpers. Não inferir que conta interna D01 funciona: falta cutover ADR0019; não ligar identidade interna a People artificialmente. Leitura child_safety.read; gestão child_safety.manage ou authorized_people.manage contextual; guardião manage_authorized_people solicita/edita própria pendente, não decide/suspende. Contratos enviados ao filho Convites para pacote de personas. Teste SQL existente child_safety_production_test.sql plan 63 não reexecutado.

Knowledge consultado via script e fontes. AAL2 histórico está superado por AAL1/MFA adiado; nenhuma exigência nova criada. Memória no-op: nenhuma regra nova de produto; correções cumprem contratos existentes. Próximo passo pai: revisar integração da cadeia e gate visual, preservar provas; pacote nominal lookup/cutover/personas para E2E. Filho disponível para correções de consolidação até corte.

Checkpoint final local: HEAD compartilhado bb8e5f70d mais WIP Safety; manifesto D04-safety-final-manifest.json contém SHA256 dos 17 Dart da feature e confere integralmente após o golden final. Resultados únicos da revisão final: P111/F1/B0/S0/U0 em 112; F1 visual permanece. Logs convertidos para UTF8 sem alteração do conteúdo. Nenhum processo próprio ativo, slot liberado ao pai e a Profiles. Commit/push de Safety continuam responsabilidade do pai; integração não declarada.

### Diagnóstico focal final do golden — revisão 4

O F1 permanece falha de baseline incompatível com alterações compartilhadas anteriores, não uma regressão visual própria demonstrada do Wrap. Nenhum código foi alterado nesta investigação; nenhum teste Flutter adicional foi executado. Pai concordou preservar alvo de toque de 48 px e publicar Safety separadamente como held-golden, sem promover FE/E2E.

Golden Safety foi atualizado por último em b943a5feb, antes de a0be1abeb. Este último alterou CoeloAdminExpandableStatusIndicator para alvo mínimo de 48 px com LayoutBuilder. O documento docs/reviews/evidence/etapa-2/estruturas/2026-09-08-location-shared-status-accessibility.md registra explicitamente que a caixa maior altera a ocupação vertical de cards. SafetyChildDirectoryCard não mudou entre a geração do golden e essa baseline integrada.

Comparação somente leitura dos pixels: 35.525 divergentes = 31.895 nos interiores dos três cards + 3.630 no shell, apenas bbox (39,784)–(253,818) do menu Coelo (Principal). Toolbar, criar, exterior dos cards e restante: zero. A disponibilidade/navegação Coelo (Principal) mudou depois da baseline; não é alteração de Safety. Dentro dos cards, cabeçalhos comparados com deslocamento (0,+2) e corpo com (0,+4) coincidem pixel a pixel nos três cards. Os status coincidem com deslocamento (-24,+2), exceto quatro pixels de antialias. Essas diferenças correspondem à caixa de toque 48 px do shared status: aumentar header de 44 para 48 desloca o centro 2 px e corpo 4 px. O círculo visual continua 24 px.

Assim, reduzir localmente a caixa para satisfazer a imagem antiga violaria o contrato de acessibilidade. Reintroduzir IntrinsicHeight já demonstrou crash. Wrap mantém composição e bounds externos; nenhuma correção local adicional é indicada. Evidência quantitativa em D04-safety-golden-diagnosis.json; imagens finais preservadas em D04-safety-visual-evidence/. Nenhuma baseline atualizada.

Manifesto final SHA256: 811a7734570897811b263eb87682e27105beeb9b15210019135d1492aab35027. Rechecados 17 arquivos Dart, 0 alterados desde o manifesto da revisão testada. Recursos próprios encerrados; sem slot Flutter retido. Commit/publicação held-golden será realizada pelo pai; não declarada realizada pelo filho.

### Retomada nominal de leitura interna — revisão 5, 15:37 BRT

Owner/pai ampliou explicitamente o recorte para preparar pacote SQL local independente. A exclusão de SQL descrita no contrato inicial aplica-se à revisão anterior, não a esta retomada. Preparados `20260909190000_d04_child_safety_internal_reads.sql` e `d04_child_safety_internal_reads_test.sql`: três RPCs v2 com guard interno por capacidade, plataforma global, AAL1 vigente, audit tipado, allowlists, pre/postflights e legado preservado. Nenhuma alteração nova em Flutter, rotas, bootstrap ou golden.

Contrato, aceites e lacunas exatas estão em [D04-child-safety-internal-reads.md](D04-child-safety-internal-reads.md). Hashes e parse estático estão em [D04-safety-internal-reads-static.json](D04-safety-internal-reads-static.json). Plano SQL distinto: P0/F0/B0/S0/U43. Sem slot SQL próprio, sem Docker, testes de banco ou nova execução Flutter. O parse estático não prova compilação, grants efetivos nem runtime. Resultado Flutter anterior P111/F1 permanece separado e não é usado para certificar o pacote novo.

Primeiros gates: revisão independente do delta, replay SQL serializado, compatibilidade da assertion histórica de wrappers invoker, contrato coerente de limite nome/cursor, autorização nominal remota e ativação FE posterior com indisponibilidade honesta das mutações legadas. Lookup adulto e cutover de escrita continuam separados por FKs de atores/receipts People. Nenhuma ponte entre realms, política nova, conta real ou chamada remota foi criada. Nenhuma ação foi promovida a FE/BE/E2E concluída.

### Adapter interno isolado — revisão 6

Nova retomada explicitamente autorizada pelo pai às 15:45 BRT produziu `SupabaseInternalChildSafetyRepository` e teste HTTP próprios, em dois arquivos novos da feature. Não ativado no bootstrap/router; repository legado, decoder, domínio e golden preservados. O adapter consome somente as três RPCs v2, desempacota envelopes com erros tipados, valida identidade/contexto de respostas, força `canCreate=false` e recusa todos os comandos sem rede ou fallback legado.

Rodada final do adapter: P34/F0/B0/S0/U0, somente HTTP sintético, e análise estática de dois arquivos sem issues. REDs provaram reads ausentes, códigos Auth PGRST301/302 e nested shapes permissivos, incluindo contexto `{}`. Histórico e motivo material de cada rerun estão no handoff específico; não somar esses resultados ao N112 anterior nem ao SQL U43. Dois arquivos congelados para revisão/commit do pai, slot Flutter liberado diretamente a Profiles; nenhum processo próprio ativo. Manifesto novo separado: `D04-safety-internal-adapter-manifest.json`. A ativação produtiva, o replay SQL e o fechamento E2E continuam abertos.

### Compatibilidade do teste legado — revisão 7

Assignment D00 r4 canônica de 16:15 lida; reserva ampliada autoriza o teste histórico exatamente afetado pelo SQL48141. Aplicado `D04-safety-legacy-test-proposal.patch` somente em `child_safety_production_test.sql`: três wrappers v2 explicitamente excluídos da assertion de invoker legada, mantendo seu teste próprio de definer/ACL. Parse estático P em 72 statements e diff sem whitespace errors; nenhuma execução SQL, Docker ou Flutter. Runtime novo U43 preservado, plano histórico 63 não executado nesta retomada. Detalhes/hash no handoff nominal; migration e adapter congelados intactos. Pai serializa commit.
