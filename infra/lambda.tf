# -----------------------------------------------------------------------------
# Funções Lambda (código Python em ../lambdas/)
# -----------------------------------------------------------------------------
# Para cada função temos três peças:
#   1. archive_file: compacta a pasta do código num .zip (a Lambda só aceita
#      código empacotado). Quando o .py muda, o hash do zip muda e o
#      Terraform sabe que precisa atualizar a função.
#   2. aws_cloudwatch_log_group: onde os print()/erros da função aparecem.
#      Criamos nós mesmos para definir a retenção de 7 dias; se deixássemos a
#      Lambda criar sozinha, os logs ficariam guardados para sempre.
#   3. aws_lambda_function: a função em si.
# Nenhuma delas tem bloco vpc_config, então rodam fora de VPC e alcançam o
# DynamoDB direto pela rede da AWS, sem NAT Gateway nem VPC endpoint.

# ------------------------------- Cadastro ------------------------------------

data "archive_file" "cadastro" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/cadastro"
  output_path = "${path.module}/build/cadastro.zip"
}

# O nome precisa ser exatamente /aws/lambda/<nome-da-função>, que é onde a
# Lambda escreve os logs por padrão.
resource "aws_cloudwatch_log_group" "cadastro" {
  name              = "/aws/lambda/${local.prefixo}-cadastro"
  retention_in_days = 7
}

resource "aws_lambda_function" "cadastro" {
  function_name = "${local.prefixo}-cadastro"
  role          = aws_iam_role.cadastro.arn

  runtime = "python3.13"
  handler = "app.handler" # arquivo app.py, função handler()

  filename         = data.archive_file.cadastro.output_path
  source_code_hash = data.archive_file.cadastro.output_base64sha256

  # 128 MB e 5 s sobram para uma escrita simples no DynamoDB.
  memory_size = 128
  timeout     = 5

  # O código lê o nome da tabela daqui, em vez de deixá-lo fixo no Python.
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.corredores.name
    }
  }

  # Garante que o log group (com retenção) e as permissões existam antes da
  # função rodar pela primeira vez.
  depends_on = [
    aws_cloudwatch_log_group.cadastro,
    aws_iam_role_policy.cadastro,
  ]
}

# -------------------------------- Busca --------------------------------------

data "archive_file" "busca" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/busca"
  output_path = "${path.module}/build/busca.zip"
}

resource "aws_cloudwatch_log_group" "busca" {
  name              = "/aws/lambda/${local.prefixo}-busca"
  retention_in_days = 7
}

resource "aws_lambda_function" "busca" {
  function_name = "${local.prefixo}-busca"
  role          = aws_iam_role.busca.arn

  runtime = "python3.13"
  handler = "app.handler"

  filename         = data.archive_file.busca.output_path
  source_code_hash = data.archive_file.busca.output_base64sha256

  memory_size = 128
  timeout     = 5

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.corredores.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.busca,
    aws_iam_role_policy.busca,
  ]
}
