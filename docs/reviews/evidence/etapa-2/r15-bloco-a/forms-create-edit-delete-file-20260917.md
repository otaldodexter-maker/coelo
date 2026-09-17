---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 4); owner.r12-39/40; R14-handoff-sessao-6.md; r14-sessao-6/forms-expire-delete-file-20260916.md (roteiro de retomada)"
status: evidence
generated_at: 2026-09-17
---

# Formulários › Editor (`forms.create`, `forms.edit`; owner.r12-39, r12-40) e › Arquivos › Excluir (`forms.delete-file`) — rota real, 17/09/2026

Mesmo ambiente das fatias anteriores (produção, build QA de `r15/bloco-a` em `900608be9`, `127.0.0.1:3014`,
CDP 9414, tema claro; viewport 1424×2200 no editor para ver o rodapé sem rolagem), sessão
`qa-r06-formularios@coelo.me` (Owner de plataforma, contexto QA R04 Cuidado (sintetico)). Upload pelo seletor
nativo real (CDP `Page.setInterceptFileChooserDialog` + `DOM.setFileInputFiles`, PNG real 64×64). Readback
e negativas por PostgREST / Edge `form-media` com a mesma identidade. Capturas em `capturas/forms-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| forms.create | `/forms/new` (00: seção e pergunta padrão) → Nome "R15 A Formulario QA" → pergunta 1 "Pergunta A texto curto" → lápis "Renomear seção" → diálogo com contador 27/120 (01) → "Secao R15 A renomeada" (lista lateral e título da seção atualizados) → "Adicionar pergunta" → catálogo (Texto e números / Escolhas…) → "Número inteiro" → "Pergunta B inteiro" → **↑ Mover pergunta para cima** (ordem B, A) → "Salvar rascunho" → "Prévia local · Rascunho salvo." (02). | `form_save_draft` → formulário `90b905a1-923a-4cec-bd96-fbdb63fa0be6` (`draft`, `management_version 1`, instituição `d0c40000-…0001`), relido por `superadmin_forms_directory_v2` (`search "R15 A"`) e por `form_get_editor` (seção `68cf5e11…` "Secao R15 A renomeada" com itens `integer` "Pergunta B inteiro" `position 0` e `short_text` "Pergunta A texto curto" `position 1`). | Carga completa de `/forms/90b905a1…/edit` (05): título, seção renomeada e **ordem B → A** preservados. | versão defasada: `form_save_draft` com `p_expected_version 0` sobre a v1 → **`409 PT409` `FORMS_STALE_VERSION` "expected_version mismatch"**, sem mutação (diretório segue v1); instituição alheia no payload (`…0099`) → `400 23514 "use form_copy_or_move for institution changes"`; `form_get_editor` com id inexistente → `500 P0002 "form unavailable"` (resíduo de mapeamento, sem dado). |
| forms.edit | Mesma rota após o primeiro save (`/forms/90b905a1…/edit` é a rota de edição; o botão "Salvar rascunho" reenvia com `p_expected_version` atual); "Atualizar perguntas" após salvar habilita "Imagens da pergunta". | idem (`form_save_draft` v1 → o segundo save sem mudança não cria versão). | (05) e (06). | idem acima. |
| forms.delete-file | Editor → "Imagens da pergunta" (pergunta B) → "Selecionar imagem" → seletor nativo → PNG real → "Imagem da pergunta confirmada." com "Ver imagem 1 · Excluir imagem 1" (03) → "Excluir imagem 1" → links somem (04) → "Voltar ao formulário" → "Salvar rascunho". | Edge `form-media` `prepare` → PUT R2 → `finalize` (asset `question-image` ativo) → `delete` (`superadmin_form_media_delete_v2`, `status deleted`). | Carga completa de `/forms/90b905a1…/edit` → "Imagens da pergunta" sem nenhuma imagem (06): nenhum órfão acessível. | `form-media delete` com `asset_id` inexistente/alheio (`…0099`) → `404 {"error":"FORM_MEDIA_NOT_FOUND","message":"Arquivo não encontrado."}`. |

## Owner items

- **owner.r12-39** (posição final persistida): "Mover pergunta para cima" reordenou B antes de A; após "Salvar
  rascunho" e carga completa a ordem B → A permanece (05); `form_get_editor` devolve `position 0/1`.
  Arraste e botões de alternativa não foram exercitados por CDP (só o botão de mover), suficientes para a
  persistência pedida.
- **owner.r12-40** (seção renomeada na prévia): "Renomear seção" por diálogo (01) → nome na lista, no título
  da seção e, após reload, no editor (05) e na prévia (`/forms/90b905a1…/test`, 07): "Testar formulário" (Pré-visualização do formulário autorado) mostra "R15 A Formulario QA › Secao R15 A renomeada" com "Pergunta B inteiro *" antes de "Pergunta A texto curto" (07).

## Observações / resíduos (sem action_id novo)

- Rótulos padrão do formulário novo são "Seção sem dados disponíveis" / "Pergunta sem conteúdo carregado" /
  "O conteúdo autorizado será carregado quando a integração estiver disponível" — parecem estado de erro,
  não modelo em branco (texto de FE).
- O campo "Instituição" do cabeçalho do editor quebra o nome em coluna estreita ("QA / R04 / Cuid / ado …").
- Após o primeiro "Salvar rascunho" em `/forms/new` a URL continua `/forms/new` (a recarga abriria um
  formulário novo); o id só aparece pelo diretório.
- Mensagem "Imagem da pergunta confirmada." permanece após "Excluir imagem 1" até fechar o diálogo.
- `superadmin_forms_editor_v2` e `superadmin_forms_save_draft_v2` respondem `SAI_PERMISSION_DENIED` (403) para
  a identidade `qa-r06-formularios` via PostgREST, enquanto a tela usa `form_get_editor`/`form_save_draft`
  (permitidos). A família `superadmin_forms_*_v2` de autoria não é a usada pela rota real; registrar para o BE.
- `forms.expire-file` fica em prova separada (worker/cron; ver handoff).
