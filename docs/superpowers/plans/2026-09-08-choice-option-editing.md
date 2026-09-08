---
source: "Spec Forms 2026-08-13:174–175; reserva central de opções em 2026-09-08"
status: "ui-approved-shared-config-gate-pending"
generated_at: "2026-09-08"
---

# Adicionar e remover opções sem perder condições

Root único writer; somente edição local/testes, sem SQL/rotas/publicação.
Adicionar opção cria ID opaco até 50. Remover exige mais de duas opções,
ausência de referência em toda a definição (árvore, plano e outras seções) e
invariantes de mínimo de seleções preservadas. Bloqueios têm motivo explícito.
Não há cascata nem ajuste silencioso de configuração. Seleção transitória da
opção removida é limpa; mapper/filas de autosave permanecem únicos.

O domínio/DTO ainda não representam min_selections/max_selections; o decoder
estrito rejeita essas chaves. Complemento de dois campos opcionais tipados e
testes próprios foi solicitado à coordenação. Não alterar esses arquivos antes
da reserva explícita. Máximo pode permanecer maior que a quantidade de opções,
como permite o SQL; mínimo não pode tornar a resposta impossível após remoção.

1. RED de adicionar/remover e round-trip de IDs; limites 2/50.
2. Após gate compartilhado, RED de round-trip da configuração e correção mínima
   de FormItemConfig/FormDefinitionDto, sem relaxar chaves/tipos desconhecidos.
3. UI usa botões/campos Coelo existentes, callbacks atuais e bloqueio de
   referência/minimum. Não tocar controles de configuração fora desta fatia.
4. Testar referência cross-section/complexa, callbacks retidos, autosave e
   mínimo preservado. Regressão Forms/pacotes, analyzer, validador e review.
5. Evidência/commit e handoff; não declarar integração ou E2E a partir disso.

Alternativa ao gate compartilhado: limitar correção a singleChoice e manter
multipleChoice aberta, sem fingir acesso aos limites. Estimativa 20–25 minutos,
com corte central às 03:20 BRT. Self-review: não cria nova política de cascata,
seleção ou autorização; preserva as regras existentes.
