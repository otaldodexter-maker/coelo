---
source: R08 C0; G0–G8; base integrada e recibos por SHA
status: checkpoint-publicavel
generated_at: 2026-09-12
---

# Ciclo 120 — integração, correções e provas API

O ciclo iniciado perto de T0+120 publica após a correção do bloqueio de Turmas,
por volta de 13h. Corte de execução permanece 14h52:16 e fechamento 15h22:16.

## Verificação da base integrada

| Recorte | Base | Resultado |
| --- | --- | --- |
| Principal, anexo e visualizador administrativo | b85fd00e0 | 79 PASS, 3 arquivos, 10,046 s; análise focal 0 |
| Forms H12/H26 | f11eb76b8 | 273 PASS, 2 arquivos, 41,362 s; análise focal 0 |
| Grupos + H19 | 659860202 e WIP C0 | primeira tentativa 60 PASS/1 FAIL; H19 32 PASS; falha só no retry de Grupos |
| Grupos após correção C0 | diff deste ciclo | 29 PASS/0 FAIL, 14,130 s, native 0 |
| form-media conjunto | 659860202 | 54 PASS/0 FAIL, Deno com typecheck, 281 ms |

Os resultados não se somam aos reruns do autor nem a ciclos anteriores.
A análise global terminou sem issues, exit0, 126 s; a alteração final de Grupos
teve análise focal posterior também sem issues, exit0.
Logs completos acompanham este recibo, inclusive tentativas inconclusivas e falhas.

G1 chegou a um testStart sem testDone no novo retry; os marcadores anteriores
não eram a suite concluída. C0 reproduziu e rastreou um loop real: source de
catálogo recriado a cada build → didUpdateWidget recarrega → seleção publicada
→ setState pai → outro source. O cache por reader elimina o loop. A publicação
inicial do filho durante build também foi corrigida com guarda de seleção e
pós-frame somente na fase de build. Dois oráculos do harness foram corrigidos:
vazio é string vazia; seletor só existe na etapa Vínculos. O retry final prova
create único, mudança de nome, recusa B→A e mesmo ID/versão.
Residual G6: mesma escolha com label/kind novos ainda não atualiza o snapshot
retido no pai; isso será corrigido no próximo gate, sem risco de autorização.

## Produção e limites de aceite

Lote58 aplicado com backup, 68/68 pgTAP e ledger: ver lote58.md.
G4 confirmou retirada200, feed ausente e leitura403 por outro consumidor.
Leitura200 do próprio autor é permitida pelo contrato; o oráculo errado ficou
preservado. BE local-green restaurado; não é novo done/E2E.

form-media v17 ACTIVE, verify_jwt=true, bundle
ea77bf6721130bb0717dae4bcd4dff7ee8350727c0842d26d3d1fc16e243a762.
Deploy CLI exit0, OPTIONS3014/prod204 com origem exata, externo403.
O finalize de answer-image retorna o DTO confirmado com actual_byte_length;
fresh e replay reautorizam. G5 revisou f0c7269fd. O smoke de question-image
já passou; answer-image ainda prepara fixture própria. Não misturar os ramos.

Smokes reais G4: Acontece23, Agora19, Cardápios24 checks; Chat primeira
tentativa27PASS1FAIL de oráculo e continuação26PASS0FAIL nos mesmos IDs.
São operações, não número de testes distintos. URLs tiveram TTL real medido.
Cross-tenant real e UI não foram certificados; Agora24h continua pendente.

## Frentes e próximos gates

- G0: espelho e question-image entregues; prepara fixture answer-image.
- G1: consumidor de Local integrado e retry corrigido C0; comparação45A na fila.
- G2: P51 não executado apesar das retomadas; execução temporariamente G5.
  G2 continua responsável pelo contrato e preparação de convite expirado.
- G3: H12/H26 e H19 local integrados; edit_secret anônimo em teste.
- G4: Principal e smokes publicados; reconcilia perguntas formais.
- G5: SQL58 e reviews entregues; executa P51 nominal sem duplicar G2.
- G6: correções produtivas/A+ integradas; revisões locais continuam.
  Incidente: circular archived/deleted_at, asset READY70bytes, cleanup não tentado.
  Houve exclusão lógica contrária à retenção, sem exclusão física medida.
- G7: sessões preservaram a sessão preexistente; revokeOthers não executado.
  Review H19 não atribui autoridade clínica a responsáveis.
- G8: contagens reconciliadas; Spark100% registrado; sem novo Flutter.

Não há nova promoção FE verified, BE done ou E2E. O único avanço contado
até aqui em FE local nesta rodada continua chat.attach; retiradaMomentos é
regressão resolvida, não ganho líquido. Os sete percentuais permanecem separados.

H19 exige definição nominal de quem pode ser responsável do plano. Fontes020
e especificação final01/09 listam o campo sem definir categorias; nenhum schema
ou concessão foi inventado. Pergunta registrada em open-questions.
