---
title: Plano de trabalho — Engenheiro 1
source: Coordenador — Etapa 2 E2E; decisões do Owner; evidências locais desta tarefa
status: em andamento
generated: 2026-09-07
updated: 2026-09-07T22:02:51-03:00
---

# Engenheiro 1 — plano por tela, ação e backend

Trabalho em andamento até 2026-09-08 03:20 BRT. O coordenador controla prioridades e leases. Apenas o root desta tarefa opera Docker. Nenhuma mutação remota está autorizada nesta fatia.

PASSOS: 1/6 delimitar contrato e dependências; 2/6 reproduzir e registrar baseline; 3/6 preparar pacote nominal; 4/6 executar validação; 5/6 revisão independente; 6/6 entregar evidência e liberar o lease. O passo indica a fase desta fatia, sem representar percentual nem conclusão da tela inteira.

| Tela / componente | Subtela / ação | Passo | Backend efetivamente trabalhado | Responsável | Teste / evidência | Próximo gate |
|---|---|---|---|---|---|---|
| Infraestrutura compartilhada | Recuperar engine e executar smoke E1-ENGINE-SMOKE-01 | 6/6 — entregue | Nenhum BD nesta fatia; Docker Linux 29.7.2 | root | Imagem pg_prove por ID; /bin/true, sem rede/volumes; exit 0 e container ausente. Inventário pós-reset: 0 containers, 0 volumes, 28 imagens; cinco backups preservados; recuperação reboot1 e novo smoke PASS às 20:57:58 BRT | Manter operação serializada; nenhum novo reset |
| Infraestrutura compartilhada | HARNESS01: validar manifesto Foundation | 6/6 — entregue | Nenhum BD nesta fatia | replay_auth_rls / root | Commit 599cee50; 67 entradas e hashes; 23/23 Pester; review central aprovado | Integração controlada pelo coordenador |
| Infraestrutura compartilhada | HARNESS02: AuthOnly com adições nominais | 6/6 — entregue | Nenhum BD nesta fatia | replay_auth_rls; review replay_runner | Commit 0fc17d38; 41/41 Pester; parse 3/3; review independente aprovado; integrado pelo coordenador | Preservar regressões nos próximos perfis nominais |
| Infraestrutura de Avisos | HARNESS N01PrerequisitesRed | 6/6 — validado e documentado | Nenhum BD nos testes do harness; Invoke/Prepare e descriptor fechado | replay_auth_rls writer; replay_runner review; root | RED inicial 23/23; ajuste de caminhos reproduzido; GREEN independente 77/77, parse e review aprovados. Nenhum perfil legado alterado | Entrega por commit ao coordenador; próximo seletor somente sob pacote nominal |
| Auth Superadmin | Login, recuperação, refresh, logout; contexto interno e negativas | 6/6 — baseline local entregue | auth.users/sessions; app_private.superadmin_internal_auth_links/identities/memberships; RPC public.superadmin_auth_bootstrap_context e auditoria | root | E1-AUTH-01: 45 canônicas + 2 preflights; pgTAP 30/30; Lifecycle PASS; identidade coelo_safe_8ab739a5eb5a4ea8ab0d9c2eba2b2 sem containers, volumes, redes ou staging residual | Próximo pacote local nominal; não promove conclusão E2E/remota |
| Perfis e permissões | E1-P0-RLS01: isolamento das três tabelas privadas e receipts | 6/6 — entrega local | app_private.access_profile_catalog_versions, access_profile_command_receipts, access_profile_command_receipts_v2; trigger de catálogo; helpers de replay | replay_auth_rls writer; replay_runner review; root execução | RED 18 falhas esperadas / 70 controles PASS; depois seis ALTER TABLE e GREEN 88/88 + Auth30/30. Cleanup próprio confirmado; commit 8a264c16 integrado no main 256f0370 pelo coordenador | Novo pacote nominal; nenhum remoto ou conclusão E2E |
| Avisos | N01PrerequisitesRed: pré-requisitos da publicação | 6/6 — RED de dependência reproduzido | Replay real local; ausência de public.notice_events após mudança para analytics | root; review replay_runner; apoio Engenheiro 2 | 52 arquivos preparados; erro 42P01 real na migration 20260812003000, statement22; exit1. Identidade coelo_safe_54154a03ddd946bba8e2c211dd652; cleanup independente zerado às 21:30:09 BRT | Revisão nominal separada de ponte transitória e correção final N01; sem conclusão E2E |
| Usuários internos | Contrato SQL de leitura / edição / status / revogação; replay 20260901210000 | 6/6 — validado no BD local | Replay Auth45 + Users + dois preflights; RPCs internos, memberships, auth-links, receipts e auditoria | root; fixture E2E2 e0efd98e revisada centralmente | 48 arquivos; fixture LF f19fe516 conferida em disco; 45/45 pgTAP PASS, exit0, cleanup independente zerado às 22:00:48 BRT. Não houve grant novo | Entregar evidência; token de concorrência e prova da tela Flutter permanecem recortes separados |
| Formulários | F-READ01: FormsApi.listDirectory / forms.list interno | 1/6 — pré-requisitos conferidos | public.forms e cadeia form_versions/applications/schedules/occurrences, apenas leitura estática | Engenheiro 2; replay_manifest / root | Auth45 + duas migrations Forms + dois preflights = 49 arquivos; hashes e dependências conferidos. Não foi identificada base para 42P01/23502 nesse conjunto. DTO de oito campos e cursor preservados | Receber migration, hash e teste do reader interno da E2E4; revisar pacote nominal antes de execução |
| Atividades | A01: contrato do diretório v2, base e seletor fechado | 3/6 — integração do seletor autorizada | Auth45 + sete Activities v2, 52 canônicas + dois preflights = 54; nenhum replay A01 ainda | replay_auth_rls writer; replay_runner review; root execução | RED do seletor: 26 falhas por ausência e um controle PASS. Fixture e927c417 com 89 TAP estáticos aprovada centralmente, TAP após RESET ROLE | GREEN e regressões do harness, parse e review; depois executar a reserva local54 autorizada com a fixture exata |

## Limites e rastreabilidade

- O baseline Auth passou localmente; não houve teste E2E de tela nem publicação remota.
- O staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a é alheio e foi preservado.
- O reset de fábrica foi uma ação externa do Owner. O inventário atual não prova preservação ou perda total do estado anterior.
- Dados remotos consultados são somente metadados de catálogo. Não há dados pessoais, credenciais ou conteúdo de tabelas neste plano.
- Nenhuma mídia/arquivo novo foi criado na plataforma. A regra de produto segue R2 privado e ADR 0032; Supabase permanece catálogo, autorizações e auditoria.
- A API de plano nativo não está exposta às ferramentas desta sessão. Este arquivo é a alternativa visível no painel direito, não altera o contador nativo de arquivos.