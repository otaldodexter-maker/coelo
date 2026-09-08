---
title: "F-AUTHOR02 candidato — contexto institucional mínimo do editor"
source: "Orientação central para crosswalk paginado; FormsEditorContext; editor atual; contexto legado e reader nominal"
status: "candidate-awaiting-contract-review-no-extra-sql"
generated_at: "2026-09-07"
---

# Problema e recorte

`FormsEditorPage._loadProduction` chama contexto global antes de getEditor e
exige canManageForms até para abrir leitura. `FormsEditorContextApi` retorna
lista integral sem paginação. O adapter existente usa exclusivamente RPC People
`superadmin_forms_context`, portanto não compõe o ator interno.

O diretório institucional interno existente exige platform.read. Não inferir
essa permissão a partir de forms.manage nem representar uma página truncada
como catálogo completo. `SuperadminAuthContext` não contém public_name.

Incluído no candidato: busca paginada de instituição para criação e contexto
vinculado para leitura/edição de rascunho nominal. Fora: publicação, aplicações,
transferência, People, Admin/Principal, novos grants implícitos, SQL/deploy.
Ordem: contrato aprovado → DTO/cliente com RED → SQL nominal reservado → replay
Eng1 → integração. Estimativa após contrato: 60–90 minutos locais, não E2E.

# Dois fluxos, sem catálogo para leitura

| Fluxo | Fonte candidata | Permissão | Dados |
| --- | --- | --- | --- |
| Criar | Novo reader paginado nominal (nome proposto `superadmin_forms_authoring_institutions_v2`) | forms.manage | Página de id/public_name |
| Abrir existente | Estender envelope de `superadmin_forms_editor_v2`, sem novo lookup cliente por instituição | forms.manage OU forms.read | Definição + instituição real vinculada + capacidade de edição |

O nome novo é proposta, não endpoint criado ou reservado. Não há migration
adicional neste documento. O reader existente mantém a capability inicial,
inclusive a revalidação pós-lock do pacote anterior.

# Contrato paginado proposto

Entrada `p_query` objeto com allowlist: search opcional (texto até 160 caracteres),
limit inteiro entre 1 e 50, default 20; cursor opcional contendo `name_key` e UUID
id, ambos presentes ou ambos ausentes. `name_key` deve ser string até 1024
caracteres e o cursor objeto de até 8 KiB, com somente essas duas chaves.
Não truncar nomes/cursor para cumprir o teto: dados históricos fora dele precisam
de diagnóstico explícito. O write institucional nominal limita nomes a 240;
o teto de cursor maior acomoda normalização sem impor nova regra de nome.
Limites são técnicos propostos para
review, não nova regra de negócio. Search é literal, escapando `%`, `_` e barra
antes de ILIKE; sem wildcard livre do usuário. Campos/tipos extras são inválidos.

Saída no envelope nominal `{ok,data,error}`:

```json
{
  "items": [{"id": "uuid", "public_name": "Nome autorizado"}],
  "has_more": true,
  "next_cursor": {"name_key": "nome autorizado", "id": "uuid"}
}
```

Ordenação/seek por `(lower(public_name),id)` ascendente, mesma collation e
expressão nos dois lados; limit+1 define has_more. Cursor não autoriza instituição
nem escopo. Todas as páginas revalidam sessão/vínculos/membership/forms.manage
antes de parâmetros. Escopo plataforma vê candidatos autorizados; escopo
instituição vê somente seu ID real. Escopos inválidos ou nulos negam.

Elegibilidade proposta para **escolha de criação**: active e deleted_at null,
preservando o filtro do contrato Forms legado 20260901190638. Não transferir
essa condição active para leitura de rascunho existente nem ampliar restrição
do save por inferência. Confirmar esse recorte no review contratual central.

Sem contagem global, documentos, configurações, endereço ou dados de People.
Busca vazia lista a primeira página de candidatos autorizados. Última página
pode conter de 1 até limit itens, com has_more false e cursor null. Somente
resultado sem correspondência ou página esgotada tem items vazio. Mudança de
busca, ator ou escopo reinicia cursor e descarta respostas
atrasadas; o cliente não conclui que não existem outras instituições enquanto
has_more for true. Paginação não promete snapshot imutável diante de renomeações;
reload/reinício é explícito, e IDs repetidos são deduplicados sem fundir rótulos.

# Contexto de formulário existente

Extensão candidata do data do reader:

```json
{
  "definition": "projeção nominal existente",
  "application": null,
  "institution": {"id": "institution_id real vinculado ao formulário", "public_name": "Nome autorizado"},
  "capabilities": {"manage": false, "publish": false, "manage_applications": false, "transfer_cross_institution": false}
}
```

Instituição vem do form autorizado e lockado, nunca de ID independente passado
pelo cliente. `manage` é true apenas se a capability forms.manage foi a escolhida
e revalidada; caso read-only é false. Outras capacidades permanecem false nesta
fatia draft-only, ainda que o usuário tenha grants para fluxos não conectados.
Instituição não excluída, sem exigir status active na leitura. Nenhuma lista de
escolhas para read-only; instituição vinculada aparece desabilitada.

Save conserva Future<FormDefinition> e snapshot de receipt como estão. Contexto
de exibição/capacidades não deve ser gravado em receipt nem usado como fonte de
autorização. O backend sempre reautoriza a escrita independentemente do DTO.

# Cliente

DTOs separados para página de candidatos e contexto vinculado, sem reutilizar a
lista integral legacy como coleção completa. Adapter nominal novo não delega
getEditorContext/save/editor a People nem fabrica platform.read.

Na criação, carregar primeira página e permitir busca/carregar mais; seleção
explícita ou única opção realmente autorizada (somente com busca vazia e
has_more false), sem inventar instituição de ID
da sessão com rótulo falso. Edição abre reader diretamente, sem consultar catálogo
antes. Separar `_canView` de `_canEdit`; read-only não exibe erro de autorização
quando há projeção autorizada e não permite mutações, save, publicar ou trocar
instituição. Botão voltar permanece utilizável. Não habilitar transferência
institucional em edição nesta fatia.

Estados: loading, vazio autorizado, erro recuperável, negado, sessão vencida,
read-only autorizado; listas e projeções antigas não sobrevivem troca de ator/
formId/escopo. DTO malformado, cursor parcial e capacidades ausentes negam
renderização dos dados, sem fallback silencioso para permissões antigas.

# Auditoria e negativas

Wrappers VOLATILE, audit obrigatório fora do catch de negócio. Evento proposto
`superadmin.forms.authoring.institutions`; reader mantém `superadmin.forms.editor`.
Registrar capacidade efetiva, ator interno ou auth_session quando identificável,
correlação e escopo mínimo. Não registrar search, nomes, cursor ou definição.
Falha de append propaga; sem resposta de sucesso não auditada.

Negativas preparáveis: sem sessão, People-only, vínculo/membership revogados,
sem manage no catálogo, A→B, cursor malformado/parcial, tipos/tamanho/limit inválidos,
instituição excluída, falha de auditoria. Controles: manage-only sem platform.read
busca candidatos; read-only abre somente formulário autorizado sem catálogo;
form em instituição inactive não excluída continua legível; mais de 20 candidatos
não desaparecem nem autorizam contagem/finalização precoce.
Cursor estruturalmente válido originado em outro escopo não exige assinatura
criptográfica: jamais amplia resultados; reautorização e escopo atual prevalecem.

# Gates e memória

Aguardar review contratual, nome/reserva nominal e elegibilidade de criação.
Nenhum endpoint, SQL, regra de produto ou projeção de conhecimento foi criado
por este candidato. Delta enviado ao Coordenador; replay e produção continuam
abertos. Locais internos, cuidado e exportação permanecem no escopo E2E 4.
