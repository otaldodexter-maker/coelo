---
source: "R08-backlog.md; R07-decisoes-owner-20260912.md; autorização nominal C0 para frame e PublicationSurface; comandos locais desta R08"
status: "local-green; recertificação FE/E2E pendente do runtime G0"
generated_at: "2026-09-12"
---

# G3 — frame e chamada

Base integrada recebida: `6d6cbef32`; abertura G3: `3ec1c1a86`.
Superfície: `apps/superadmin -> Assiduidade -> Chamada -> marcar/concluir/corrigir`;
`apps/superadmin -> Cuidado -> Medicação -> cadastro/edição em 375 px, texto 200%`.

## Alterações

- A+ de Chamada: título e subtítulo compactos reduzidos em 25%; retorno `Voltar`.
  `PublicationSurface.compactHeaderScale` vale 1 por padrão e .75 somente em Chamada.
  Desktop conserva tipografia. Posse do composto confirmada nominalmente por C0.
- Frame: o rodapé recebe limite de metade da altura útil e scroll quando suas
  ações não cabem. O corpo continua separado e rolável, sem cobrir campos ou
  reduzir texto. Reproduzido overflow na etapa de data de Medicação com altura
  disponível de 203 px; corrigido e testado com conteúdo/ação alcançáveis.
- Chamada: o controller da observação era descartado a cada mudança de chamada;
  a segunda mudança tentava reutilizá-lo. Agora limpa ao mudar e descarta no
  encerramento do State. Teste de três chamadas reproduziu erro antes e passou depois.

## Evidências locais

Todos os comandos Flutter abaixo usaram `--concurrency=1 --reporter expanded`,
na pasta `apps/superadmin`, em slot nominal G3. Sem execução paralela de Flutter.
O C0 mediu e transferiu o slot às **11:10:15 -03:00**, sem processos restantes.
IDs de sessão observados são registros da ferramenta, não PIDs inferidos.

| Casos únicos | Arquivos | Resultado atual |
|---:|---|---|
| 26 | medication_plan_ui_contract_test.dart | PASS |
| 5 | superadmin_form_frame_test.dart | PASS |
| 5 | superadmin_form_action_footer_test.dart | PASS |
| 53 | attendance_pages_test.dart (52 existentes + ciclo de controller) | PASS |
| 1 | publication_header_contract_test.dart | PASS |
| 52 | attendance_pages_golden_test.dart + daily_routine_editor_responsive_test.dart + forms_editor_page_test.dart + safety_pages_test.dart | PASS |
| **142** | **Base local desta entrega** | **142 PASS / 0 FAIL atuais** |

Logs nesta pasta:

- `medication-before.log`: teste focal de data, exit 1, overflow reproduzido.
- `medication-after.log`: mesmo caso corrigido, exit 0 (incluído nos 26, sem somar).
- `frame-attendance-tests.log`: lote inicial, exit 1, 86 PASS / 3 FAIL;
  falhas eram fixture nova de altura e duas expectativas do antigo retorno.
- `frame-attendance-rerun.log`: apenas frame + attendance afetados, exit 0, 57 PASS.
- `attendance-controller-before.log`: caso novo, exit 1, controller descartado.
- `attendance-controller-after.log`: caso novo corrigido, exit 0, 1 PASS.
- `attendance-golden-before.log`: 1 PASS / 3 FAIL esperadas pelas alterações A+.
- `attendance-golden-update.log`: regravação das cinco imagens afetadas, exit 0.
- `frame-consumers-and-goldens.log`: verificação posterior e consumidores,
  sessão 76241 encerrada, exit 0, 52 PASS. Não soma novamente os quatro goldens.
- `frame-attendance-analyze.log`: análise focal dos três arquivos produtivos e
  dois testes novos/alterados, sessão 80321 encerrada, exit 0, `No issues found`.
- `visual-contracts.log`: validador global, exit 1, achados em outras frentes
  (Agenda, Chat, Instituições, Acontece, Alunos/allowlist); nenhum arquivo alterado
  por este pacote. Não significa validação global verde.

Goldens comparados antes de atualizar: mobile claro/escuro 375 a 200% mostra
`Sua publicação` em uma linha e retorno em uma linha; desktop1440 só altera o
texto de retorno. Cinco PNGs alterados na pasta original de goldens de Chamada,
sem nova aprovação visual inferida. Cenários start/footer são provas da mesma
superfície aprovada, não cinco novas aprovações do Owner.

## Limites e próximo gate

Nenhum estado de inventário/rastreador foi alterado. `attendance.mark`,
`attendance.finish`, `attendance.correct` conservam FE local-green, BE done e
E2E pending-verification até nova rota real/persistência/reload com G0.
O overflow local de Medicação está resolvido; isso não recertifica CRUD ou mídia.
Nenhum dado sintético ou chave criado. Nenhum deploy ou SQL remoto executado.

Continuar mídia de Formulários (imagem de pergunta separada de resposta),
`forms.location-answer` e conciliação H10/H11 com as fontes canônicas. Memória:
nenhuma regra de produto nova; esta entrega executa A+ e contratos existentes.
Projeção durável final, se necessária, permanece com C0, conforme escritor central.
