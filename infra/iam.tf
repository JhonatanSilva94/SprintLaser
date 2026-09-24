# -----------------------------------------------------------------------------
# Permissões (IAM)
# -----------------------------------------------------------------------------
# Toda Lambda roda "vestindo" uma role do IAM. A role define o que o código
# pode fazer na AWS. Aqui cada Lambda tem a sua, com o mínimo necessário:
#   - cadastro: escrever logs + UpdateItem (contador) + PutItem (corredor)
#   - busca:    escrever logs + GetItem
# Assim, mesmo que o código da busca tivesse um bug, ele não conseguiria
# gravar nada na tabela.

# Política de confiança ("trust policy"): diz QUEM pode assumir a role.
# Aqui, só o serviço Lambda. Sem isso a Lambda não conseguiria usar a role.
# É igual para as duas roles, por isso é declarada uma vez só.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------------------------- Lambda de cadastro -----------------------------

# Role da Lambda de cadastro.
resource "aws_iam_role" "cadastro" {
  name               = "${local.prefixo}-cadastro-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# O que a Lambda de cadastro pode fazer (política de permissões).
data "aws_iam_policy_document" "cadastro" {
  # Escrever logs apenas no próprio log group. O log group já é criado pelo
  # Terraform (lambda.tf), por isso não damos logs:CreateLogGroup.
  # O ":*" no fim cobre os log streams dentro do grupo.
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.cadastro.arn}:*"]
  }

  # UpdateItem: incrementar o CONTADOR com ADD.
  # PutItem:    salvar o corredor novo.
  statement {
    actions   = ["dynamodb:UpdateItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.corredores.arn]
  }
}

# Anexa a política acima à role (política "inline", vive dentro da role).
resource "aws_iam_role_policy" "cadastro" {
  name   = "${local.prefixo}-cadastro-policy"
  role   = aws_iam_role.cadastro.id
  policy = data.aws_iam_policy_document.cadastro.json
}

# ----------------------------- Lambda de busca -------------------------------

# Role da Lambda de busca.
resource "aws_iam_role" "busca" {
  name               = "${local.prefixo}-busca-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# O que a Lambda de busca pode fazer: logs + ler um item pela chave.
data "aws_iam_policy_document" "busca" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.busca.arn}:*"]
  }

  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.corredores.arn]
  }
}

resource "aws_iam_role_policy" "busca" {
  name   = "${local.prefixo}-busca-policy"
  role   = aws_iam_role.busca.id
  policy = data.aws_iam_policy_document.busca.json
}
