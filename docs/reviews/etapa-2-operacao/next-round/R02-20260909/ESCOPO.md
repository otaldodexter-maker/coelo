---
title: "E2 R02 — cobertura da rodada e restante da Etapa 2"
source: "inventario-etapa-2.json de 09/09/2026 08:41:13 -03; escopo.json"
status: "prepared-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# O que entra e o que fica para depois

Este é o recorte PREPARADO; nenhuma das nove tarefas foi iniciada por este pacote.
A lista completa por action_id, família, estado inicial e responsável está em
[escopo.json](escopo.json). Ações são unidades de aceite do inventário, não horas.

| Frente | Contexto | Ações MVP E2E já inventariadas |
| --- | --- | ---: |
| D01 | Login, recuperação, redefinição, sessão/saída | 4 |
| D02 | Instituições, Unidades, Turmas, Atividades, Avaliações | 38 |
| D03 | Alunos, Assiduidade, Rotina diária | 15 |
| D04 | Pessoas, Perfis/permissões, Modelos, Convites, Segurança criança, Usuários internos | 31 |
| L01 | Acontece, Agora, Momentos; Circulares com mapeamento a completar | 12 + lacuna Circulares |
| L02 | Chat e Comunicações | 13 |
| L03 | Perfil contextual e Para Você | 3 |
| Total conhecido da rodada | Sete frentes | 116 + lacunas |

As atribuições ainda incluem 14 ações adiadas e2 gates formais para preservar
o comportamento aprovado, sem implementar o que foi adiado. São 132  IDs
selecionados no total, não132 funcionalidades novas.

## Restante fora das sete frentes

| Fila futura | Ações MVP E2E inventariadas | Observação |
| --- | ---: | --- |
| Saúde/cuidado e Medicação | 9 | Fluxos e suas subtelas |
| Agenda | 7 | Operação |
| Formulários: autoria, respostas e arquivos | 18 | Inclui a exceção XLSX por formulário |
| Planos e Planejamentos alimentares | 11 | 5 de planos e6 de planejamento alimentar |
| Auditoria, Suporte e Catálogo | 13 | Exportação geral de auditoria permanece adiada |
| Minha conta, Locais e Páginas de erro | 13 | E2E aplicável:3+4+6; dependências pontuais podem ser necessárias já |
| Total ativo E2E conhecido fora da rodada | 71 | Não abrir essas frentes automaticamente |

Esses71 pertencem a87  IDs fora da rodada: 73 MVP (dois não aplicam E2E),
8 adiados,5 de shell exclusivamente frontend e1 gate formal.
Home não tem action_id próprio suficiente: registrar a lacuna antes de alegar
cobertura integral da Etapa 2. Ações que só têm entrada /dev precisam de acesso
normal; existir uma preview não remove a pendência.

No conjunto do inventário:219  IDs =189 MVP +22 adiados +5 flutter-only +3 gates.
Dos 189 MVP,187 aplicam E2E; account.settings e account.theme não.
Importação/exportação geral real continua pós-MVP; forms.responses.export
é a exceção XLSX aprovada e pertence à futura frente de Formulários.
MFA segue os gates formais existentes; não declarar implantado por esconder o gate.

## O que os percentuais significam hoje

- Seleção da rodada:116/187 =62,03% das ações E2E atualmente inventariadas.
- Certificação E2E registrada na fotografia:0/187 =0%.
- Isso NÃO significa zero código ou zero funcionalidade implementada.
  Significa que o registro ainda não certifica o circuito completo exigido.
- Circulares, Home e granularidade de subtelas ainda limitam a completude
  do inventário. Não usar62,03% como avanço ou prometer100% apenas nesses IDs.
- Não há taxa global de testes confiável para somar a partir dos lotes
  históricos sobrepostos. Reportar casos únicos, última execução pertinente,
  base/ambiente e os bloqueados/ignorados/não executados separadamente.

D00 recalcula os números no início real e no fechamento, publicando o delta,
a base e qualquer mudança de denominador. Uma nova lacuna registrada não deve
parecer perda de código, e uma suíte repetida não deve parecer nova entrega.

## O que precisa mudar para a rodada produzir entrega

O fechamento anterior prova lotes locais verdes, mas ainda mantém requisitos
de integração, caminho normal, identidade/permissão e provedores sem prova
completa por ação. Há também lacuna de inventário de Circulares e uma limitação
real da ponte entre sessões: Markdown não acorda o Claude sozinho.
Esses fatos explicam por que contagens de testes não demonstraram entrega E2E;
não provam que todo tempo anterior foi desperdiçado ou que um modelo específico
seja o causador.

O contrato atribui um dono por contexto inteiro, integra commits durante o dia,
restringe repetição de testes a causas concretas e exige evidência da ação.
Prazo de fechamento completo só pode ser atualizado pelo delta inspecionado e
pela vazão real de aceites E2E; não multiplicar uma faixa fixa de horas por tela.

