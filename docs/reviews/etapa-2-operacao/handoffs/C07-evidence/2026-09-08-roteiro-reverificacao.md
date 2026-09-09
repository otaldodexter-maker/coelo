---
title: "C07 — roteiro da reverificação independente, para executar quando o baseline conjunto chegar"
source: "combinado com a C06 e aceito pela C00: reverificar por medição própria, em vez de aceitar o resultado de quem corrigiu; medições e reproduções próprias de C07 no baseline 4af42925"
status: "evidence-plan"
generated_at: "2026-09-08T23:00:00-03:00"
timezone: "America/Sao_Paulo"
---

# Roteiro da reverificação independente

Preparado **antes** da janela para encurtá-la. **Nada aqui foi executado**: são previsões, e o valor
está justamente em registrá-las antes, para que a comparação depois não seja racionalização.

Princípio: **quem corrigiu não é quem verifica.** Cada linha abaixo tem um resultado esperado e o que
significa se ele não vier.

## Pré-condição

A C00 materializa o baseline conjunto na minha worktree. **Eu não faço merge nem cherry-pick.** Ao
receber, confiro o SHA e registro o antes e o depois.

## Comando único

```
cd apps/superadmin
rtk flutter test test/visual_review test/acceptance
```

Baseline `4af42925`, medido às 22:45: **169 casos, 144 verdes, 25 vermelhos.** É contra esse número
que a comparação vale.

## O que deve mudar, arquivo por arquivo

| Arquivo | Vermelhos hoje | Esperado depois | Se não vier |
|---|---|---|---|
| `visual_review/c07_now_publication_acceptance_test.dart` | 7 | **0** | achado real: a correção do Agora não restaurou a anatomia aprovada. Reportar quais dos sete sobraram |
| `acceptance/c07_locations_directory_test.dart` | 1 | **0** | a correção `15dc4727` não fechou o retry no negado |
| `acceptance/c07_institutions_directory_test.dart` | 3 | **0** | os focos do card, do banner e do indicador não foram todos cobertos |
| `acceptance/c07_people_directory_test.dart` | 4 | **0** | falta alguma das quatro: retry, dois limpar, Enter do indicador, alvo de 24 |
| `acceptance/c07_students_directory_test.dart` | 3 | **0** | a troca de captura não chegou ao view model de Acompanhamento |
| `acceptance/c07_groups_directory_test.dart` | 1 | **0** | o banner compartilhado não foi corrigido, ou a correção não alcançou Turmas |
| `visual_review/c07_happens_acceptance_test.dart` | 3 | **3** | **esperado continuar vermelho**: nenhuma correção foi anunciada para o sinal além de cor |
| `acceptance/c07_notices_directory_test.dart` | 3 | **3** | **esperado continuar vermelho**: a causa raiz é o alvo que consome largura, sem correção anunciada |

**Total esperado:** de 25 para **6** vermelhos, e os 6 remanescentes devem ser exatamente os de
Acontece e Comunicados, que não têm correção anunciada. Qualquer outro número exige investigação
nominal, não arredondamento.

## Reproduções fora do lote

Rodar cada uma copiando para `test/acceptance/_tmp_*.dart`, executando **em série**, e removendo
depois, com `git status` conferido vazio ao fim.

| Reprodução | Hoje | Esperado depois | Observação |
|---|---|---|---|
| `repro/toggle_field_keyboard_test.dart` | 5 verdes, 5 vermelhos | **10 verdes** | é o A/B; o baseline conjunto deve ter a correção do pacote **e** a do gêmeo. A C00 registra 7+7; **minha** medição é que fecha |
| `repro/shell_compact_page_header_inset_test.dart` | vermelho | **verde** | corrigido em `c4a7feff`, nunca medido por mim |
| `repro/chat_inbox_border_under_pagination_test.dart` | vermelho | depende | correção era da C05 no consumidor; se continuar vermelho, verificar se entrou |
| `repro/now_publication_wide_stage_test.dart` | vermelho | **verde** | o ramo amplo depende da correção do breakpoint |
| `repro/activity_directory_error_hang_test.dart` | 3 vermelhos | depende | encaminhado ao C03; sem correção anunciada até aqui |
| `repro/child_safety_error_hang_test.dart` | 3 vermelhos | **0** | a C02 está corrigindo decoder, controller e páginas |
| `repro/child_safety_silent_search_test.dart` | 6 vermelhos | **0** | mesma correção; inclui os quatro casts crus do decodificador |

## O que a reverificação **não** prova

1. Nada sobre backend real, persistência ou provedores. Tudo aqui é cliente com repositório duplo.
2. Nada sobre golden: **não regenero nenhum**, e a decisão de master continua da C00 com o Owner.
3. Um verde meu não certifica a ação no rastreador; certifica que **o defeito que medi deixou de
   reproduzir** no baseline que a C00 publicar.

## Se a janela não abrir até o fechamento

Entrego o que está medido, com este roteiro documentado como **não executado**, e a dependência
exata registrada: a materialização do baseline conjunto, que é da C00. Isso é entrega honesta e não
fica devendo nada.
