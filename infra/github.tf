# -----------------------------------------------------------------------------
# Deploy do site pelo GitHub Actions (OIDC, sem access keys)
# -----------------------------------------------------------------------------
# Em vez de guardar uma access key no GitHub, o workflow recebe do próprio
# GitHub um token OIDC assinado ("sou o repositório X, na branch Y") e troca
# esse token por credenciais temporárias da AWS (sts:AssumeRoleWithWebIdentity).
# As credenciais valem só durante a execução e só têm as permissões da role
# abaixo. O workflow está em .github/workflows/deploy-site.yml.

# --------------------------- OIDC provider -----------------------------------
# Registra o GitHub como "emissor de identidades" confiável na conta. Só pode
# existir UM provider com esta URL por conta AWS. Se ele já tiver sido criado
# por outro projeto, rode com -var="oidc_github_ja_existe=true" (ou coloque
# no terraform.tfvars): aí o Terraform só lê o provider existente, sem criar.
variable "oidc_github_ja_existe" {
  description = "true se a conta já tem o OIDC provider do GitHub (token.actions.githubusercontent.com)"
  type        = bool
  default     = false
}

locals {
  github_oidc = "token.actions.githubusercontent.com"

  # ARN do provider, venha ele do resource (criado aqui) ou do data source.
  github_oidc_arn = var.oidc_github_ja_existe ? data.aws_iam_openid_connect_provider.github[0].arn : aws_iam_openid_connect_provider.github[0].arn
}

# count = 0 ou 1 funciona como um "if": só um dos dois blocos existe.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.oidc_github_ja_existe ? 0 : 1

  url = "https://${local.github_oidc}"

  # "aud" que o GitHub coloca no token quando a action
  # aws-actions/configure-aws-credentials pede credenciais.
  client_id_list = ["sts.amazonaws.com"]

  # Sem thumbprint_list: para o GitHub a AWS valida o certificado pelas CAs
  # confiáveis dela, e o provider aws 6.x não exige mais esse campo.
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.oidc_github_ja_existe ? 1 : 0

  url = "https://${local.github_oidc}"
}

# ------------------------------- Role -----------------------------------------

# Trust policy: só tokens do GitHub, para a AWS (aud), vindos DESTE
# repositório e da branch main (sub). Um fork, um pull request ou outra
# branch recebem um "sub" diferente e a AWS recusa.
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # O GitHub envia o "sub" com os IDs numéricos do dono e do repositório
    # (dono@id/repo@id). Os IDs não mudam se o repositório for renomeado ou
    # apagado e recriado com o mesmo nome. Valor conferido no CloudTrail.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:sub"
      values   = ["repo:JhonatanSilva94@321849969/SprintLaser@1386455132:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy_site" {
  name               = "${local.prefixo}-github-deploy-site"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

# O mínimo para `aws s3 sync --delete` + invalidação do cache.
data "aws_iam_policy_document" "github_deploy_site" {
  # Listar o bucket: o sync compara o que está lá com os arquivos locais.
  # ListBucket vale para o bucket em si (ARN sem /*).
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  # Enviar e apagar arquivos (objetos, ARN com /*).
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  # Invalidar o cache apenas desta distribuição.
  statement {
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "github_deploy_site" {
  name   = "${local.prefixo}-github-deploy-site-policy"
  role   = aws_iam_role.github_deploy_site.id
  policy = data.aws_iam_policy_document.github_deploy_site.json
}
