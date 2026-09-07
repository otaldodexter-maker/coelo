---
title: "Medicação — recibos e replay obsoletos"
source: "Prompt 5; achado MED-STALE do Engenheiro 2; testes locais"
status: "local-hardening-production-blocked"
generated_at: "2026-09-07"
---

# Recorte

Superadmin, `medication.create` e `medication.edit`, somente lifecycle do
componente existente DEV. Nenhuma autorização clínica, regra de dose, status
de plano, schema, router, persistência produtiva ou decisão jurídica alterada.
Estimativa inicial local: 45–75 min, sem promessa E2E.

## Causa e correção

Os dois caminhos de save aplicavam recibos após await sem conferir contexto ou
mounted. No replay com edição, uma conclusão obsoleta ainda iniciava outra
mutation no callback antigo. Geração agora invalida source/callback/dispose e
protege sucesso, catch e finally. Callback de sucesso é capturado na operação.

Troca real da fonte reidrata campos e descarta pending antigo. Comparação da
fonte é semântica, incluindo todos os campos e conjuntos, para não apagar
edições em rebuild equivalente. Troca só de callback preserva a intenção da
mesma fonte; replay sem alterações não cria atualização extra.

## Verificação

- Cinco RED iniciais reproduzidos antes da correção: callback, dispose,
  replay com/sem edição, fonte substituída.
- Review encontrou dois P2 na primeira implementação; ambos tiveram RED:
  rebuild equivalente apagava edição e callback swap gerava segunda mutation.
  Corrigidos e segunda revisão aprovada, sem novos achados no diff.
- Oito testes novos no total, incluindo falha obsoleta enquanto B está busy.
  Contrato: 18/18. Regressão final de seis arquivos: 54/54.
- Analyzer dos dois arquivos sem issues. Validador administrativo exit 0.
- Cenários existentes de replay idempotente continuam passando: mesmo request
  no retry; edição recupera recibo antes da próxima versão; navegação sem edição
  não cria versão extra.

## Pendências visuais preexistentes

O teste golden `matches both forms on mobile light and desktop dark` falhou em
quatro imagens. Retirado temporariamente apenas o patch deste componente via
apply_patch, confirmado diff vazio contra HEAD 8d2ab5a, e repetido o teste:
mesmas diferenças. Patch reaplicado e regressão final rodada. Goldens intactos.

| Imagem | Pixels diferentes | Percentual |
| --- | ---: | ---: |
| profile_form_mobile_light | 72034 | 21,34% |
| profile_form_desktop_dark | 109822 | 8,47% |
| medication_form_mobile_light | 79321 | 23,50% |
| medication_form_desktop_dark | 201118 | 15,52% |

## Estado e próximo gate

Front-end produtivo, Back-end e E2E de ambos IDs continuam `blocked-decision`.
Evidência local não autoriza ativar rotas, certificar efeito clínico ou promover
persistência. OQ-003/OQ-040 e contratos produtivos seguem abertos. Não houve
remoto, dado real, upload ou mudança compartilhada. Round-trip de DTO e status
do repository DEV são achados separados, não resolvidos por este pacote.

Gate de memória: no-op; aplicação de isolamento e idempotência existentes, sem
regra de produto nova. Handoff ao Coordenador; rastreadores não editados aqui.
