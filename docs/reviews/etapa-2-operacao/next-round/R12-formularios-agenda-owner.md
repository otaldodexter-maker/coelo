---
source: Owner e quatro anexos de Formulários e Agenda na conversa de 2026-09-13; .agents/skills/coelo-ui/SKILL.md
status: backlog R12; sem implementação
generated_at: 2026-09-13
---

# R12 — Formulários e tabela de aprovações da Agenda

Sexto bloco de R12-apontamentos-owner.md. Somente registro para R12, fora da
execução R11. Host apps/superadmin; família administrativa. Quatro anexos vistos
na conversa, sem exportação dos binários nem transcrição de dados pessoais.
Responsável: C0 R12 após abertura explícita.

| ID / referência | Tela/subtela e action_ids | Requisito / primeiro gate |
|---|---|---|
| R12-39 / anexo 1 | Operação > Formulários > Editar > Arrastar pergunta ou seção; forms.edit, forms.create | Rejeitado bloco cinza/sombra pesada no arraste. Usar sombreamento sutil preservando aparência do item e indicação clara de posição. Mesma regra para seções. Reproduzir arraste, soltar e cancelar, sem alterar tamanho/brincar com ordem ou duplicar item; manter alternativas por teclado/botões. |
| R12-40 / relato | Editar formulário > Nome da seção; forms.edit, forms.create | Owner não consegue mudar o nome das seções. Reproduzir acesso à edição, renomear, confirmar, salvar e reload; mostrar nome atualizado no painel de seções, título e prévia. Não confundir nome da seção com nome do formulário ou pergunta. Nenhuma causa backend confirmada. |
| R12-41 / anexos 2–3 | Formulários > Diretório > Situação / Período; forms.list | Inputs fora do padrão. Seletor Situação estreito trunca texto e quebra Limpar/Aplicar em duas linhas. Usar filtros canônicos e largura adequada do popup/rodapé, com seleção múltipla preservada. Conferir Período ao lado no mesmo padrão, estado aberto/fechado, foco, compacto e texto ampliado. |
| R12-42 / anexo 4 | Operação > Agenda > Aprovações > Aprovações de publicação; action_id específico ainda a mapear | Tabela fora do padrão. Aplicar Table canônica: largura, colunas/alinhamento, densidade/altura das linhas, status, texto de histórico, ações e seleção/hover. Reprodução focal antes de atribuir causa; preservar decisão registrada e controles de autorização. Este anexo NÃO é de Respostas/Formulários. |

## FE / BE / E2E e critérios

FE: direção visual registrada, sem render corrigido aprovado; renomear seção é
falha relatada a reproduzir. BE: verificar suporte a título e ordem de seções,
identidades estáveis, versão e persistência; nenhum diagnóstico novo de banco.
E2E: renomear e reordenar múltiplas seções/perguntas, salvar/reload sem perda nem
duplicação; filtro deve retornar dados corretos. Agenda exige prova própria na
rota de Aprovações; não alterar decisão ou disparar aprovação real para registrar UI.

O sombreamento sutil é direção aprovada, não novo token arbitrário. Reutilizar
componentes/estados do Design System, mouse/toque/teclado e contraste de foco.
Distinguir cancelamento do arraste de persistência da ordem; não assumir autosave.
Tabela da Agenda é um pedido visual, sem autorização nova de regra de aprovação.

## Handoff

Deltas propostos em R12-formularios-agenda-delta.json, NÃO aplicados. C0 central
rebaseia as notas atuais antes de apply-tracker-delta.cjs e incorpora ownerItems.
Mapear Aprovações ao inventário por rota/contrato antes de aplicar delta dessa tela:
agenda.request ou agenda.permissions não são assumidos como equivalentes.
Não criar action_id ou mudar denominador por contagem de anexos.
WIP R11 e seus rastreadores centrais preservados; integração documental central
permanece pendente do integrador. Sem código, build, SQL, deploy ou execução R12.
