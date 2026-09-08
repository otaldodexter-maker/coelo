---
title: "Perfil — contexto e prévia da aba Circulares"
source: "Contrato existente de isolamento Coelo; TDD e revisão read-only E2E3"
status: "fatia local-green; baseline visual Perfil e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte

Aba Circulares do Perfil no menu Coelo (Principal) do Superadmin. Não altera
apps/principal, SQL, autorização, dados remotos nem catálogo. Ordem: reproduzir
swap e resposta tardia, corrigir lifecycle, regressão funcional/visual e revisão.
Critério local: itens, cursor e prévia não atravessam contexto; não promover E2E.

# Evidência

- Quatro REDs reproduzidos: repository novo retinha itens/cursor; troca de scope
  não recarregava e aceitava sucesso ou negação tardios; prévia permanecia aberta.
  A prévia exigiu ajustar o fixture para View 1440/DPR1 antes do RED funcional.
- Comparação por quatro campos do scope evita reload em reconstrução equivalente.
  Reset limpa itens/cursor imediatamente e incrementa geração; conclusão antiga
  é ignorada. Paginação é single-flight; negação purga itens/cursor e prévia.
- A rota de prévia pertence à aba e fecha em swap, callback novo ou dispose.
  Callback de leitura é capturado; ações tardias verificam geração/contexto.
  Helper compartilhado preserva temas, focus traversal e reduced motion.
- Seis casos adicionados: quatro REDs e controles de scope equivalente/paginação
  concorrente e negação durante paginação com prévia aberta. 12/12 no arquivo.
- 135/135 testes não-golden de Circulares administrativas/Principal e Perfil;
  19/19 goldens de Circulares, incluindo Perfil/feed e prévia desktop.
- Perfil completo: 2 PASS / 10 FAIL. Contraprova com versão da6eb4cf, em três
  cópias temporárias encadeadas (surfaces, página e teste), também 2 PASS / 10 FAIL.
  Mesmas divergências: light375 22,12%/91265px e texto200 dark1440
  11,55%/199557px. Cópias removidas; nenhum baseline PNG alterado.
- Analyzer dois arquivos, format, diff check, validador visual e revisão
  independente read-only passaram. Suíte visual integral não está verde.

# Limites e memória

## Incremento — consumidor no feed de Acontece

O limite de ownership do FeedCard registrado abaixo foi corrigido no incremento
seguinte: três REDs item/callback/dispose, geração e rota própria também no card.
O modo contextualPreview=false continua direto, sem preview recursivo. A troca
de callback invalida conservadoramente a prévia; closures recriadas pelo
consumidor também contam como troca, não como prova de mudança de autorização.
Teste adicional do widget real de feed misto confirma troca para o feed B,
fechamento da prévia e rejeição de read capturado de A, com repositories fakes.
172/172 não-golden de Circulares/Perfil/Acontece, 19/19 goldens Circulares,
analyzer três arquivos, format/diff/visual e review read-only passaram.
Isso não fecha os baselines históricos do Perfil/feed nem gates de backend.

PrincipalCircularFeedCard fora da aba ainda não recebe automaticamente ownership
de contexto/rota na primeira entrega; esse limite histórico foi resolvido pelo
incremento acima, sem afirmar reautorização server-side ou E2E.
Não houve leitura de dados privados, envio ou mutation real. Memória no-op:
restaura regra existente, sem nova política. Evidência enviada ao Coordenador,
writer exclusivo dos rastreadores oficiais.
