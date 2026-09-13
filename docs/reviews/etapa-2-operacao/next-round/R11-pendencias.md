---
source: Owner R11 2026-09-13; R11-checkpoint.md; inventario-etapa-2.json; evidence/etapa-2/r11-coordenacao
status: encerrada; entrega parcial documentada
generated_at: 2026-09-13
---

# R11 — pendencias preservadas

Entrega parcial; nao iniciar R12/Etapa3 por este registro. Retomar somente com instrucao explicita, confirmando origin/dev atual, cota e slots. Reutilizar quatro candidatos/testes locais e IDs retidos; nao reaplicar SQL61/62/63 nem criar duplicatas.

| apps/superadmin > menu > tela/subtela > action_id | FE / BE / E2E | Primeiro gate e responsavel |
|---|---|---|
| Meu perfil > Identidade/acesso > account.profile | parcial / parcial / pendente | Owner resolve PITR; C0 aplica candidato sigla/cor/metadados, prova headers/reload e implementa catalogo/gateway R2 de foto, bind/remocao/limpeza/variantes; testar outra sessao sem identidade residual |
| Auth > Recuperar > auth.recover | verified historico / pendente / pendente | Owner disponibiliza caixa/configuracao de e-mail; C0 recebe mensagem real apos pedido normal. SMTP proprio ausente; caixa acessivel nao recebeu. Nao contornar com Admin API |
| Auth > Redefinir > auth.reset | verified historico / pendente / pendente | C0 usa link real na UI, nova senha/sessao, expiracao/uso unico; atualizar arquivo privado se trocar senha. Redirect local3000 ausente da allowlist |
| Estrutura > Atividades > Configuracao > activities.assessment | pendente / local-green8pgTAP / pendente | C0 aplica20260913143441 apos gate remoto, UPDATE mesmo b04c879e, reload dos periodos; SQLSTATE23503 identificado apenas localmente |
| Estrutura > Atividades > Publicar > activities.publish | local-green historico / done historico / pendente | C0 fecha configuracao/publicacao coerente; atividade retida ja active, nao alternar status para produzir contagem |
| Estrutura > Avaliacoes > Entrada > assessments.entry | pendente / local-green / pendente | C0 aplica20260913145023, aluno aparece pelo modo all sem participante individual novo |
| Estrutura > Avaliacoes > Diario > assessments.gradebook | pendente / local-green / pendente | C0 salva nota no diario d2c945d8, sem recria-lo |
| Estrutura > Avaliacoes > Detalhe > assessments.detail | pendente / local-green / pendente | C0 rele nota e snapshot no mesmo diario |
| Estrutura > Avaliacoes > Fechar > assessments.close | pendente / local-green / pendente | C0 fecha estado/versao e rele |
| Estrutura > Avaliacoes > Reabrir > assessments.reopen | pendente / local-green / pendente | C0 reabre/rele e prova escopo remoto alheio negado |
| Estrutura > Turmas > Contadores > groups.list | pendente / local-green10pgTAP / pendente | C0 aplica20260913143659, compara linksativos/heranca e UI/reload, preservando turma sintetica |

Todos os candidatos SQL aguardam requisito de PITR. Backups logicos foram preparados, mas nao substituem esse requisito explicito. C0 nao presume resposta ausente como autorizacao; conflito ADR0034D8 versus promptR11 esta em docs/open-questions.md.

Foto: frontend ja conserva crop rasterizado sem duplicar transformacao e sinaliza ausencia de confirmacao; nao ha persistencia R2 implementada. ADR0032 exige masternormalizado/variantes64/128/256/512, MIME/bytes/dimensoes/checksum verificados, ownership/auditoria/retencao, leitura privada e limpeza. Nao usar Chat/Formularios como catalogo de Conta nem bucket publico. Conta nao ganha capa. A proxima estimativa depende desse contrato ainda nao existente, nao de quantidade de botoes.

Nao executados/condicionados: alternancia de identidade na R11 (prova R10 preservada, nao atual); entrega/reset real; cadeia remota de configuracao/notas/fechar/reabrir; remoção de foto persistida; grupos reais de permissoes aposSQL. Plano UI31:11P/5F/14B/0S/1U. Flutter59P e pgTAP41P separados; nao completam E2E. Ocorrencias legadas do validator visual20 fora de Conta permanecem fora do recorte, sem mascaramento.

institutions.status/locations-map nao foram abertos: condicao A0/A/B/C/D concluidos com margem nao ocorreu. Referencia de chat `docs/design/chat-media-composer-owner-reference-20260913.md` preservada, pendente na Etapa2 futura; nao e render A nem implantacao. Anexos do Owner permanecem na conversa, sem inventar arquivo binario nao fornecido.

Build/runtime e preservacao: r11-account-v3/d20bcfcf2/JS1dd04dca..., Python39272/3000; QAChrome31192/CDP9427, OwnerChrome18924 intocado; Flutter livre. Espelho localcoelo_r11 e builds/env/backups preservados. Uma worktree, stash vazio no checkpoint; branches historicas nao apagadas. Base de retomada e origin/dev atual, nao SHA antigo de handoff. Ver R11-fechamento.md, build-manifest.json, backup-manifest.json, closure-metrics.json e entrega-atual.json. Push nao e deploy.

Fechamento registrado em 2026-09-13T15:42:06.430654+00:00 (114.46min desde T0). Gate apos commit/push f4d602f2e9f1aee24b24f5c202bf8f5641d23977: PASS DOCUMENTED_PARTIAL, exit0. Cota final medida92% usados, abertura87%, consumo5p.p.; mesma janela/reset. HEAD/origin-dev sem divergencia e checkout sem WIP no gate. Este registro documental sera publicado e o gate repetido na base final, sem rerun de testes de produto. Retomada somente mediante instrucao explicita; R12/Etapa3 nao iniciadas.

## Destino das pendências R11 — decisão Owner 2026-09-13

As pendências remanescentes foram transferidas para [R12-pendencias-herdadas-R11.md](R12-pendencias-herdadas-R11.md), itens R12-46 a53, com responsável C0 R12, estados e primeiro gate preservados. R11 permanece encerrada parcialmente; esta atualização não inicia R12, não aplica SQL e não altera percentuais. O compositor de chat R12-52 deve ser coordenado com o contorno R12-43.
