# Resume seguro do executor de Avaliações

Data: 2026-09-12

O runner permanece **sem execução remota** nesta rodada. A alteração local
`a0a6d5b5c` fecha a recuperação de falha parcial apontada por G7:

- `--resume` só é aceito junto de `--execute`, com o mesmo arquivo de ACK e
  `assignment-id` explícito;
- o manifesto existente precisa registrar modo de execução, mutações, plano e
  executor habilitado; um plano concluído é recusado;
- o alvo persistido é comparado com atividade, instituição e unidade retornadas
  novamente por `context_options`;
- os mesmos `request_id` e payloads persistidos são reutilizados; nenhum ID é
  criado em uma retomada;
- configuração, ativação e diário já gravados são relidos antes de serem
  reutilizados. Cada nova etapa atualiza o estado persistido antes de seguir.

Validações locais: `python -m py_compile assessments_api_runner.py` e
`git diff --check` passaram. Não houve Chrome, Flutter test, SQL nem chamada
mutante de API.

Próximo gate: revisão G5/C0 do código publicado e ACK nominal antes de qualquer
invocação com `--execute`.
