---
source: Owner 2026-09-13 — transferir pendências R11 para R12; R11-fechamento.md; R11-pendencias.md; R12-owner-items.json
status: backlog R12; transferência autorizada; execução não iniciada
generated_at: 2026-09-13
---

# R12 — Pendências herdadas da R11

O Owner transferiu as pendências da R11 para a R12. Este é o destino operacional
dos itens ainda abertos; os documentos R11 permanecem como evidência histórica.
Inclui os 11 action_ids focais, a dependência de aplicação SQL, a referência de
chat preservada e a opção vizinha estritamente condicional. Os 45 apontamentos
R12 anteriores permanecem; os oito registros abaixo elevam o catálogo a 53
compromissos, sem criar action_ids ou aumentar denominadores de produto.

Responsável: C0 R12, após abertura explícita. Confirmar origin/dev atual, cota,
runtime e slots; não copiar os limites numéricos da R11 como orçamento R12.
Transferência não inicia execução, não altera autorizações remotas e não resolve
o conflito de PITR por inferência. Etapa 3 permanece fora.

| Item | apps/superadmin > menu/tela/subtela | action_ids | FE / BE / E2E herdados | Primeiro gate |
|---|---|---|---|---|
| R12-46 | Meu perfil > identidade, cabeçalhos e Meu acesso | account.profile | Parcial: rodapé/busca, nome, crop e confirmação autoritativa testados. / Sigla/cor/metadados em candidato local; foto R2 ausente. / E2E pendente | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. |
| R12-47 | Auth > recuperar e redefinir senha | auth.recover, auth.reset | Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / E2E pendente | Obter acesso/configuração de caixa/SMTP/redirect; usar link real na UI e provar nova senha/sessão, expiração/uso único; preservar credencial QA privada. Não usar link Admin API como entrega SMTP. |
| R12-48 | Estrutura > Atividades > configuração e publicação | activities.assessment, activities.publish | UPDATE do rascunho retido falha; publicação sem novo aceite. / Correção causal local8/8 pgTAP; publicação BE done histórico. / E2E pendente | Aplicar candidato após gate SQL; salvar/reler o mesmo b04c879e e fechar a cadeia de configuração/publicação. Atividade95b98978 já active: não recriar ou alternar status para inflar avanço. |
| R12-49 | Estrutura > Avaliações > entrada, diário, detalhe, fechar e reabrir | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | Aluno ausente reproduzido; prova remota pendente. / Candidato all/selected13/13 pgTAP; local-green preservado. / E2E pendente | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| R12-50 | Estrutura > Turmas > contadores | groups.list | Zeros incorretos reproduzidos; UI/reload pendentes. / Candidato10/10 pgTAP para contagens, herança, status e isolamento. / E2E pendente | Aplicar projeção após gate SQL e conferir contadores na turma4214106c com vínculos ativos e reload. Aceite antigo da listagem não cobre contadores. |
| R12-51 | Integração > quatro candidatos SQL e requisito PITR | Gate/condição, sem novo action_id | Não aplicável. / Quatro candidatos locais; nenhum aplicado remotamente. / E2E pendente | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |
| R12-52 | Coelo (Principal) > Chat > compositor e múltiplas mídias | chat.attach | Direção visual registrada; não é render A nem implementação. / Contrato existente a preservar e verificar no recorte. / E2E pendente | Reutilizar chat-media-composer-owner-reference-20260913.md: foto inline maior, vídeo com play/duração, mosaico e escrita em cápsula. Coordenar com R12-43 (contorno), sem duplicar aceite nem alterar formulários administrativos globalmente. |
| R12-53 | Estrutura > Instituições > ação vizinha condicional | Gate/condição, sem novo action_id | Não iniciada; condição de abertura não atendida. / Não iniciado. / E2E pendente | Somente considerar institutions.status OU institutions.locations-map após concluir Conta/Auth e os três blocos de Estrutura, com margem e escopo R12 autorizado. Não promover esta opção a tarefa obrigatória nem abrir outro macrotema. |

## Reutilização obrigatória

- Código e provas entregues em dev até2d425246c na R11; confirmar o HEAD atual
  antes de executar. Não voltar a worktrees/SHAs antigos de handoffs.
- Candidatos em packages/coelo_database/candidatos:20260913143441 (UPDATE
  configuração),20260913143659 (contadores),20260913144142 (sigla/cor/acesso),
  20260913145023 (diário all/selected). Não reaplicar SQL61/62/63. Espelho local
  próprio coelo_r11 e manifesto de167 migrations preservados; repetir testes
  somente se a base/código/risco exigir, sem somar reruns.
- Configuração b04c879e-bedd-4e45-9358-66c545215646; atividade
  95b98978-19e2-43ba-aa0c-70ae81557e08; diário
  d2c945d8-3809-4d84-b836-2bc6da7c381d; turma
  4214106c-46a2-4bf4-84ba-9c6a619bd486. São sintéticos retidos; não recriar.
- Foto exige R2 privado, catálogo/ownership, bytes/MIME/dimensões/checksum,
  variantes64/128/256/512, bind, remoção, retenção e limpeza da ADR0032.
  Crop e mensagem honesta existentes não são persistência implementada.
- Provas e limitações: [fechamento R11](R11-fechamento.md),
  [pendências históricas](R11-pendencias.md),
  [plano UI](../../evidence/etapa-2/r11-coordenacao/ui-acceptance-plan.json),
  [manifesto do build](../../evidence/etapa-2/r11-coordenacao/build-manifest.json)
  e [backups](../../evidence/etapa-2/r11-coordenacao/backup-manifest.json).
  PID/porta/backup são snapshots: conferir antes de usar. Preservar Chrome do
  Owner, credenciais privadas e builds; push não é deploy.

## Ponte de avanço, sem recertificação

Base herdada: FE verified175/231 (75,76%); BE done159/224 (70,98%);
E2E148/199 (74,37%). FE local-green12/56 pendentes (21,43%);
BE local-green21/65 pendentes (32,31%); aprovação visual54/231 (23,38%);
cobertura SQL181/224 (80,80%). Visual/SQL preservam os IDs históricos.
Transferência: delta funcional0, nenhum novo aceite ou teste executado.
R11 preserva59 casos Flutter e41 asserts pgTAP aprovados, separadamente;
UI31 subaceites:11P/5F/14B/0S/1U. A R12 deve fechar os gates abertos,
sem chamar provas locais ou históricas de E2E atual.

As20 ocorrências legadas do validador visual fora de Conta continuam nos
rastreadores gerais; não se tornam escopo R12 integral por esta transferência.
Decisões abertas de R12-01 a45 permanecem no catálogo e em docs/open-questions.md.
