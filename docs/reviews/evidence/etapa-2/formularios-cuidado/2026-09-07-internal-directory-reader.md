---
title: "F-READ01 — reader interno e composição do diretório"
source: "Reserva nominal F-READ01-UI do Coordenador; prompt original preservado em ../coordenador/prompts-etapa-2-e2e.md; contrato Forms e SAI existentes"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Recorte e limite

Superadmin, Formulários / Diretório / `forms.list`. Base
`17812624cd27e947cf56bc2d6d04250bfcabf14a`, branch
`codex/e2e-formularios-cuidado`, worktree `f6c2/Coelo`. Único writer root;
reviews read-only por `review_export_policy` e `medication_roundtrip`.
Objetivo: reader exclusivo do realm interno, sem converter a API legada nem
fabricar vínculo de Pessoas. Ordem: teste, reader, teste de tela/composição,
regressão, review e commit; depois SQL nominal e prova integrada.

Fora desta fatia: autoria, editor, overview, respostas, agendas, comandos,
exportação, mídia e política clínica. Esses itens continuam no escopo original
da frente e **não estão concluídos**. Nenhuma escrita/leitura remota de banco,
Docker, R2 ou Stream foi executada. Não há lease remoto nesta frente.

# Alteração

- `FormsDirectoryReader`: uma operação, somente listagem.
- `SupabaseSuperadminFormsDirectoryReader`: chama exclusivamente
  `superadmin_forms_directory_v2`, com `p_query`, sem People/context/mídia.
- Decodifica envelope SAI e os oito campos da projeção explicitamente; rejeita
  enums desconhecidos, UUID/data/versão inválidos, campos extras, páginas acima
  do limite, IDs duplicados e cursor incoerente. Preserva micros textuais do
  cursor; valida offset antes da normalização de `DateTime.parse`.
- Falhas retornam mensagens fixas e detalhes vazios. Não reutiliza projeção
  após revogação; cada página é uma chamada nova. Validação cliente não
  substitui autorização ou validação SQL.
- `formsDirectoryReader` passa por Scope → main → App → router. Apenas `/forms`
  recebe `api:null` e reader. Sem reader, permanece indisponível, sem fallback.
- Modo reader desativa gestão/lifecycle/transferência e callback de agenda,
  inclusive quando o chamador fornece API e flags permissivas.
- Troca de reader/API limpa busca, filtros, cursor e página; invalida respostas
  e contextos antigos, incluindo A → reader → mesmo A. Dispose ignora o retorno
  assíncrono. Erro/revogação descarta a página anterior.
- `/dev/forms` conserva fixtures; criar/editar/overview conservam `formsApi`.
  Navegar para overview/respostas pode chamar o contrato legado desses destinos:
  ausência de chamada People aqui diz respeito ao diretório leitor, não à
  conclusão de todos os destinos.

# Testes

RED executado: stub do reader teve 25 falhas de comportamento; oito testes de
integração da tela falharam sem wiring; quatro de composição falharam sem
pass-through. Review identificou offset inválido, com dois RED adicionais antes
da correção. Testes de preservação de destinos e dispose complementam regressão.

Suíte focada de dez arquivos: **124/124**, executada novamente após formatação.
Inclui 54 testes do novo reader, 11 da tela com reader, oito de rotas e 11 do
Scope, além das regressões de API legada, diretório, lifecycle e agenda.
Comando a partir de `apps/superadmin`:

```text
rtk proxy flutter test --no-pub --reporter expanded test/features/forms/data/supabase_forms_api_test.dart test/features/forms/data/supabase_superadmin_forms_directory_reader_test.dart test/features/forms/presentation/directory/forms_directory_page_test.dart test/features/forms/presentation/directory/forms_directory_internal_reader_test.dart test/features/forms/presentation/directory/forms_development_lifecycle_wiring_test.dart test/features/forms/presentation/directory/forms_lifecycle_actions_test.dart test/features/forms/presentation/directory/forms_schedule_dialog_test.dart test/features/forms/presentation/forms_lifecycle_page_wiring_test.dart test/app/router/forms_internal_directory_routes_test.dart test/core/config/superadmin_auth_scope_test.dart
```

Analyzer dos 11 arquivos Dart novos/alterados: zero problemas. Validador visual
`apps/catalog/tool/validate_admin_visual_contracts.dart`: exit 0, allowlist
inalterada. `git diff --check`: exit 0. Reviews finais sem achado bloqueante
no recorte; não são certificação de SQL ou produção.

# Visual: pendência preservada

Baseline administrativa: composição existente de Instituições, sem redesenho.
Suíte `forms_directory_golden_test.dart`: um teste passa e três falham, com
oito diferenças. Repetida com comportamento da página em HEAD (mantidos apenas
import/parâmetro/field inertes do reader para compatibilidade de compilação),
produziu **as mesmas diferenças e contagens de pixels**. O WIP foi restaurado
por `apply_patch`; nenhuma imagem golden foi atualizada.

| Golden | Diferença em HEAD e patch |
| --- | ---: |
| light 375 | 75.046 px / 22,24% |
| dark 375 | 91.159 px / 27,01% |
| light 768 | 128.647 px / 18,61% |
| dark 768 | 143.271 px / 20,73% |
| ações light 1440 | 9.390 px / 0,72% |
| vazio light 375 | 45.177 px / 13,39% |
| sem resultados light 375 | 46.732 px / 13,85% |
| não autorizado light 375 200% | 37.031 px / 9,87% |

Isso isola divergência preexistente, mas **não fecha o gate visual**. As provas
da página com doubles e o reload por reentrada de rota não equivalem a sessão
produtiva ou persistência em banco. Troca de dependências de App após initState
não faz parte desta composição estática; não foi refatorada.

# Próximo gate

Passo 3/6 local: cliente parcial. SQL e pgTAP do novo endpoint são o próximo
pacote; replay local pertence exclusivamente ao Engenheiro 1. A CLI 2.116.0
gerou `20260908000049_superadmin_forms_directory_internal_read.sql`, ainda vazio
e fora deste commit de cliente. Sem endpoint implantado, erro de função ausente
vira indisponibilidade honesta. Prova real exige sessão interna, escopo A/B,
revogação, persistência/reload e ambiente nominal autorizado.

ETA desta próxima preparação SQL/review: 1–2 horas de trabalho, dependente da
base local do runner. ETA de entrega E2E completa: não calculável sem gates
remotos e decisões clínicas. Os percentuais oficiais pertencem ao Coordenador;
não transformar esta fatia em conclusão de tela ou vertical.

Memória Coelo: no-op; aplicação de contrato aprovado, sem nova decisão de
produto. Consulta da projeção e fonte existente; validador da base e testes de
memória passam. Nenhuma projeção foi criada para registrar atividade.
