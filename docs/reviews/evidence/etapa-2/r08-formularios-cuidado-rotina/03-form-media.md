---
fonte: R08-prompts.md; R08-backlog.md; ADR 0034; form-media/index.ts; candidatos G5 140547/140548/140549
status: local-green; integracao-e-runtime-pendentes
data_geracao: 2026-09-12
---

# G3 — Upload e leitura privada de Formulários

Base de código: 0d6024076. Recorte: apps/superadmin -> Formulários -> editor/imagens da pergunta e resposta/Galeria -> forms.upload, forms.resolve-file, forms.expire-file, forms.delete-file. Pergunta e resposta são aceites distintos. Nenhuma promoção E2E ou alteração de rastreador central.

O uploader usa exclusivamente upload_url e required_headers do prepare, PUT em cliente HTTP próprio sem copiar Authorization, sem seguir redirecionamento, e só adiciona o asset após finalize. Valida MIME pela assinatura, tamanho, SHA-256, TTL até cinco minutos, IDs/medidas do recibo; cancela e apaga bytes ao invalidar a sessão. Falha incerta mantém o asset para verificação ou descarte explícitos, sem repetir PUT. Galeria usa até 10 MiB; pergunta usa até 4 MiB. A medição de pixels e conteúdo permanece no backend.

Galeria identificada está conectada ao rascunho da resposta. Enquanto houver envio pendente, autosave/revisão/envio aguardam conciliação. Retirar imagem confirmada da resposta altera a referência no rascunho; não declara exclusão física do asset. O descarte de upload ainda pendente usa a operação autorizada. O visualizador existente recebe leitor e sessão, com TTL, reautorização, invalidação e limpeza de cache.

Imagem da pergunta usa FormsQuestionImageApi separado, purpose question-image no payload, versão de trabalho e item_id da projeção. O DTO aceita media_context ausente/null para compatibilidade e rejeita bindings fora da definição. Preserva status pending sem exibi-lo como ready. O editor só permite abrir mídia com rascunho limpo/contexto autorizado; salvar invalida esse contexto. Atualizar perguntas recarrega os IDs do servidor. O diálogo pausa autosave e recarrega a projeção ao sair; fechar durante envio cancela o trabalho local, sem afirmar sucesso remoto. Exclusão de pergunta/imagem usa o comando de backend próprio.

Wiring reservado ao C0:

```dart
FormsEditorPage(api: formsApi, formId: formId,
  mediaSession: formsMediaScope?.current)
FormResponsePage(api: formsApi, occurrenceId: occurrenceId,
  mediaSession: formsMediaScope?.current, mediaReader: formsMediaReader)
```

Não alterei router. Candidatos G5: 140547 corrige identidade estável/FK e projeção; 140548 (c82fa53f5) concilia finalize confirmado e exclusão nominal; 140549 (3f494eb51) solta bindings de question-image deleted também por mismatch/expiração. Revisão estática de compatibilidade feita, sem presumir aplicação SQL. C0/G0 mantêm fila e pgTAP.

Validação atual: **376 testes únicos PASS, 0 FAIL** neste pacote: 16 uploader/UI, 54 API, 35 reader, 115 editor, 130 resposta, 21 visualizador privado e 5 DTO. Flutter terminou exit 0 (sessão 65667); DTO inicial teve 3 PASS/2 FAIL porque requireOnlyKeys exigia o campo opcional, corrigido e rerun 5 PASS/0 FAIL. Reruns não somados. Casos incluem pergunta/diálogo 375 px a 200%, Galeria confirmada, exclusão de imagem da pergunta, sessão revogada durante picker, PUT incerto, finalize incerto, TTL e cache. Análise focal final: exit 0, sem issues. Slot G3 liberado às 12:14 BRT.

Logs: forms-media-tests.log, forms-media-dto-tests.log (falha resolvida), forms-media-dto-final.log, forms-media-analyze-final.log. Não somar os 115 testes do editor com os 112 do pacote anterior; há sobreposição explícita.

Pendências: runtime/CRUD/reload/cross-tenant reais; aplicação dos candidatos pelo C0; upload de Foto/câmera; upload de resposta anônima, pois o host atual não mantém edit_secret; exclusão física e ciclo remoto de expiração. Nenhum upload remoto foi realizado nesta prova. Não há arquivos privados, segredos, URLs reais ou dados pessoais nos logs.

H19/H20, inspeção independente: router de Medicação não passa responsibleOptions, mantendo default vazio; a reprodução com destinatário válido ainda é necessária. MedicationEvidenceCommand e diálogo de dose atuais são outcome/reason/note, sem asset. Aceite textual não certifica imagem da dose. Nenhuma alteração nessas superfícies neste pacote.

Memória: comportamento segue fontes existentes; nenhum novo requisito durável foi inventado. Contratos SQL e deltas persistentes ficam com G5/C0. Nenhum arquivo de memória criado apenas para registrar atividade.
