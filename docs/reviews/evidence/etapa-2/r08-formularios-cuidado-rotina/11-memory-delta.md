---
source: "Gate coelo-knowledge; C0 R08; spec Formulários13/08; design-system seção17.1; código e evidências07–10 G3"
status: "proposta focal para C0 aplicar fonte antes da projeção; não altera documentos centrais"
generated_at: "2026-09-12"
---

# Delta de memória: anônimo, Foto e H25

Audiência: somente `team`. Não criar artigo admin/users sobre disponibilidade ainda sem prova da UI. Não criar ADR: não houve decisão nova do Owner sobre produto, privacidade ou autorização remota. Este delta documenta implementação aprovada e seus limites, sem transformar testes locais em certificação.

## Fontes consultadas e ordem de aplicação

Consulta oficial: `.agents/skills/coelo-knowledge/scripts/Search-CoeloKnowledge.ps1 -Query 'anônimo' -Audience team -Detailed -Root .` encontrou `superadmin-forms-production`, fonte `docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md`. Foram lidos o artigo, a seção Anonimato técnico, a seção Cloudflare R2, permissões e o código correspondente. O caminho abreviado `scripts/...` da skill é relativo à própria skill; a tentativa inicial pela raiz não executou consulta, depois foi corrigida.

Para H25, foram lidos `docs/design/design-system.md` seção17.1, `.agents/skills/coelo-ui/references/surface-interaction-contracts.md` e `docs/knowledge/team/coelo-admin-directory-composite.md`. A projeção atual deste último aponta à decisão do composto10/09, que não contém a nova geometria da alça. C0 deve primeiro incorporar a regra no design-system/referência visual; depois acrescentar a nota na projeção com fonte adequada, sem apresentar uma decisão histórica como se contivesse H25.

## Texto proposto para a fonte de Formulários

Na seção Anonimato técnico, substituir a frase histórica “segredo opaco retornado ao dispositivo” pela descrição compatível com o contrato existente e a implementação:

> O dispositivo gera32bytes aleatórios para o segredo de edição anônima e confirma sua persistência local antes de abrir a resposta. O servidor recebe o segredo no corpo do comando e persiste somente seu hash na resposta. A chave de armazenamento local é separada por projeto, conta e ocorrência; essa organização local não é enviada como vínculo entre identidade e resposta. Falha de armazenamento impede a abertura com um segredo temporário. Perder o segredo local continua tornando a edição irrecuperável.

Fundamento: a migration histórica `20260813155121_forms_commands_and_projections.sql` já exige `edit_secret` no payload de open/mutate, tamanho mínimo43 na representação textual e verificação contra hash; não retorna um segredo novo. Código atual: `forms_anonymous_edit_secret_store.dart` e `form_response_page.dart`, commits `72e6e6f22`/`8344cb98a`. A projeção já dizia “dispositivo gera32bytes”; a correção principal é conciliar a fonte, não duplicar conhecimento.

Após a fonte, acrescentar à projeção `superadmin-forms-production` somente a nota reutilizável de persistência local confirmada antes do RPC e separação das chaves locais, sem guardar IDs reais nem explicar isso como garantia de anonimato absoluto.

Na seção de mídia da fonte, acrescentar a regra de consumidor:

> A captura Foto usa a câmera e Galeria seleciona arquivo existente. O resultado capturado segue o mesmo preparo, PUT com upload_url/required_headers e finalização pelo gateway privado. Troca de formulário, encerramento da sessão, cancelamento ou saída do aplicativo encerram a câmera; resultados tardios são descartados e seus bytes limpos. A atualização visual após purge respeita o descarte da árvore Flutter.

A distinção Foto/Galeria já está na fonte e na projeção; não precisa de artigo novo. A frase de lifecycle é orientação interna sustentada pelo código/parecer. Evidências: `08-camera-result.md`, `09-camera-purge.md`, `d3d3d5d63`, `725155ec0` e `d4c71277d`; review G4 `b58cbaec9`. Não declarar captura física/browser provada. Não afirmar edição simultânea entre abas nem conclusão do wiring por inferência.

Cardinalidade: a fonte13/08 contém Foto/Galeria até5, enquanto o contrato executável preservado de Foto usa1. C0 já determinou preservar Foto1 e não ampliar por fonte antiga. Esta proposta não reescreve a regra para5 nem trata a limitação da implementação como nova decisão de produto; C0 deve reconciliar a referência aprovada mais recente antes de alterar cardinalidade canônica. Limites de imagem, conversão HEIC e provas do gateway permanecem subaceites separados.

## Texto proposto para design-system17.1 e referência visual

> A coluna redimensionável reserva uma faixa interativa própria de48px para a alça, sem sobrepor a área interativa de ordenação. A pintura do cabeçalho conserva a largura integral aprovada, em camada sem hit testing; não se deve reduzir o texto ao reservar os alvos. O indicador visual permanece estreito e alinhado à borda. Colunas com largura mínima igual à máxima não oferecem redimensionamento sem efeito. Nome e direção da ordenação permanecem acessíveis sem duplicação da camada visual.

Incluir imediatamente o limite de aplicação, para não generalizar o aceite:

> A faixa de48px não certifica sozinha todos os alvos do cabeçalho: uma coluna de80/90px deixa apenas32/42px para ordenar. Esses consumidores exigem revisão específica de composição/largura; não ampliar seus mínimos silenciosamente.

Fonte executável: `54c892ebc` com correção visual obrigatória `f0e148a70`, `10-h25-inspecao.md` e `12-h25-paint.md`; review G4 inicial `d5aa7e253`. O pacote inicial reduziu texto e falhou nos goldens integrados; o followup preserva as referências existentes. Em Formulários foram medidos toque e rótulo em375/1440. Contraste e AA de todos os consumidores não foram certificados. Depois da fonte, a projeção do composto pode resumir a reserva sem sobreposição e a ausência de alça em largura fixa, com link à seção canônica e sem números de testes efêmeros.

## Validação e resultado do gate

Validador da base atual:64artigos válidos, exit0. Suite da ferramenta:13casos,12PASS/0FAIL/1SKIP (host não permite symlink), exit0; log `11-memory-tests.log`. Cenários do wrapper também passaram. Esses testes validam estrutura/consulta, não aprovação do texto nem ausência absoluta de dados sensíveis.

G3 não editou fonte/projeção porque C0 é escritor central. Entrega: delta concreto pronto para aplicação, com fontes, audiência e limites. Nenhum JWT, segredo de edição, ticket assinado, fixture identificável, dado de criança ou conversa bruta foi capturado na memória.
