---
source: ADR 0038; R13-pendencias.md; ETAPA-2-estado-atual.md; AGENTS.md
status: prompt de execução autorizado pelo Owner em 14/09/2026
generated_at: 2026-09-14
---

# Prompt — resolver a R13 e avançar a Etapa 2

Cole o bloco abaixo numa conversa nova (Claude Code, checkout `dev`
consolidado). Ele abre a execução da fila R13 com as decisões da ADR 0038 já
tomadas; não reabre perguntas respondidas.

```text
$coelo-frontend-backend

Recorte: Etapa 2 › apps/superadmin › fila vigente R13 (H02–H28 + owner.r12-* abertos), com as decisões da ADR 0038 (decisions/0038-owner-decisions-etapa2-backlog-20260914.md) já tomadas — não reabrir nenhuma pergunta respondida nela nem no adendo. Modo padrão: resolver pendências até prova E2E, não auditar.

Ordem obrigatória:

0. Abertura (1 checkpoint, sem perguntar tempo): git fetch/status, worktrees e stash; confirmar SHA de dev; ler ADR 0038, R13-pendencias.md, ETAPA-2-estado-atual.md e os cabeçalhos/linhas afetadas dos três rastreadores. Listar o recorte, ordem, critério de parada e primeiro gate de cada item. Usar somente sintéticos qa-r06-* já existentes.

1. Backend primeiro — fila SQL liberada (ADR 0038: Decisão 8 mantida; dump lógico local fora do Git antes de cada lote, SHA-256 registrado). Aplicar em produção na ordem serial, com pgTAP verde no espelho reconstruído pela ordem real (ordem-de-aplicacao-producao.txt) e ledger preenchido:
   a. os quatro candidatos locais retidos desde a R11 (owner.r12-51);
   b. pacotes novos decididos, um por família, cada um com revoke explícito + grant mínimo e negativa cross-tenant no pgTAP:
      - chat: revoke_message_v2 recusa CHAT_READ_ONLY (H06); limite 10 anexos por mensagem no prepare (ADR 0038); asset_id aditivo no envelope de authorize_read + deploy da Edge Function chat-media (spec 028);
      - cuidado: capacidade care_policies.manage nos perfis de sistema Owner/Administrador da instituição e remoção do papel fixo em superadmin_unit_care_policy_set_v1 (H17);
      - medicação: responsáveis elegíveis = guardiões autorizados e equipe no escopo; eventos novo/alteração/suspensão + lembrete 30 e 15 min antes; só sino (owner.r12-33, H19);
      - segurança infantil: pessoa global sem conta com nome, sobrenome e CPF (HMAC) obrigatórios, demais opcionais, dedupe por CPF, autorização pendente de revisão (owner.r12-18);
      - cardápios: remover prioridade explícita e datas excluídas do contrato; bloquear sobreposição ao salvar (owner.r12-36/37);
      - avisos: RPC de duplicar para novo rascunho com auditoria de origem (H08);
      - catálogos globais de tipo (instituição, unidade, turma, atividade) por migration idempotente por code, com Outros + texto livre e troca de tipo permitida (OQ-031, listas na ADR 0038);
      - planos: readers no principal interno 039, só leitura (open-questions); conta: reader self com platform.read (open-questions); suporte: mapeamento de status A (OQ-028);
      - circular: limite 4.000 no total somando blocos (H21; spec 037 atualizada).
   Auth: adicionar localhost à allowlist de redirect (owner.r12-47). SMTP próprio, senha do banco, token Cloudflare amplo, DNS e arrobas reservados ficam para o fechamento do MVP — não tocar.

2. Front-end e E2E por tela, na ordem que fecha mais gates com menos retrabalho, cada ação provada pela régua do MVP (rota normal abre, CRUD persiste no Supabase real, RLS nega outro tenant, reload mantém):
   - Publicação › Circular: compositor segue a referência inteira aprovadas-20260911/circular-web-1440 (shell, rodapé em card contornado, contador 4.000 total, Opções com toggle), blocos intercalados no host produtivo (H04), regravar os seis goldens web (H21/R07-CIRC-RODAPE);
   - Comunicação › Avisos: Duplicar; atualização mantendo a lista + barra fina de progresso, e registrar esse padrão em coelo-ui para todas as listas (H23); CTA das notificações abre o detalhe do item por tipo (H13);
   - Formulários: preservar todas as regras de audiência e autosave do autor via authoringApi (H10/H11); local interno com IDs fixados na publicação e revisão conservando valor histórico; H12 e H26 por contrato atual;
   - Saúde e Cuidado: múltiplos registros de alergias/orientações, nome da criança na edição, inputs padronizados, visão de medicação por período/contexto, responsáveis e notificações (owner.r12-28 a 33); H19/H20 provados;
   - Segurança infantil: wizard de pessoa sem conta (owner.r12-18); lista 1440 sem alteração (owner.r12-10 fechado);
   - Acessos › Perfis e permissões: owner.r12-19 a 27 e o desenho de R12-23 (perfis profissionais para uso no Principal): revisar spec 018, propor o catálogo de capacidades finas do Principal (publicar Momentos/Agora, responder chat, ver turma…) e só então SQL;
   - Cardápios: telas sem Prioridade/Datas excluídas ligadas ao contrato novo; mídia de cardápio e foto de perfil no contrato R2 (owner.r12-38/46);
   - Coelo (Principal): saudação por hora do dia e ponto laranja em Momentos (H27); avatar do Perfil com anel laranja que abre o Agora (P54/V-1 no MVP); Sobre conecta a atualização oficial (H02); H03/H24/H28 por referência vigente;
   - Convites/Auth: owner.r12-44/45/47/52 pela rota normal; Agora: medir a expiração agendada real (H09);
   - Demais owner.r12-* abertos na ordem do catálogo, distinguindo implementável de já fechado pela ADR 0038 (r12-02 modelos Coelo imutáveis; r12-53 sem opcionais; plans.assign fora do MVP).

3. Regras fixas: um Chrome e um flutter test por vez; teste antes do código; menor implementação; analyze/lint; evidência por apps/superadmin → menu → tela → subtela → action_id; atualizar inventário e os três rastreadores no mesmo turno de cada correção; deltas só em arquivo no formato de apply-tracker-delta.cjs; FE verified, BE done e verified-e2e contados separadamente; nada promovido por mock, /dev, golden ou fixture. Segredos só no secret store; nenhum valor em chat, commit ou log.

4. Meta obrigatória: os percentuais canônicos de ETAPA-2-estado-atual.md (base 14/09: FE 151/231, BE 159/224, E2E 125/199, Owner items 3/53) têm de SUBIR nesta execução, e só sobem por prova de runtime nova — rota real no Chrome contra o Supabase de produção, pgTAP no espelho e reload — registrada por action_id com data, SHA e ambiente. Alteração apenas documental (ADR, rastreador, spec, skill, "decidido") não muda estado nem conta como avanço; um item "fechado pela ADR 0038" só sobe de estado quando a tela/RPC foi provada. Cada checkpoint informa o delta dos três percentuais e dos Owner items desde o anterior; três checkpoints seguidos sem delta obrigam a trocar de gate, não a relatar. Não reclassificar, arquivar ou excluir ação para inflar denominador.

   Checkpoints de até quatro linhas a cada subtela fechada e a cada lote SQL aplicado. Se um gate externo travar (só Cloudflare fora da Decisão 5 ou custo), registrar o bloqueio com responsável e seguir nas ações independentes. Não iniciar Etapa 3.

5. Fechamento: gate de memória da coelo-knowledge (fonte canônica antes da projeção), specs revisadas por ADR 0038 (018, 020, 028, 037, 039/051, notices-mvp-design, locais-mapas, forms-end-to-end), skills no checkout de destino, validate-trackers.cjs, commit em dev, push, delivery_gate.py e o relatório PASS COMPLETE ou PASS DOCUMENTED_PARTIAL com o que ficou aberto e por quê. Continuar enquanto houver item implementável no recorte; parar só por bloqueio demonstrado ou fim da fila.
```
