---
source: "D04 parent assignment; coelo-ui verification.md; form-layout-contracts.md; InstitutionFormPage approved baselines"
status: "candidate-evidence-only; not-approved-baseline; not-E2E"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Estados de confirmação Pessoas e Usuários internos — candidatos D04

Hospedeiro apps/superadmin; família administrativa; referência de composição
Criar/Editar instituição, FormFrame/StepNavigation/ActionFooter compartilhados.
Baselines institution_form_create_light_375 e institution_form_edit_dark_1440
foram abertas para comparação de anatomia. Nenhum golden existente foi alterado.
Base observada na captura final: `d2334cc8cc5e94a315ffa5de8a3ca5222e32d30e`.

Recorte visual estrito: Acessos -> Pessoas/Usuários internos -> editar ->
estado após resposta confirmada. IDs people.edit e internal-users.edit;
criação compartilha o componente, mas não foi capturada neste lote visual.
Harness local usa widget real e resposta sintética; não certifica rota normal,
backend, ator real, auth, criação de conta ou E2E. Referências permanecem candidatas.

| Arquivo candidato | Viewport/tema | SHA256 |
| --- | --- | --- |
| people-confirmed-light-375-candidate.png | 375x900 light | f4d4d7c0cf10c32b456641339419d0e8106663bfb00d37cbef937c98f00d6f0f |
| people-confirmed-dark-1440-candidate.png | 1440x900 dark | aeaa716e2d7828aee9f32e24f822a13f7cd82c8d565806f27fae45f0d0348aaf |
| internal-users-confirmed-light-375-candidate.png | 375x900 light | 0ba58439aff8c2b710f3d6ae6fd306f9dc589b5b4541cffa1126a2e465dc4568 |
| internal-users-confirmed-dark-1440-candidate.png | 1440x900 dark | c02076dde7c6f80dfce14bbf0faec63036b79b0138ddfb8f968d0d1c726d316c |

Quatro imagens finais abertas visualmente pelo subagente: títulos, painel e
mensagem íntegros; Continuar visível; rodapé não cobre a última mensagem.
Mobile empilha ações; desktop mantém saída à esquerda e continuidade à direita.
Pessoas oferece Voltar ativo. Usuários internos preserva Cancelar ativo para
sair e Voltar desabilitado para impedir retorno à edição já confirmada.
Sem overflow observado nem exceção de layout. Nenhum redesenho foi realizado.

Final **P4/F0/B0/S0/U0**, quatro casos únicos de captura, sem somar reruns
nem lotes funcionais14/17/20. Assertions cobrem mensagem, Continuar hitTestable,
Voltar presente, geometria mensagem acima do footer e footer dentro do viewport.
Nunito Sans e MaterialIcons carregados. Debug banner desligado só no harness.
Sem rede real: repositórios sintéticos. Endereço do fixture Users removido para
não ativar plugin de mapa alheio ao estado capturado.

Comando, de apps/superadmin:
`flutter test ../../docs/reviews/etapa-2-operacao/next-round/R02-20260909/evidence/D04/d04_confirmed_forms_capture_test.dart --no-pub --reporter expanded`.
Saída final completa: `confirmed-forms-capture-final.log`.
Harness SHA256: `711c8c0bf75dd905d561f0fd2c057a4cef6377c200c62a67de9afdf2186f80b0`.
Diff --check limpo. Nenhum teste de referência oficial atualizado.

Falhas de infraestrutura do harness resolvidas antes desta evidência: primeiro
runner interrompido após raster aguardar fakeasync; toImage/toByteData passaram
integralmente a runAsync. Interrompido só tester D04 PID44892; tester L01 alheio
não foi tocado. Primeiro lote concluído P3/F1 apontou MissingPluginException de
path_provider durante mapa do fixture Users; removido endereço sintético,
Users2 verdes. Rerun4 final justificado pela remoção de debug banner das imagens.
Esses eventos não foram registrados como regressão nova do produto.

Fora da prova: teclado/leitor de tela, texto200%, 768/1024, criação e outros
passos do formulário, snackbars de falha de continuação, runtime conectado.
Não há nova regra de produto/knowledge; somente evidência proposta. Slot liberado.
