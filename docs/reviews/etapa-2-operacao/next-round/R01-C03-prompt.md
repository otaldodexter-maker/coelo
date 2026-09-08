---
title: "Prompt de abertura E2 R01 C03 — Operações"
source: "Owner R01; docs/reviews/coelo-etapa-2-coordenacao.md; docs/reviews/inventario-etapa-2.json; AGENTS.md"
status: "active"
generated_at: "2026-09-08T12:19:18-03:00"
timezone: "America/Sao_Paulo"
---

# Cole este prompt na sessão Codex

Nome desta conversa: E2 R01 C03 — Operações. Use este nome na interface quando houver ferramenta e registre seu ID real no handoff; não invente ID.

Você é executor da Etapa2 R01 do Coelo e deve implementar suas telas e ações ponta a ponta, testar e produzir seus próprios commits. Modelo/nível planejados: GPT-5.6 Sol / high; confirme a seleção real. Não é apenas auditor ou consultor.

Abra e trabalhe exclusivamente em `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c03`, branch `codex/e2-r01-c03-operacoes`, base herdada `6cb8ba15bae15f5a6129b0db6e740a66f8f82b3f`. A worktree já foi preparada; confira cwd, branch, HEAD e alterações antes de editar. Não crie worktree duplicada nem sobrescreva trabalho existente.

Leia AGENTS.md e RTK.md. Use coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, ponytail e rtk. Ao revisar Dart use flutter-dart-code-review; para SQL/RLS/Supabase use skill oficial Supabase e supabase-postgres-best-practices. Para Cloudflare use o plugin Cloudflare/skill cloudflare; cloudflare-manager só nas operações de gerenciamento aplicáveis. Tutor somente por pedido didático do Owner. Referências conforme trabalho, sem reiniciar cadeias.

Leia DIRETAMENTE na C00, mesmo que exista cópia na sua branch:
1. `C:/Users/adrie/Documents/Coelo.worktrees/e2-c00/docs/reviews/etapa-2-operacao/PROTOCOLO.md`
2. `C:/Users/adrie/Documents/Coelo.worktrees/e2-c00/docs/reviews/etapa-2-operacao/assignments/C03.md`
3. bloco operacional R01 de `C:/Users/adrie/Documents/Coelo.worktrees/e2-c00/docs/reviews/coelo-etapa-2-coordenacao.md`.
Cruze cabeçalhos, seus action_ids, dependências e evidências dos três rastreadores, specs/ADRs e código preservado. Somente Superadmin e dependências; Principal é menu interno, não apps/principal. Não ampliar para apps/admin/apps/site.

Sua ordem inicial: Atividades A01/runtime → Avaliações v2 → recuperar delta visual de Agenda → Cardápios → Assiduidade/Rotina/Auditoria/Suporte → Planos conforme contrato → Catálogo e indisponibilidade honesta dos adiados.
Reaproveitamento obrigatório: A01 97/97 pgTAP local e adapter já integrado; Avaliações possui migration v2 20260901182838. Agenda reader/controller integrados: recuperar somente view ca4c82ab, corrigindo quatro diferenças golden; nunca aprovar imagens automaticamente. Planos 051 aprovado para catálogo manual, mas identidade039 e activate/assign exigem reconciliação.
Dependências: C04 para seleção de Locais; C02 para mídia de eventos/atividades/cardápios; C01 para contrato interno039. Catálogo: conferir host Superadmin e ferramentas existentes antes de propor N/A backend; não inventar CRUD/tenant de catálogo de componentes.

Confirme revisão R01-C03-I001 no primeiro handoff e continue. Cada action_id tem dono exclusivo e classe; respeite reservas de arquivo na assignment/protocolo. Router/composition roots/barrels/migrations/Media Gateway/componentes centrais exigem escritor único. C02 mantém o núcleo de mídia, C04/C05 consumidores. Não crie outro gateway.

Você pode implementar Flutter, domínio, adapters, backend e testes dentro do ownership, com reserva nominal para migrations e arquivos compartilhados. Preserve segurança, acessibilidade e comportamento; componentize quando barato e útil, dívida explícita para refatoração ampla. Não aprovar goldens automaticamente. `pending-verification` não significa refazer código.

Cada executor publica somente seu próprio documento operacional de entrega em `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c03/docs/reviews/etapa-2-operacao/handoffs/C03.md`. Frontmatter com fonte/status/data. Registre rodada, conversa/ID real, revisão, última instrução, timestamp com fuso, branch/baseline, SHAs de código, push verificado, IDs/arquivos, testes/ambiente/resultado, evidências minimizadas, bloqueios, primeiro critério aberto, próximo passo, ETA fundamentada e proposta de delta FE/BE/E2E. Atualize no mesmo turno de mudança. Não editar os três rastreadores, inventário, coordenação, assignments ou relatórios C00.

Faça commits pequenos próprios e push em `origin/codex/e2-r01-c03-operacoes`, verificando a ponta. Não faça merge, force-push, push em dev, migration/deploy remoto. C00 integra em dev conforme autorização do Owner. Todo remoto é produção. Localhost deve ligar ao Supabase real; mutações somente nos cenários/personas/janelas nominalmente autorizados por C00 com aprovação Owner existente. Sem autorização, preparar/testar localmente e reter só a operação dependente. Não provisionar contas remotas ou usar credenciais pessoais. Personas sintéticas e tenants A/B, sem segredos/logs brutos.

FE pode ser certificado sem BE; BE sem UI; E2E exige UI normal → backend real (incluindo R2/Stream aplicáveis) → persistência/reload e negativas. `/dev`, fixture, mock, fail-closed, golden ou teste isolado não certificam E2E. Forms inclui mídia e único XLSX do formulário inteiro; outros import/export reais adiados.

Continue lotes independentes sem aguardar confirmação a cada ação. Consulte assignment nos limites dos lotes, respeite novas revisões e publique progresso quando mudar. Registre ferramenta/build em andamento para evitar falsa ociosidade. Use continuidade nativa espaçada disponível na sua sessão, com ID/cadência/limites verificados; Claude consulta instruções usando seu mecanismo local. Markdown não acorda sessão e não há ponte Codex–Claude por teclado/API paga.

Horários America/Sao_Paulo: janela08/09/2026 12:20 até16/09/2026 12:20; handoffs12:50/14:50/17:30 em08/09; fechamento09/09 05:30; até06:00 entregar commits, push verificado, handoff final, evidências, pendências, WIP separado e comandos exatos de retomada. Pare lotes/loops R01 após fechamento seguro; não espere mensagem para respeitar esse corte. R02 virá da C00.

Comece agora pelo menor delta comprovado do seu primeiro lote. Não pare em recomendações.
