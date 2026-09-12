---
fonte: C0; G1 bb6cca571 e341112bde; fixes9ea8d1a12/ecbcca06f; SQL20260910180350
status: revisao-concluida-fixes-prova-offline-verdes
data_geracao: 2026-09-12
---

# Revisão G4 do executor de Avaliações

Recorte C0: recuperação após save/activate, replay histórico, ACK/alvo e IDs
persistidos. Somente leitura; G4 não editou G1, não abriu credenciais e não
executou runner remoto, SQL, Flutter ou Chrome. Arquivo:
`docs/reviews/evidence/etapa-2/r08-estrutura/assessments_api_runner.py`.

## Achados concretos e correções

1. **Login falho encerrava plano parcial.** No bb6cca571:83/203–205, resume com
   login401 ou200 sem token pula o bloco autenticado, mas o elif do executor
   marca complete e sobrescreve manifesto antes de devolver1. Nova retomada é
   recusada. Fix9ea8d1a12 marca verified apenas após reload válido do diário e
   limita complete ao caminho200/verified. Inspeção atende o caso parcial.
2. **Diário persistido podia usar vínculo diferente do ACK atual.** No341112bde,
   plano compara atividade/instituição/unidade, sem assignment original. Dois
   vínculos da mesma atividade/unidade produzem o mesmo plano. Reutilizar um
   payload de diário persistido envia o vínculo antigo antes da comparação na
   releitura. Fixecbcca06f persiste/valida assignment_id e compara o payload
   inteiro expected_gradebook antes de save_gradebook, incluindo request_id,
   period/configuration,students,version e reason. Inspeção atende o caso.
3. **Saída da execução depende de contagem global de vínculos.** Emecbcca06f,
   execute valida assignment único pelo ID e pode chegar a complete com dois
   vínculos visíveis, mas o retorno final exige strict_projection=len1 e sai1.
   Isso mantém o residualG7#3 de protocolo. Encaminhado a G1/C0 para alinhar a
   saída ao alvo validado, sem ampliar mutações. Fixd59e17f62 usa conclusão do executor para saída execute; prova offline G4 abaixo.

G1 publicou quatro casos fake negativos emd59e17f62. G4 leu esses testes, sem
reexecutá-los, e produziu prova independente de dois workflows stateful conforme
pedido C0. Não somar os quatro testes do autor aos workflows deste relatório.

## Recuperação e replay inspecionados

- Manifest existente não é sobrescrito por invocação sem --resume. Resume
  exige execute/ACK/assignment explícitos e plano parcial habilitado.
- Fix341112bde valida os três UUIDs de comando e a igualdade do plano persistido
  com o plano esperado. Resume não cria novos IDs; plano é gravado antes do save.
- Save/activate/gradebook registram suas etapas e resultados antes de prosseguir;
  retomada relê IDs/estado/versão autoritativos. Falha após resposta perdida
  pode repetir a mesma chave e recuperar o recibo, sem resetar plano.
- O período da configuração ativa é conferido por ID em context_options,
  instituição/unidade/status open, antes de produzir diário.
- O replay de save ainda devolver draft depois de activate é correto: SQL
  assessment_v2_replay:248 retorna result_json histórico+replayed; save:470 e
  activate:593 consultam recibo antes de reaplicar mutação. Não trocar esse
  oráculo para active. O active_read separado comprova estado atual/versão.
- O backend revalida ator, hash, capability e escopo do recibo:235–247.

Isso é revisão de segurança operacional do executor, não certificado de API,
UI, cross-tenant ou liberação nominal para executar. Recibos e IDs devem ser
preservados; C0 mantém a decisão de execução. Nenhum contrato de produto novo.

## Prova offline G4 em SHA fixo

`assessments_runner_fakeproof.py` carrega o runner via gitshow, substitui env e
transporte por dados sintéticos, bloqueia urllib.request.urlopen e usa diretórios
temporários. Nenhuma credencial real é lida; não há chamada de rede, alteração
SQL ou arquivo G1 editado. O modelo mantém recibos imutáveis por comando/UUID e
falha se a mesma chave receber payload diferente. Isto testa recuperação do
cliente; o modelo não comprova a implementação do backend.

Dois workflows únicos:

1. Salvar persiste no modelo, mas a resposta se perde. O manifesto gerado pelo
   próprio runner fica planned. Login401 e200 sem token preservam executor/IDs
   e devolvem falha. Trocar assignment é recusado antes de qualquer replay de
   comando. Retomar o alvo original conclui com os mesmos IDs/plano: exatamente
   uma mutação modelada de save, uma de activate, uma de gradebook e três recibos;
   histórico save permanece draft, estado atual active e logout204.
2. Dois assignments visíveis, um alvo escolhido com ACK: só esse alvo recebe
   diário, executor termina complete e o processo retorna0.

Fonteecbcca06fd4d44e8866f210da38c305829f16281:0PASS/2FAIL/native1. Além da saída
errada com dois vínculos, o primeiro workflow revelou retorno0 para login200
sem token (estado parcial já era preservado pelo primeiro fix). A mensagem de
asserção foi explicitada e o diagnóstico repetido; não somar essa repetição.
Fonte d59e17f62c47d1df810fae50269395f5a21d2fda:2PASS/0FAIL/native0. O ajuste de
retorno do d59 corrige ambas as falhas de saída.

Manifests nativos: assessments-fake-red.json (primeiro diagnóstico),
assessments-fake-red-diagnostic.json (asserção explícita) e
assessments-fake-green.json. O campo actual_mutations do modelo significa
mutações simuladas; todas as três contagens são locais. environment e
network_requests=0 explicitam o limite em cada manifesto.

Achados atendidos na revisão focal; C0/G5 decidem o ACK e a execução remota
única. Não declarar Avaliações verificadas por estes dois workflows.
