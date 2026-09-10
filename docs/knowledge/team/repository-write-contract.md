---
title: "Contrato de escrita de repositório — a implementação de referência"
knowledge_id: "repository-write-contract"
source: "docs/reviews/etapa-2-operacao/reports/E2-noturna-idempotencia-escrita-20260909.md"
status: "draft"
generated_at: "2026-09-10"
updated_at: "2026-09-10"
audience: "team"
surfaces: [frontend, integration, documentation]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Contrato de escrita de repositório

Quatro repositórios precisaram da mesma correção numa única noite — Agenda,
Planos, a mídia de Cardápios e o diretório de Atividades. Um quinto,
`supabase_institution_directory_repository.dart`, já fazia tudo certo. Este artigo
registra o que ele faz, para que o próximo repositório copie em vez de redescobrir.

## As quatro regras

**1. A intenção de escrita pertence ao comando, não à tentativa.**
A chave de idempotência é memorizada por assinatura do comando e reusada enquanto
ele não confirmar. Gerar uma chave nova por chamada faz toda repetição chegar ao
servidor como intenção diferente. Em atualização o `expected_version` ainda barra a
repetição; em **criação e publicação não há revisão esperada**, e um retry após
falha incerta executa a operação duas vezes.

**2. Resultado incerto preserva a intenção; rejeição do servidor a descarta.**
São casos opostos e não podem compartilhar tratamento. Indisponibilidade e timeout
significam "pode ter sido gravado" — a intenção fica. Rejeição explícita significa
"nada foi gravado" — a intenção sai. O repositório de Instituições marca isso com
um comentário no `rethrow`: *the write may already be committed*.

**3. Falha de transporte é resultado, não exceção que escapa.**
Capturar só `PostgrestException` e `FormatException` deixa `ClientException` subir
crua até a UI. **Mas alargar a captura sem preservar o que já tem significado
próprio é pior que o defeito:** no diretório de Atividades, um `on Exception`
ingênuo transformou negação de autorização em indisponibilidade, e três casos de
`SAI_*` ficaram vermelhos na hora. A ordem correta é: tipos de domínio primeiro,
com `rethrow`; depois o específico do provedor; só então o amplo.

Atenção ao detalhe de Dart: `TypeError` e `StateError` são `Error` e **não**
`Exception`. `on Exception` não os captura, então cláusulas existentes para eles
devem permanecer.

**4. O recibo é conferido antes de virar estado local.**
O repositório de Instituições relê o registro e compara identidade antes de
devolvê-lo. Sem isso, uma resposta que não corresponde ao pedido entra no cache
como se fosse o registro salvo. Em Cardápios a divergência de recibo era critério
de aceite explícito, e a primeira correção candidata descartava a intenção
justamente nesse caminho — o único em que a escrita pode ter ocorrido.

## Como verificar num repositório novo

- Para cada método que escreve: existe intenção memorizada, ou a chave nasce na
  chamada?
- O caminho de indisponibilidade preserva a intenção?
- Existe cláusula de transporte, e os tipos de domínio são preservados antes dela?
- O recibo é conferido contra o que foi pedido?

Um teste por pergunta, com controle negativo. Os quatro defeitos desta noite foram
encontrados por leitura e confirmados por teste que falha sem a correção.
