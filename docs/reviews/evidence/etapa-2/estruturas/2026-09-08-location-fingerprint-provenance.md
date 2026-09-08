---
title: "LOC — proveniência dos dois fingerprints divergentes"
source: "inventário remoto0b7ab89a; LOC6b0cbb30; probe Auth47 Eng1d119cef3; inspeção remota de catálogo autorizada pela coordenação em 2026-09-08"
status: "diagnosed-read-only-no-candidate-change-awaiting-joint-review"
generated_at: "2026-09-08"
---

# Resultado

Os casos são diferentes: **#6 é somente EOL misto; #4 tem divergência semântica**.
Nenhum pin, migration canônica, candidatoLOC, CHILD78e, grant ou objeto remoto
foi alterado. Este diagnóstico não autoriza aplicar o candidato.

## Proveniência e autoridade

Os sete pins de LOC31000 nasceram em `0b7ab89a78361bbccf64bdb248ca901f9e6a3aa9`,
na seção de inventário remoto de
`docs/superpowers/specs/2026-09-07-location-catalog-sql-proposal.md`.
São MD5(pg_get_functiondef) remoto de 2026-09-07, documentados explicitamente
como não comprovação de equivalência textual às migrations. `ce318d05` levou
esses pins para o candidato; `6b0cbb30` não os mudou.

Fonte local real: Eng1 `d119cef32661d066f005d8e6c49a589e8129026f`, arquivos
`docs/reviews/evidence/etapa-2/engenheiro-1/loc-auth47-helper-fingerprints-2026-09-08.json`
e `loc-auth47-helper-fingerprint-evidence-2026-09-08.md`.
Auth47 passou somente sete verificações de existência, não sete fingerprints.
PG170006, postgres, search_path public/pg_catalog; cleanup próprio zero às
05:25:07Z. Não confundir com o replayLOC50 que falhou antes de TAP.

A coordenação autorizou inspeção remota somente leitura das duas assinaturas.
Consulta pelo plugin oficial Supabase, conexão existente, projeto produção
`evvbomzejfijozbtgvpt`, às **2026-09-08T05:28:22.102187Z–05:28:22.102286Z**.
Somente pg_proc/pg_get_functiondef/prosrc/owner/config/ACL e metadados de sessão;
nenhuma linha de pessoas, chamada funcional, DDL/DML ou credencial.
Ator postgres, PG170006; search_path da conexão registrado no JSON adjacente
(user/public/extensions), sem mudança de configuração remota.

Comparação semântica usa prosrc, independente do pretty-printer/search_path.
As duas assinaturas usam argumentos/retorno built-in; hashes de definição
normalizada ficam registrados como evidência adicional. Não presumir que essa
independência valha para qualquer assinatura com tipos definidos pelo projeto.

Metadata completa/diff sanitizado:
`2026-09-08-location-remote-canonical-comparison.json`, adjacente.
Corpos brutos ficaram apenas em memória da comparação; não publicados em
mensagens, logs ou Git. O diff contém nomes de campos e SQL, não valores de
pessoas. Nenhum padrão de segredo foi identificado nos dois corpos consultados.

## #6: writer legado, diferença de quebras de linha

Assinatura: `app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)`.
Última fonte canônica: `20260811194840_activity_files_identity_commands.sql:43–104`,
SHA256 dos bytes `3ab6f64f3f2d00fb6ff99fa6f1f3c929753bcf29f5b6506f62c95b50107474e9`.
O DO posterior desse arquivo apenas revoga privilégios, sem alterar corpo.

| Artefato | MD5 definição raw | MD5 definição CRLF→LF | CRLF no corpo |
| --- | --- | --- | ---: |
| Remoto observado, igual ao pin6b | 886752274164d0d435c9df8ced18d896 | 3167d90039df952c9ae561f28486223c | 54 |
| Auth47 Eng1 | 063138f31cff9ec6b5a2fe24ba036c56 | 3167d90039df952c9ae561f28486223c | 58 |

prosrc remoto normalizado CRLF→LF é **textualmente idêntico** ao corpo canônico:
2968 caracteres. Portanto não houve diferença semântica encontrada neste caso.
Owner postgres, SECURITY DEFINER, volatile, search_path vazio e ACL somente
postgres coincidem. Não concluir isso apenas comparando LF local ao pin raw:
foi necessário obter o LF remoto e comparar os corpos.

Proposta, não patch: para #6 somente, comparar definição normalizada CRLF→LF
ao hash remoto normalizado comprovado3167d90039df952c9ae561f28486223c,
mantendo assinatura/owner/ACL/config e todos os demais gates exatos. Não usar
trim, remover espaços, OR com hashes arbitrários ou normalização global de pins.
A mudança exige revisão conjunta e nova contraprova de drift antes de replay.

## #4: opções legadas, divergência de comportamento

Assinatura: `app_private.superadmin_get_activity_form_options(uuid)`.
Última fonte canônica na closure47:
`20260811200614_activity_read_model_contract_hardening.sql:123–205`, SHA256
`9e99d589ec89975110d3fcaef8c363701bd255b00072b99a4797a923458cea26`.
Substitui a definição de20260811193838; nenhuma redefinição posterior nominal
ou dinâmica desses dois helpers foi encontrada nas fontes revisadas antesLOC.
A definição remota também não é igual à definição antiga20260811193838.

| Artefato | MD5 definição raw | MD5 definição LF | prosrc LF caracteres |
| --- | --- | --- | ---: |
| Remoto observado, igual ao pin6b | 65fe6408f0f2c6b0c1c9d71a809f2d80 | 516a06602a96073317e495dbb9d5b040 | 3766 |
| Auth47/canônico | 70700ddc38d42df4fae75765b7ff2617 | b951e603ef34b7d26597356a16eb6d06 | 4778 |

Diferenças após normalização exclusiva CRLF→LF:

- Em units, locations, groups e professionals, remoto usa
  `p_institution_id is null OR resource.institution_id=p_institution_id`.
  Canônico exige `p_institution_id is not null AND ...`.
  Assim parâmetro nulo permite agregação sem esse filtro institucional no
  remoto, enquanto canônico devolve arrays vazios nessas quatro seções.
- Remoto não contém a seção students existente no canônico, que projetaria
  child_group_link_id/child_id/group_id/name/age/gender. Não restaurar essa seção.
- Guard inicial activities.read, filtro institutions, taxonomy/templates e
  demais linhas fora do delta permaneceram iguais na comparação LF.

Não há prova neste pacote da origem/decisão que introduziu esse delta remoto,
nem teste funcional de exploração. Não chamar a migração histórica de estado
correto por presunção, nem afirmar que o contrato remoto inteiro foi aprovado.

## Como LOC31000 trata #4

LOC v2 não chama esse helper nem usa suas opções para autorizar seu gateway.
Entretanto ele é SECURITY DEFINER e o wrapper público mantém EXECUTE para
authenticated. Revogar SELECT da tabela não impede sua consulta privilegiada:
o fechamento legado é necessário para impedir descoberta dos novos locais.

Em LOC31000:518–520, a transformação pretende trocar **somente** a expressão
JSON locations por `'locations','[]'::jsonb`, preservando os demais campos.
Lines522–537 exigem uma ocorrência exata e depois ausência de qualquer
referência `public.activity_locations`. Writers legados são fechados à parte.

A regex candidata exige o trecho canônico
`and location.institution_id=p_institution_id and location.status='active'`.
O remoto possui `or location.institution_id=p_institution_id) and ...`.
Contagem **offline**, usando a regex candidata com tradução POSIX-space para
whitespace JavaScript: canônico1, remoto0. Não é execução do regex PostgreSQL.
Pela diferença literal, carregar o snapshot remoto sem rever a transformação
reproduz outro RED esperado: `location legacy closure pattern drift`.
Trocar apenas o pin4 pelo hash do replay esconderia a incompatibilidade.

Garantias LOC dependem de zerar locations e remover toda consulta ao catálogo,
não do comportamento ORNULL das outras três seções nem de students.
O escopo aprovado diz preservar demais payloads/assinaturas/ACL; portanto
não mudar esses ORs, restaurar students ou ampliar acesso durante o cutover.

## Menor prova local proposta, ainda sem implementação/autorização

1. Eng1 conserva Auth47 canônico e seus hashes como baseline identificado.
2. Reservar uma fixture de snapshot local isolada para **somente #4**, obtida
   da definição remota revisada. Pin de entrada é catálogoAuth47; pin de saída
   é snapshot remoto completo/metadata. Não reescrever migration histórica.
   Não executar no remoto. O arquivo/harness precisa preservar os bytes/EOL
   do corpo observado, ou declarar nominalmente a normalização e novos hashes.
3. Executar primeiro contraprova do candidato atual: documentar rejeição #6EOL
   e regex#4, sem mascarar RED. Snapshot sozinho não é alegação de GREEN.
4. Após revisão conjunta E2E2/E2E5, reservar patch candidato que remova somente
   o bloco locations **da definição remota exata**, com preflight/pós-condição
   e diff garantindo todos os outros bytes/semântica preservados; #6 recebe
   somente o guard LF proposto. Não aceitar alternativamente a versão canônica
   com students como se fosse o mesmo contrato.
5. Reexecutar preflight, fechamento legado e regressões/negativas, incluindo
   opções com instituição nula e explícita, verificando locations vazio e
   demais seções preservadas, além da prova de isolamento do catálogo novo.

Isso prova o snapshot remoto em ambiente isolado, sem aplicar fonte histórica
sobre produção. Não cria decisão de produto: preserva o comportamento observado
fora do fechamentoLOC já reservado. Se for desejada alteração dos outros ORs
ou restauração de students, a decisão concreta do Owner é escopo de opções
legadas/PII infantil; deve virar pacote separado de E5, nunca efeito colateralLOC.

Revisão Mencius somente leitura confirmou fontes/ausência de redefinição e a
origem remota dos pins. Próxima decisão pertence à coordenação/review E5.
Gate de memória: evidência técnica de drift, nenhuma regra nova aprovada a
projetar para usuários. Os rastreadores centrais permanecem com a coordenação.
