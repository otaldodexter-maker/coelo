---
title: "Instituições — snapshot salvo e lifecycle"
source: "contrato local aprovado pelo Coordenador; spec042; testes antes/depois"
status: "local-tests-green; baseline-five-failures-unchanged; not-verified-e2e"
generated_at: "2026-09-07"
---

# Recorte

Somente `InstitutionFormPage`: snapshot antes de awaits; resposta/erro antigo
ignorado por geração/identidade; controller salvo substitui anterior com mesma
etapa e subtree nova; dispose após desconexão dos campos; bloqueio de interação
e duplo envio durante save. Sem mudança de validação, layout, FormFrame,
router, DTO/RPC, coreV2 ou remoto.

## TDD e revisão

Novo `institution_form_save_lifecycle_test.dart`: antes do patch,4RED e1GREEN.
Falhas reproduzidas: nome/record antigo após save, ausência de bloqueio de
interação, snackbar de sucesso/erro de instituição anterior após trocar ID.
Depois do patch:5GREEN local, também reexecutados por reviewer independente.
Analyzer dos arquivos alterados: zero issues.

O teste de interação foi reforçado depois da revisão para tocar campo e etapa,
usar Tab, conferir falta de conexão de teclado e repetir a callback já capturada
de envio. Reexecução da versão reforçada:5GREEN; analyzer dos dois arquivos:
zero issues. Regressão ampliada após o patch:44PASS/5FAIL, exatamente os
mesmos nomes da baseline abaixo, sem falha nova. Não foram atualizados goldens.
Revisão independente final somente leitura: sem bloqueadores concretos no
recorte. Validador visual e gate de conhecimento passaram; projeção no-op.

## Baseline preservada

Antes de qualquer código deste pacote, a suíte existente do formulário e
goldens retornou44PASS/5FAIL. As mesmas3 falhas de widgets foram reexecutadas
isoladamente e reproduzidas:

- `administrator representative selection supports 200 percent text at 375 and 1440`;
- `person dialog reveals required errors after submit attempt`;
- `renders approved breakpoints without overflow`.

O footer compacto está no final de `SingleChildScrollView` em
`SuperadminFormFrame`; os testes tocam Continuar fora da viewport375 e não
avançam. Erros subsequentes são `No element` ou campo CEP ausente, não prova
de overflow. Fonte compartilhada e testes existentes não foram alterados.

Duas falhas de golden:

- `matches critical create and edit form references`;
- `matches the contained institution bio reference`.

Inspeção do testImage375 versus master encontrou shell/mídia indisponível já
vigentes e footer fora da tela, enquanto master antigo mostra footer fixo e
escolha de foto. Não atualizar baselines para esconder a divergência.

## Limites

Este pacote não remove a exigência local de representantes/administradores.
Modo coreV2 e compatibilidade da validação com detalhe interno permanecem
pendências explícitas e foram excluídos pelo Coordenador. Não há acesso a BD,
tenant real, produção, arquivo remoto ou autorização nova. Memória: no-op de
projeção, pois trata correção do comportamento de save já aprovado.
