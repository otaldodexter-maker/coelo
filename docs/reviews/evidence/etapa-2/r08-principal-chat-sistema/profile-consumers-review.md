---
fonte: C0; baseline20260910000000; codigo d5aa7e253
status: varredura-concluida-correcoes-local-green
data_geracao: 2026-09-12
---

# Varredura dos consumidores de ProfileAbout

Recorte autorizado: apps/superadmin/lib e test, todos consumidores/expectativas
ProfileAbout/get_profile_about; sem edição de router, Pessoas/G2 ou contrato SQL.
Busca literal por get_profile_about, parseProfileAboutReadResponse e
SupabaseProfileAboutRepository encontrou somente adapter, auth_scope e teste do
adapter. Busca complementar por ProfileAbout/profile_about cobriu apresentação,
composição e censo de contratos, inclusive o domínio separado de Atividades.

## Contrato de leitura

A única declaração localizada nas migrations é a baseline20260910000000:21947.
Retorna null em21956/21975; objeto plano em21979 com id,subject_type,subject_id,
version,state; fields usam key e sections usam type21980/21983.

| Consumidor | Resultado da inspeção |
| --- | --- |
| SupabaseProfileAboutRepository | Único adapter RPC; guard subject id/type já corrigido em b58cbaec9. Fallback de tabelas usa parser de colunas separado. |
| superadmin_auth_scope → SuperadminApp → router | Injeta a mesma porta; não remonta envelope JSON. Somente leitura G4. |
| PrincipalProfileEditPage | Usa página de domínio e confirmação condicionada à releitura; papel/escopo corrigidos b58cbaec9. |
| PrincipalProfileRoutePage | Usa página de domínio; achado real: omite roleCode/scopeKind no didUpdateWidget126–132. C0 autorizou correção mínima e2REDs. |
| profile_about_editor / labels / PrincipalProfilePreviewPage | Recebem objetos de domínio e projetam audiência; sem desserialização RPC. |
| Testes do adapter | Canônico plano e negativas. parseProfileAboutPage(field_key/section_type) testa legitimamente o parser de tabela; não converter esses oráculos para key/type. |
| Testes de rota, responsividade, preview e affordance do editor/Perfil | Stubs devolvem ProfileAboutPage/null/exceções; não são fixtures de transporte nem precisam campos JSON novos. |
| ActivityProfileAboutRepository e consumidores | Contrato separado load(institutionId,activityId)/save(page...). Produção permanece Unavailable; fixtures de desenvolvimento usam domínio. Não ligar ao adapter por coincidência de nome. |

Nenhuma outra expectativa positiva de envelope antigo foi localizada. O caso
negativo {'page':'nao e objeto'} continua legítimo: exige FormatException.
Nenhum oráculo foi alterado para esconder bug. O teste novo da view exige limpar
bio ao trocar só papel/tipoescopo, reler e ignorar resposta anterior depois de
nova troca negada. Execução concluída no slot C0: RED2→GREEN16PASS/0FAIL, incluindo os14existentes.

## Censo estático de contrato — encaminhado ao C0

`test/contracts/rpc_contract_test.dart:112–125` ainda excetua três tabelas de
Sobre com comentário de inexistência. A baseline cria profile_about_pages:11971,
profile_about_sections:30355 e profile_about_structured_fields:30386.
O scanner de relações295–296 não aceita os identificadores entre aspas do dump;
por isso a presença canônica não necessariamente retira essas exceções.
O scanner de funções191 também não aceita nomes entre aspas; argumentos205–212
precisariam normalizar quoting se essa leitura for ampliada.

Além disso, linha301 normaliza caminho com replaceAll(r'', '/') e não com
barra invertida. Isso insere separadores entre caracteres e não exclui /tests/;
declarações pgTAP podem participar indevidamente do censo de relações.

C0 concedeu posse focal do teste compartilhado a G4, mantendo G8 fora desse
arquivo. Correção implementada: reconhece identificadores SQL entre aspas,
normaliza nomes de parâmetros e caminho Windows, remove somente as três
exceções de Sobre comprovadas pela baseline. Três fixtures temporárias testam
relações quoted/unquoted, função quoted com parâmetros/defaults e exclusão de
pgTAP sob o caminho nativo. Não são novas tabelas remotas nem alteração SQL.

RED3FAIL esperado; GREEN7PASS/0FAIL no arquivo inteiro (3novos4existentes).
Nenhuma falha nova real apareceu no censo com o parser corrigido. Não houve
relaxamento de assinatura nem edição de listas amplas para forçar verde.

Validação local: dois arquivos executados separadamente,16+7=23IDs únicos,
5novos18existentes; sem somar reruns. Logs profile-view-context-red/green.jsonl,
profile-contract-scanner-red/green.jsonl; analyze3arquivos sem problemas/native0
em profile-consumers-analyze.log. Slot devolvido13h55, processos encerrados.
Sem Chrome, resultado UI/E2E ou promoção. O censo é contrato estático, não prova
produção nem atualiza métricas de ação por si.
Memória: nenhuma regra nova aprovada; fontes oficiais permanecem intactas.
