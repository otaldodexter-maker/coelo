---
title: "Decisões complementares do Owner sobre goldens (10/09/2026, tarde e noite)"
source: "Mensagens do Owner ao coordenador em 10/09/2026 (artefato de01d63e de Perfis de cuidado e Medicação; respostas P15 e P16; decisões RODAPÉ e CHAT via grupo estrutura); ADR 0034 Decisões 7, 9 e 12"
status: "approved"
generated_at: "2026-09-10"
---

# Decisões complementares do Owner sobre goldens

Complementa a [lista de 10/09](goldens-claro-decisoes-2026-09-10.md) e a de
[Acontece e Cardápios](goldens-acontece-cardapios-decisoes-2026-09-10.md).
Para os arquivos aqui listados, esta página **prevalece** sobre as anteriores.
Legenda igual: **R** mantém a referência guardada; **A** promove o render
atual depois de aplicar a observação.

## Perfis de cuidado e Medicação (artefato de01d63e, 16:00)

| Arquivo | Decisão | Observação |
| --- | --- | --- |
| medication_form_mobile_light | A | P15 (noite): rodapé ancorado no fim da tela em todos os formulários, com espaço no fim do conteúdo para a última informação nunca ficar escondida nem inalcançável; regravar depois da correção no frame compartilhado. Supera o R da tarde. |
| profile_form_mobile_light | A | RODAPÉ; título e descrição da etapa como cabeçalho do corpo (padrão de Criar instituição), não dentro de card. Regravado pelo grupo. |
| profile_form_desktop_dark | A | Seguir a skill `coelo-ui`: o wizard não seguia 100% o padrão (contêiner interno). Regravado pelo grupo. |

## Regras do Owner recebidas pelo grupo estrutura (tarde)

- **RODAPÉ opção A** (Decisão 7): rodapé ancorado no fim da viewport em todas
  as larguras nos formulários; `institution_form_create_light_375` regravado.
- **CHAT** (Decisão 7): sem balão de chat em telas de criar, editar e publicar,
  nem no Agora aberto e no Momentos aberto; prevalece sobre a regra CHAT da
  lista de 10/09 nessas telas.
- **Locais**: internos e externos como grupos, card Criar do composto por grupo
  definindo o tipo, botão "Novo local" do cabeçalho removido, card Criar também
  em vazio e sem resultados; 12 goldens do diretório de Locais regravados pelo
  grupo com essa estrutura (`location_directory_*`).
- **Turmas**: espaçamento dos cards reduzido conforme
  `r03-estrutura/decisao-espacamento-turmas.md`.

## Regras reafirmadas em toda a Etapa 2

- Pesquisar no menu em todas as telas.
- Botão de Bug no cabeçalho em todas as telas (MENU-M no mobile).
