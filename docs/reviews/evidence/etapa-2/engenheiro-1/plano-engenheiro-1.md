---
title: Plano de trabalho — Engenheiro 1
source: Coordenador — Etapa 2 E2E; decisões do Owner; evidências locais desta tarefa
status: em andamento
generated: 2026-09-07
updated: 2026-09-07T19:58:06-03:00
---

# Engenheiro 1 — plano por tela, ação e backend

Trabalho em andamento até 2026-09-08 03:20 BRT. O coordenador controla prioridades e leases. Apenas o root desta tarefa opera Docker. Nenhuma mutação remota está autorizada nesta fatia.

PASSOS: 1/6 delimitar contrato e dependências; 2/6 reproduzir e registrar baseline; 3/6 preparar pacote nominal; 4/6 executar validação; 5/6 revisão independente; 6/6 entregar evidência e liberar o lease. O passo indica a fase desta fatia, sem representar percentual nem conclusão da tela inteira.

| Tela / componente | Subtela / ação | Passo | Backend efetivamente trabalhado | Responsável | Teste / evidência | Próximo gate |
|---|---|---|---|---|---|---|
| Infraestrutura compartilhada | Recuperar engine e executar smoke E1-ENGINE-SMOKE-01 | 6/6 — entregue | Nenhum BD nesta fatia; Docker Linux 29.7.2 | root | Imagem pg_prove por ID; /bin/true, sem rede/volumes; exit 0 e container ausente. Inventário pós-reset: 0 containers, 0 volumes, 28 imagens; três backups preservados | Manter operação serializada; nenhum novo reset |
| Infraestrutura compartilhada | HARNESS01: validar manifesto Foundation | 6/6 — entregue | Nenhum BD nesta fatia | replay_auth_rls / root | Commit 599cee50; 67 entradas e hashes; 23/23 Pester; review central aprovado | Integração controlada pelo coordenador |
| Infraestrutura compartilhada | HARNESS02: AuthOnly com adições nominais | 5/6 — review central | Nenhum BD nesta fatia | replay_auth_rls; review replay_runner | Commit 0fc17d38; 41/41 Pester; parse 3/3; review independente aprovado; worktree limpa na entrega | Review central / integração pelo coordenador |
| Auth Superadmin | Login, recuperação, refresh, logout; contexto interno e negativas | 6/6 — baseline local entregue | auth.users/sessions; app_private.superadmin_internal_auth_links/identities/memberships; RPC public.superadmin_auth_bootstrap_context e auditoria | root | E1-AUTH-01: 45 canônicas + 2 preflights; pgTAP 30/30; Lifecycle PASS; identidade coelo_safe_8ab739a5eb5a4ea8ab0d9c2eba2b2 sem containers, volumes, redes ou staging residual | Próximo pacote local nominal; não promove conclusão E2E/remota |
| Perfis e permissões | P0: isolamento das três tabelas privadas e receipts | 1/6 — fechar pacote | app_private.access_profile_catalog_versions, access_profile_command_receipts, access_profile_command_receipts_v2; trigger de catálogo; helpers de replay | replay_auth_rls; execução futura root | Dependências presentes no baseline Auth; owner BYPASSRLS observado em catálogo; wrapper v2 com ACL preexistente deve ser testado separadamente | Enviar nomes migration/testes e critérios antes de editar |
| Avisos | N01: publicação, fila e receipts | 1/6 — dependências / proveniência | public.notice_events (ausente no catálogo atual); analytics.notice_events; SQL notices_production / Notices v2 analisado; nenhum Worker executado | replay_manifest; apoio Engenheiro 2; root | Quatro prerequisites antigos; hipóteses 42P01/23502 ainda não executadas. Artefato de teste externo tem 17 asserções não executadas | Perfil e pontes nominais exatos, depois RED local autorizado |
| Usuários internos | A01: editar / suspender / reativar / revogar | 1/6 — contrato analisado | Projeção e comandos superadmin_internal_users; versões de perfil, membership e auth link; audit reason_code | replay_manifest | Divergência greatest e draft sem token original identificadas; exemplos estáticos, sem replay. Nenhuma taxonomia de motivo de sucesso aprovada | Coordenador decidir pacote nominal de token e contrato Dart |
| Formulários | F-READ01: FormsApi.listDirectory / forms.list interno | 1/6 — mapa externo em preparação | public.forms e cadeia form_versions/applications/schedules/occurrences apenas analisadas pelo Engenheiro 2 | Engenheiro 2; review replay_runner | DTO de oito campos e cursor preservados como requisito; prerequisites antigos não podem entrar via AdditionalMigration | Receber mapa e hashes; revisar perfil nominal antes de execução |

## Limites e rastreabilidade

- O baseline Auth passou localmente; não houve teste E2E de tela nem publicação remota.
- O staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a é alheio e foi preservado.
- O reset de fábrica foi uma ação externa do Owner. O inventário atual não prova preservação ou perda total do estado anterior.
- Dados remotos consultados são somente metadados de catálogo. Não há dados pessoais, credenciais ou conteúdo de tabelas neste plano.
- Nenhuma mídia/arquivo novo foi criado na plataforma. A regra de produto segue R2 privado e ADR 0032; Supabase permanece catálogo, autorizações e auditoria.
- A API de plano nativo não está exposta às ferramentas desta sessão. Este arquivo é a alternativa visível no painel direito, não altera o contador nativo de arquivos.