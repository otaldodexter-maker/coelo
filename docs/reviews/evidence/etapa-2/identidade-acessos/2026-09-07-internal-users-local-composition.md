---
title: "Usuários internos — composição e erros locais"
source: "reservas E2E1-R01/R02 do Coordenador; testes locais da branch codex/e2e-identidade-acessos"
status: "local-tested-not-e2e"
generated_at: "2026-09-07"
---

# Recorte

Somente Superadmin, `internal-users.list`, no runtime normal. Base
`1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`. Sem escrita remota, migração,
Cloudflare, convite, criação ou edição produtiva.

## Evidência local

- `a2bf2315cb0dc3ba419a947f054cd1ff59d814d9`: habilitação explícita de preview
  nos dois testes de Conta. Suíte de rotas de Conta: 5/5.
- `151d9ddf946607c50a55ea8011cddabacd127495`: erros de transporte
  42501/PGRST301/302/303 e envelopes de sessão retornam unauthorized sem
  detalhes privados; MFA tipado mantém precedência. Repositório: 12/12;
  analyzer focal: zero problemas; revisão independente aprovada.
- Composição: scope → main → app → router → repositório Supabase. Ausência
  de configuração mantém repositório nulo. Rota normal rejeita nulo/demo,
  exige `platform.member.read`, não infere permissão do nome Owner e não
  expõe callbacks de mutação. Logout remove a página e redireciona a login.
- Testes de rota: 4/4; escopo de autenticação: 11/11. Regressão combinada com
  Conta e repositório: 32/32. Transporte Supabase simulado, sem backend real.
- O cliente de teste é criado fora do relógio simulado do widget e encerrado
  em tearDownAll; renovação automática fica desabilitada nesse teste.
- Revisão independente da composição: sem bloqueios novos no recorte.

## Gates ainda abertos

### Incremento de apresentação após a composição

Negação server-side tipada agora limpa busca/filtros/resultados da tela e
oculta toolbar, paginação e retry. Mensagem privada nunca é renderizada.
O vazio somente leitura não sugere criação em preview. Suíte de diretório:
13/13, incluindo transição carregado → negado, estados e matriz de larguras
375/768/1024/1440 com escala de texto até 200%. Analyzer focal sem problemas;
revisão independente sem bloqueios. Cache do repositório e sessão permanecem
como trabalho separado; essa mudança não comprova revogação ponta a ponta.

Não promover Front-end verified, Back-end done ou verified-e2e. Faltam estados
remotos completos da UI, detalhe/edição, invalidação de contexto/cache,
verificação visual e cadeia real autorizada com reload, negativas e auditoria.
Produção continua dependente de pacote nominal e lease do Coordenador.

Os três rastreadores são escritos exclusivamente pelo Coordenador; deltas e
SHAs foram enviados por handoff. A projeção de conhecimento de usuários
internos foi corrigida quanto ao MFA a partir do aditivo aprovado de
2026-09-01 da ADR 0019, sem criar decisão nova. O texto sobre preview não
comprova prontidão produtiva; esta evidência distingue a composição local da
validação real ainda pendente.
