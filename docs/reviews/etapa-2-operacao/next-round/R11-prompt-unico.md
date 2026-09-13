---
source: Owner 2026-09-13; AGENTS.md; R10-fechamento.md; Principal-pos-R10.md; inventario-etapa-2.json
status: preparado; execução da R11 ainda não iniciada
generated_at: 2026-09-13
---

# R11 — Estrutura e recuperação de senha, com consumo limitado

Você é C0, executor e integrador da R11 da Etapa 2 do Coelo.
Modelo GPT-6 Astra, esforço medium. Este prompt, quando enviado para execução,
autoriza executar a R11 até seu corte e publicar as fatias concluídas.
Não iniciar R12 nem Etapa 3 automaticamente.

## Objetivo e recorte

Concluir o maior conjunto coerente de ações possível dentro da cota real,
priorizando problemas reproduzidos e provas que reutilizam código já integrado.
Recorte: apps/superadmin > Meu perfil/Conta, Auth e menu Estrutura >
Atividades, Avaliações e Turmas. Coelo (Principal) é outro menu hospedado: preservar suas correções.
Não interpretar esta rodada como auditoria de todas as 231 ações.

A R10 e a extensão posterior estão encerradas. Base entregue antes desta
preparação: 60499468e; código do build preservado: 01833e90b.
Confirme origin/dev na abertura; a preparação do prompt terá commits posteriores.
Não voltar a uma base antiga só porque um handoff cita outra worktree.

## Primeiro gate executável: base, posse e orçamento

1. Repositório C:/Users/adrie/Documents/Coelo. Faça git fetch origin;
   confira HEAD, origin/dev, status, stash, worktrees e processos de runtime.
   Use checkout consolidado limpo por padrão. Atualize por fast-forward seguro
   se necessário, preservando ignorados. Se houver divergência/trabalho alheio,
   preserve e reconcilie antes de escrever; não reset/clean/force-push.
2. Leia AGENTS.md e aplique os caminhos canônicos:
   - .agents/skills/coelo-ui/SKILL.md
   - .agents/skills/coelo-supabase/SKILL.md (coelo-backend)
   - .agents/skills/coelo-flutter-review/SKILL.md (coelo-frontend)
   - .agents/skills/coelo-flutter-supabase-review/SKILL.md
   - .agents/skills/ponytail/SKILL.md
   - .agents/skills/rtk/SKILL.md
   - .agents/skills/coelo-knowledge/SKILL.md para memória.
   Reutilize leituras já válidas; carregue referências por recorte, sem ciclos
   de releitura ou auditoria global de skills.
3. Consulte R10-fechamento.md, R10-estado-por-tela.md, Principal-pos-R10.md,
   R10-consolidacao.md e os action_ids afetados no inventário/três rastreadores.
   R10-pendencias.md é histórico: referências à worktree removida e ao picker
   bloqueado foram superadas pela consolidação e pela prova posterior.
4. Registre T0 real, SHA, escritor C0, PID/porta do runtime e posse dos slots
   em R11-checkpoint.md. Consulte consumo real com:
   rtk proxy python docs/reviews/evidence/etapa-2/r09-coordenacao/read-codex-checkpoint.py --quota
   Registre indicador, janela e reset; não invente percentual se não houver leitura.

## Cota e tempo: o primeiro corte prevalece

O Owner informou cerca de 12 pontos percentuais disponíveis, não uma medição.
Na preparação o leitor reportou 87% usados; medir de novo ao executar.
Para esta nova rodada, registre U0 = consumo usado real na abertura e calcule:
- teto absoluto da R11 = min(U0 + 12 pontos percentuais, 98% usados);
- congelar novas fatias quando faltar 3 p.p. para esse teto;
- reservar esses 3 p.p. para testes finais, integração, MDs, push e fechamento;
- buscar terminar pelo menos 1 p.p. antes do teto; antecipar pelo ritmo real.
Os cortes numéricos da R10 ficam históricos; estes são os cortes da R11.
Se não houver margem operacional, somente preservar/fechar e registrar o limite.
Não usar reset de cota para estender a rodada silenciosamente.

Medir na abertura, a cada 10 minutos, em cada entrega e antes de build caro.
Janela máxima: T0 + 3 horas de execução e até 30 minutos de fechamento,
sempre dentro da cota. Isso é máximo, não tempo a consumir obrigatoriamente.
Sem meta artificial de +7 a +9 p.p.; medir apenas aceites realmente fechados.
Execução serial C0 é o padrão econômico; não iniciar enxame de auxiliares.

## Ordem focal e aceites

### A0. Meu perfil e cabeçalho — account.profile

Prioridade acrescentada pelo Owner após a preparação inicial. Ler
`docs/design/account-profile-owner-adjustments-20260913.md`.
Na UI o formulário mostra foto selecionada, mas o cabeçalho continua com sigla;
nome também foi apontado como possível falha, ainda a reproduzir.
Confirmar primeiro antes/depois de Salvar e reload: prévia local não é foto
persistida. Depois de sucesso real, cabeçalho deve refletir foto/nome da mesma
conta no shell e no Principal hospedado, inclusive após navegar/recarregar.
Não usar valor fixo nem aceitar identidade residual ao trocar sessão.

A lista longa Meu acesso empurra Salvar para o fim da página. Aplicar o rodapé
de ações padrão acessível no contêiner; limitar altura de Meu acesso, com
rolagem interna, busca e agrupamento de permissões por módulo e escopo/hierarquia
que o catálogo/backend realmente informar. Preservar leitura apenas, teclado,
scroll mobile e texto ampliado, sem rolagem aprisionada ou botão encoberto.
Explicar capacidades de funções adiadas sem prometer operação disponível.
Não criar papéis/permissões nem alterar autorização por ajuste de apresentação.
Agrupamento visual não substitui tenant/ownership/RLS. Provar salvar/cancelar,
nome/foto no header, busca/grupos e reload antes de declarar corrigido.

### A. Recuperar/redefinir senha — auth.recover, auth.reset

Primeiro faça uma inspeção curta do fluxo/configuração e da caixa sintética
acessível. Abra Esqueci minha senha pela tela de login normal, solicite para
uma conta sintética autorizada, receba a mensagem real e use o link na UI.
Prove nova senha, nova sessão, expiração/uso único e comportamento seguro para
endereço inexistente. Nunca mostrar token/link de recuperação/credencial nos
logs, prints ou MDs. Preserve a identidade de QA compartilhada e coordene
invalidações; atualizar o arquivo privado se houver troca de senha autorizada.

Não substitua entrega SMTP por link gerado via Admin API como certificado.
Pedido aceito pela API não prova chegada à caixa. Se depender de acesso de
caixa/DNS/provedor ausente, registre o bloqueio preciso e siga Estrutura;
não gastar a rodada inteira esperando ou repetindo envio. Inspeção inicial
máxima de 20 minutos sem evidência nova, depois mudar para ação independente.

### B. Configuração avaliativa — activities.assessment; activities.publish

Reproduza menu Estrutura > Atividades > configuração/avaliação no mesmo
rascunho retido (prefixo b04c879e, localizar ID completo na evidência).
Esperado: UPDATE salva o mesmo registro e reload mantém períodos/configuração.
Observado na R10: SAI_INTERNAL_ERROR; payload Dart/replay local passaram.
Contexto platform era válido: não presumir falta de membership institucional.
Capture causa/SQLSTATE sanitizados por observabilidade autorizada; corrija
contrato/cliente no ponto causal e prove pela rota normal.
Não criar outro rascunho para contornar o defeito. Não reaplicar SQL61/62/63.
Provar salvar/publicar atividade se a correção fechar essa cadeia.

### C. Diário e notas — assessments.entry, gradebook, detail, close, reopen

Reutilize configuração, período e diário retidos (diário prefixo d2c945d8).
O aluno já tinha contexto/unidade/turma ativos; investigar participante da
atividade e snapshot do diário, especialmente activity_group_participants.
Esperado: aluno elegível aparece, recebe nota, detalhe/diário relidos mantêm
resultado; fechar/reabrir respeitam estado e versão. Provar RLS/escopo real.
Não duplicar vínculos nem recriar diário/configuração para obter um caminho verde.

### D. Contadores de Turmas — groups.list

Card de turma sintética mostrou zero alunos/atividades enquanto vínculos
existiam. Comparar RPC/projeção/repository/renderização; corrigir fonte causal
com filtro de status e hierarquia do contrato vigente. Provar UI e reload.
Não tratar o aceite anterior da listagem como prova de contadores corretos.
Esta ação é independente: antecipar se a cadeia avaliativa ficar bloqueada.

Se Conta/Auth e os três blocos de Estrutura terminarem com margem, escolher somente uma ação
vizinha executável: institutions.status ou institutions.locations-map.
Não ampliar para outro macrotema para aumentar contagem. Diante de bloqueio,
registrar causa e seguir o próximo bloco independente dentro da cota.

## Runtime, segurança e execução

Um Chrome e um flutter test globais, com posse/PID explícitos. Não fechar o
Chrome do Owner. Build/analyze/testes pesados serializados; não reconstruir
runtime enquanto alguém estiver executando prova nele.
Usar http://127.0.0.1:3000: origem já autorizada de mídia. A porta 3016 falhou
CORS; isso não significa falha do upload. Host iniciado na preparação teve
PID17204; conferir se ainda existe, não presumir posse ou processo atual.
Build preservado em apps/superadmin/build/principal-pos-r10, SHA JS:
c9c94dbe88812c7c8e1792dfdf0000efd425d747ae4ca96ae6587d5129607d97.
Novo build só quando código mudar, com manifesto SHA/ambiente e prova conjunta.

Ponytail: reutilize contratos/componentes, corrija a causa, faça testes focais
pertinentes; não acrescente abstrações/dependências nem repita lotes verdes sem
mudança material. RTK nos comandos. Regra visual conforme coelo-ui; preservar
contêiner, cabeçalho, avatar, seletor branco, card de mídia e launcher Principal.

Somente C0 aplica SQL/deploy no escopo autorizado da ADR0034. Migrations
forward-only, pgTAP local verde, ordem serial e backup PITR verificado antes da
aplicação. Confirmar autorização nominal de qualquer recurso Cloudflare fora
do pacote aprovado. Nenhum segredo no cliente/Git/log/URL. Todo remoto é produção;
apenas dados sintéticos autorizados. API isolada não certifica UI/E2E.

## Referência de chat: preservar na Etapa 2, fora da prioridade R11

Ler docs/design/chat-media-composer-owner-reference-20260913.md.
Anexos do Owner orientam foto inline maior, prévia de vídeo com play/duração,
mosaico de múltiplas mídias e campo de escrita em cápsula, menos reto.
A direção está registrada; não conta como render aprovado nem implementação.
Não alterar globalmente formulários administrativos por esse apontamento.
Se não couber, manter a pendência para rodada posterior da Etapa 2, sem perder
anexos/referência ou iniciar redesign oportunista na R11.

## Checkpoints e entrega sem perdas

A cada 10 minutos, fatia entregue e antes de interrupção/compactação:
- atualizar e commitar checkpoint com SHA, telas/action_ids, prova, WIP,
  consumo real, slots, bloqueio e próximo passo;
- comitar pequenos deltas revisáveis e fazer push em dev sem force;
- atualizar inventário/matrizes via docs/reviews/apply-tracker-delta.cjs;
- validar os três rastreadores. Distinguir FE verified, BE done e E2E;
  não converter testes locais ou PNG de outro domínio em aceite genérico.

Ao fechar, criar R11-fechamento.md e R11-pendencias.md com cada tela/subtela,
FE/BE/E2E, primeiro gate, responsável, provas, testes únicos P/F/B/S/U,
consumo inicial/final, tempo, commits, runtime/build/deploy e WIP preservado.
Reportar sete métricas vigentes, denominadores e ponte com a base, sem inflar
avanço por mudança de escopo. Registrar decisões ainda abertas separadamente.

Atualizar docs/reviews/entrega-atual.json com todos os pedidos desta rodada;
conferir skills/referências no destino, memória coelo-knowledge e executar
python -X utf8 docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
após commit/push. PASS DOCUMENTED_PARTIAL exige dizer o que falta.

Uma worktree ativa por escritor. Se criar isolamento, integrar o delta revisado
por merge real; preservar branches, commits exclusivos, stash, sintéticos e
ignorados importantes antes de arquivar. Não reaplicar histórico nem fazer
merge vazio para fingir consolidação. Só declarar entregue depois de push e
conferência de divergência ativa. Push não é deploy.

Comece pelo gate da base/consumo e siga ao primeiro fluxo executável.
Não parar apenas com plano, auditoria ou pedido de status enquanto existir
trabalho autorizado executável dentro do corte.
