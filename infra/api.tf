# -----------------------------------------------------------------------------
# API Gateway (HTTP API)
# -----------------------------------------------------------------------------
# É a "porta de entrada" pública: recebe as requisições HTTPS do navegador e
# repassa para a Lambda certa conforme o método + caminho (a "rota").
# Usamos HTTP API (e não REST API) por ser mais simples e mais barata.

resource "aws_apigatewayv2_api" "api" {
  name          = "${local.prefixo}-api"
  protocol_type = "HTTP"

  # CORS: o navegador só deixa uma página em http://localhost:5500 chamar um
  # domínio diferente (execute-api.amazonaws.com) se a API responder com os
  # cabeçalhos Access-Control-Allow-*. Com este bloco o próprio API Gateway
  # responde ao "preflight" (OPTIONS) e adiciona esses cabeçalhos, então o
  # código Python não precisa se preocupar com CORS.
  cors_configuration {
    allow_origins = local.origens_permitidas
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300 # navegador guarda o preflight por 5 minutos
  }
}

# ------------------------------ Integrações ----------------------------------
# Uma integração diz "para onde" a requisição vai. AWS_PROXY repassa a
# requisição inteira para a Lambda e devolve ao cliente o que ela retornar.
# payload_format_version 2.0 é o formato de evento mais enxuto da HTTP API
# (é o que o código Python espera: event["body"], event["pathParameters"]).

resource "aws_apigatewayv2_integration" "cadastro" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.cadastro.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "busca" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.busca.invoke_arn
  payload_format_version = "2.0"
}

# -------------------------------- Rotas --------------------------------------
# Ligam "MÉTODO /caminho" a uma integração.

# POST /cadastro -> Lambda de cadastro
resource "aws_apigatewayv2_route" "cadastro" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /cadastro"
  target    = "integrations/${aws_apigatewayv2_integration.cadastro.id}"
}

# GET /corredor/{codigo} -> Lambda de busca.
# {codigo} é um parâmetro de caminho; chega no Python em
# event["pathParameters"]["codigo"].
resource "aws_apigatewayv2_route" "busca" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /corredor/{codigo}"
  target    = "integrations/${aws_apigatewayv2_integration.busca.id}"
}

# -------------------------------- Stage --------------------------------------
# Um stage é uma "versão publicada" da API. O nome especial $default deixa a
# API acessível na raiz da URL (sem /prod, /dev...). auto_deploy publica
# automaticamente qualquer mudança de rota/integração.
#
# Throttling baixo: no máximo 5 requisições por segundo em média, com picos
# de até 10. Acima disso o API Gateway responde 429 sem nem chamar a Lambda,
# o que protege a conta de custos inesperados se alguém abusar da URL.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }
}

# ------------------------- Permissão para invocar ----------------------------
# Por padrão ninguém pode invocar uma Lambda. Estes recursos autorizam o
# serviço API Gateway, e apenas esta API (source_arn), a chamar cada função.
# Sem eles a API responderia 500 "Internal Server Error".

resource "aws_lambda_permission" "api_cadastro" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cadastro.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_busca" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.busca.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
