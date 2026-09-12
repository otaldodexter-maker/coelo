# Revisao G7 - P51: usuario interno

- Data: 2026-09-12
- Escopo: leitura do roteiro/evidencia G5 1548780e1.
- Acao canonica: internal-users.create.

## Resultado

A prova mede uma unica criacao sintetica com preflight anti-duplicidade,
perfil global minimo support, escopo platform, releitura por detail/list e
logout local. A autorizacao acontece antes da chamada e a Edge Function a
repete com o token do operador; o cliente nao e a fonte de autoridade.

O link de setup e validado pela funcao quanto a HTTPS, origem do projeto,
authority sem credenciais e path. O destino de recuperacao e constante
canonica da funcao, independente da origem CORS.

## Limite do verificador

O resultado agregado password_setup_link_contract=false nao registrava qual
subcheck falhou. A leitura case-sensitive dos headers era um defeito do
verificador, mas nao demonstrava por si o valor da query do action link.

C0 gerou uma unica recuperacao para a mesma identidade existente e inspecionou
somente booleans: HTTPS, host, path, tipo e mesmo usuario passaram, mas
redirect_exact=false. Ha portanto uma falha produtiva no contrato de destino,
nao uma falha apenas do oraculo. A causa entre SDK, Auth ou configuracao ainda
nao foi medida. Nao gerar novo link, nem mudar senha, SMTP ou configuracao antes
do diagnostico.
