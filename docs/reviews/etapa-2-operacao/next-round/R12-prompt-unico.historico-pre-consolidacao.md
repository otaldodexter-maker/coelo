---
source: Owner 2026-09-13; R12-plano-de-rodada.md; R13-plano-de-rodada.md; AGENTS.md
status: pronto para execução mediante envio; R12 não iniciada nesta preparação
generated_at: 2026-09-13
---

# R12 — Correções focais com consumo limitado

Você é C0, executor e integrador da R12 da Etapa2 do Coelo. Use GPT-6 Astra,
esforço medium, execução serial. Este prompt, quando enviado para execução,
autoriza implementar, testar e publicar as fatias deste recorte em dev até o
corte. Após fechamento e liberação de posse, acionar R13 pelo supervisor Luna
descrito abaixo, conforme autorização posterior do Owner. Não iniciar Etapa3. Não pedir confirmação do
recorte já definido nem encerrar apenas com plano enquanto houver trabalho
independente executável dentro da cota.

## Base e skills obrigatórias

Repositório `C:/Users/adrie/Documents/Coelo`. Leia AGENTS.md e RTK.md. Aplique:

- `$rtk`: `.agents/skills/rtk/SKILL.md`;
- `$coelo-ui`: `.agents/skills/coelo-ui/SKILL.md`;
- `$coelo-backend`: `.agents/skills/coelo-supabase/SKILL.md`;
- `$coelo-frontend`: `.agents/skills/coelo-flutter-review/SKILL.md`;
- `$coelo-frontend-backend`: `.agents/skills/coelo-flutter-supabase-review/SKILL.md`;
- `$coelo-knowledge`: `.agents/skills/coelo-knowledge/SKILL.md`.

Reutilize leituras válidas; referências somente pelo recorte. Use ponytail para
reaproveitar componentes, sem abstrações/dependências novas. coelo-ui é a
autoridade visual; preservar contêiner, cabeçalho, avatar, seletores e Principal
hospedado. Use RTK nos comandos. Manutenção de plano não inicia auditoria global.

Faça fetch origin; confira HEAD/origin-dev, status, stash, worktrees e processos.
Use checkout consolidado por padrão, fast-forward seguro quando necessário;
preserve WIP/ignorados e reconcilie divergência antes de escrever. Sem reset,
clean, force-push ou reaplicação de histórico. Não use SHA antigo como destino
só porque aparece num handoff. Confira skills no checkout entregue.

Leia `R12-plano-de-rodada.md`, `R12-owner-items.json`,
`R12-sincronizacao-rastreadores.md`, `R13-plano-de-rodada.md` e
`R13-pendencias.md` em `docs/reviews/etapa-2-operacao/next-round/`.
Consulte inventário e três rastreadores somente nas ações afetadas.

O catálogo conserva53 compromissos. **Nesta R12 executar somente R12-07,
R12-41 e R12-43**; destinationRound identifica a divisão vigente. Os outros50
já estão na R13. Notas antigas que atribuíam tudo à R12 são históricas.

## Primeiro gate: orçamento e posse

Antes do trabalho de produto, confirme o disparo independente já preparado:

```text
rtk proxy python docs/reviews/etapa-2-operacao/next-round/r12-luna-dispatch.py status
```

Leia R12-disparo-luna.md. Se expirado/cancelado, execute `arm` para uma nova
espera e confira `status`; não reaproveite sinal antigo. Se houver execução
running, não assuma a posse. O teste já documentado dispensa nova chamada
de modelo sem mudança material. O processo espera até 12h, sem consumir
modelo. Sua criação não inicia R12/R13 nem muda estados de produto.

Registre T0 real, base/SHA, escritor C0, PID/porta do runtime e dono dos slots em
`R12-checkpoint.md`. Meça consumo real:

```text
rtk proxy python docs/reviews/evidence/etapa-2/r09-coordenacao/read-codex-checkpoint.py --quota
```

Preparação:92% usados, janela10080min, reset1789820315. Isso é histórico;
registre U0 real ao abrir. O Owner informou cerca de8p.p. restantes:

- teto R12 = min(U0 + 6p.p., 98% usados);
- congelar novas fatias a teto - 2p.p.; reservar esses2p.p. para verificação,
  integração, documentos, transferência dos abertos e push;
- procurar fechar1p.p. antes do teto quando possível; se não houver margem
  operacional, preservar/fechar, sem iniciar correção que não caiba;
- medir a cada10min, em cada entrega e antes de build caro;
- máximo T0+2h de execução e30min de fechamento, sempre dentro da cota;
  tempo/cota são limites, não metas a consumir;
- se o leitor falhar, não inventar percentual. Sem indicador válido, suspender
  novas fatias e registrar a limitação. Reset não estende a rodada silenciosamente.

Um Chrome QA e um flutter test globais; build/analyze/test pesado serializados.
Não fechar Chrome do Owner. Runtime preferencial `http://127.0.0.1:3000`.
Snapshot R11: Python39272/3000, QAChrome31192/CDP9427, OwnerChrome18924;
confirmar existência/posse, não presumir. Build preservado r11-account-v3,
código d20bcfcf2; novo build só quando código mudar, com manifesto SHA/ambiente.

## Ordem de execução

### 1. R12-07 — Chamada: espaçamento do erro

apps/superadmin > Acompanhamento > Assiduidade > Chamada > falha ao salvar;
action_ids attendance.mark, attendance.correct, attendance.finish.
Fonte: `R12-apontamentos-owner.md`, anexo7.

Inspecione `apps/superadmin/lib/features/attendance/attendance_pages.dart`,
`_AttendanceCommandErrorBanner` e os usos de feedback. Já existe padding interno;
reproduza antes de corrigir o encaixe/margem externa. Use composição canônica,
preservando rascunho, mensagem, recuperação e rodapé. Prove desktop/mobile,
texto ampliado, teclado e ausência de botão encoberto.

Não ampliar para persistência/sentimento R12-08, que está na R13. Se surgir
falha funcional independente, registre causa/prova/primeiro gate e continue
o acabamento quando possível. Não chamar gravação corrigida por ajustar banner.

### 2. R12-41 — Formulários: filtros Situação/Período

apps/superadmin > Operação > Formulários > Diretório; action_id forms.list.
Fonte: `R12-formularios-agenda-owner.md`, anexos2–3.

Inspecione `apps/superadmin/lib/features/forms/presentation/directory/forms_directory_page.dart`.
Reproduza truncamento e quebra de Limpar/Aplicar. Reutilize filtros canônicos;
preserve seleção múltipla e parâmetros do repository. Prove aberto/fechado,
aplicar/limpar/período, resultado filtrado, foco, compacto e texto ampliado.
Não incluir editor, renomeação de seção ou arraste, destinados à R13.

### 3. R12-43 — Conversas: contorno

apps/superadmin > Comunicação > Conversas > lista/conversa;
action_id chat.open. Fonte: `R12-chat-contorno-owner.md`.

Inspecione `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`.
Reproduza continuidade da borda entre lista, paginação, painel e compositor,
com cantos, vazio e scroll, desktop/compacto, claro/escuro. Corrija o contorno
ou clipping causal com tokens existentes, sem contêiner redundante nem borda
indiscriminada nas bolhas. Preserve navegação e leitura normal.

Mosaico/foto/vídeo/compositor R12-52 permanece na R13. Não redesenhar o chat
inteiro nem enviar mensagens a terceiros para provar acabamento.

## Segurança e provas

Todo Supabase/Cloudflare remoto é produção. Só sintéticos autorizados. Não há
alteração SQL ou Cloudflare prevista neste recorte. PITR, quatro candidatos SQL
R11, SMTP, foto R2, notas/contadores e demais apontamentos têm destino R13;
a divisão não resolve bloqueios nem concede autorização remota nova.

Testes existentes e comandos focais estão no R12-plano-de-rodada.md. Execute
casos pertinentes aos aceites, revise os renders alterados e prove pela rota
normal. Após verdes, avance; repetir/ampliar somente por mudança material.
Screenshot/golden/local-green/API isolada não certifica E2E. Não fabricar
aprovação visual A ou tratar herança histórica como prova atual.

## Checkpoints, entrega e abertos para R13

A cada10min, entrega e antes de interrupção/compactação: atualizar checkpoint
com código, provas, consumo, WIP, slots, bloqueio e próximo passo; fazer commits
pequenos e push dev sem force. Atualizar inventário/três matrizes pelo
`docs/reviews/apply-tracker-delta.cjs`, preservando camadas/certificações válidas.

No corte, criar `R12-fechamento.md` e `R12-pendencias.md`: por item/ação, FE/BE/E2E,
primeiro gate, responsável, provas, testes únicos P/F/B/S/U, consumo inicial/final,
tempo, commits, runtime/build/deploy e WIP. Informar sete métricas e ponte com
a base sem inflar avanço. Registrar quais ajustes já foram entregues mesmo
quando a ação integral continuar aberta, evitando refazê-los na R13.

Atualize os estados reais em entrega-atual.json e R12-owner-items.json. Depois
de registrar o fechamento real com status encerrada, execute:

```text
rtk proxy python docs/reviews/etapa-2-operacao/next-round/transferir-abertos-r12-r13.py --preview
rtk proxy python docs/reviews/etapa-2-operacao/next-round/transferir-abertos-r12-r13.py --apply
```

O procedimento transfere os selecionados ainda abertos, mantendo IDs, estados,
provas e bloqueios; preserva os50 itens já planejados da R13. Conferir a lista
exata e atualizar os MDs. Não marcar item incompleto como concluído para evitá-lo
na transferência. Nenhum item aberto pode ficar sem destino.

Concluir memória coelo-knowledge: fonte canônica primeiro, projeção apenas se
houver regra durável; no-op fundamentado quando não houver. Reconciliar Git,
stash/worktrees/ignorados, skills no destino; commit/push autorizado, depois:

```text
rtk proxy python -X utf8 docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
```

FAIL bloqueia conclusão; PASS DOCUMENTED_PARTIAL exige informar o que falta.
Conferir HEAD/origin-dev no final. Push não é deploy. Encerrar a R12 com a
lista transferida para R13. Como ÚLTIMO comando de escrita/coordenação desta
rodada, após encerrar seus comandos de runtime/testes e conferir o gate, execute:

```text
rtk proxy python docs/reviews/etapa-2-operacao/next-round/r12-luna-dispatch.py release --release-writer
```

Esse comando valida fechamento real, transferência, checkout dev limpo,
HEAD=origin/dev e delivery gate antes de emitir sinal atômico. Após sucesso,
não escreva mais no checkout; envie somente a resposta final. O supervisor
iniciará uma sessão exclusiva conforme R13-luna-continuacao.md, acompanhará
sua saída e poderá retomá-la uma vez na reserva Luna médio. Não lançar outro
CLI manualmente. Não sinalizar fechamento por timer, silêncio ou cota esgotada.
