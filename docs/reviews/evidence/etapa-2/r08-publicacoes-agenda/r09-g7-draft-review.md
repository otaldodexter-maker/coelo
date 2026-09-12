---
source: "G7 R09 drafts at b99a67f4e01eecb1e8cdaaf425387285f5829078"
status: "reviewed-read-only; final-package-accepted"
generated_at: "2026-09-12"
---

# Revisão independente dos drafts R09 do G7

Recorte: detectar comandos que repetem provas válidas ou avançam depois de um
gate bloqueado. Arquivos do G7, rastreadores, Flutter, Chrome e remoto não foram
alterados.

## Pontos corretos

- R09 não é iniciada pelo draft.
- C0 continua autora exclusiva de `dev`, inventário, rastreadores e fila SQL.
- O censo usa base fixa e mudanças posteriores recebem prova focal.
- O critério geral manda parar no primeiro gate não satisfeito.

## Correções enviadas ao G7

1. H28, avaliações e E2E devem primeiro reconciliar o fechamento R08 e executar
   somente o primeiro gate ainda aberto; a redação não pode ordenar nova prova
   de candidato/teste que já tenha sido fechada nesta rodada.
2. E2E deve partir de `action_id` explicitamente pendente e reutilizar prova
   válida quando não houver delta.
3. A frente G6 precisa de prompt próprio. Os seis R param até decisão do Owner
   sobre path/componente, recorte e geometria do rodapé para cada arquivo; nenhum
   R pode ser regravado antes disso.
4. Depois da decisão, somente delta e rebaseline seletivos, preservando os A+,
   a ordem intercalada e o limite agregado de 10.000.
5. `circulars.attach` pela UI é gate independente no runtime 3014, com nova
   fixture autorizada e retida. Preflight e smoke API 16/16 permanecem válidos
   e não devem ser repetidos sem delta.
6. `shell.load/read_at` é prova complementar somente quando houver evento; não
   cria novo `action_id`.
7. P50, 10.000 versus 4.000, provas R06/R08 sem delta e cleanup antecipado do
   manifesto ficam fora da repetição.
8. O SHA remoto revisado contém apenas quatro seções de prompts; a entrega final
   deve materializar G0 a G8 sem omitir G6 ou agrupar responsabilidades de modo
   a perder posse e critério de parada.

Parecer sobre `b99a67f4e`: plano aproveitável com correções; prompts ainda não
aceitos como pacote final até os nove recortes e a parada visual de G6 estarem
explícitos.

## Corretivo e aceite

`22d119de53e743b76c9c3516f504d2804d78740a` incorporou reconciliação R08,
reuso de provas, `action_id` explícito, censo na primeira janela e o gate G6
completo. A revisão encontrou ainda o bloco legado `G1 + G4 — avaliações`, que
duplicava os prompts individuais e poderia repetir o runner.

`4e5fd717709602ba30d62b5af094a529eb21d82a` remove somente essa duplicata. A
estrutura final contém exatamente C0 e G0 a G8; G6 para diante da decisão do
Owner e não reabre API, P50, 10.000 versus 4.000 ou provas sem delta.

Parecer final: pacote aprovado para integração pelo C0; R09 permanece não
iniciada.
