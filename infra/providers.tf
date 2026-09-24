# -----------------------------------------------------------------------------
# Configuração geral do Terraform
# -----------------------------------------------------------------------------
# Diz ao Terraform quais "plugins" (providers) baixar no `terraform init`:
#   - aws:     cria os recursos na AWS
#   - archive: compacta o código Python em .zip para enviar às Lambdas
# O state fica local (arquivo terraform.tfstate nesta pasta), então não há
# bloco "backend" aqui.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Provider da AWS: todos os recursos serão criados em São Paulo (sa-east-1).
# As credenciais vêm do seu ambiente (aws configure / variáveis AWS_*).
# default_tags coloca a tag "Projeto" em tudo, facilitando achar os recursos
# no console e no billing.
provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = {
      Projeto = "SprintLaser"
    }
  }
}

# Segundo provider da AWS, apontando para us-east-1 (Norte da Virgínia).
# O CloudFront só aceita certificados ACM criados em us-east-1, não importa
# onde estejam os outros recursos. O "alias" dá um apelido a este provider;
# recursos que precisarem dele dizem `provider = aws.us_east_1`. Todo o resto
# continua usando o provider padrão (sa-east-1).
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Projeto = "SprintLaser"
    }
  }
}

# Valores reaproveitados em vários arquivos. Centralizar aqui evita digitar
# o mesmo nome em vários lugares.
locals {
  prefixo = "sprintlaser"

  # Domínio próprio (dns.tf e dominio.tf) e os endereços em que o site responde.
  dominio       = "sprintlaser.com"
  dominios_site = [local.dominio, "www.${local.dominio}"]

  # Origens que podem chamar a API pelo navegador:
  #   - Live Server do VS Code (testes locais)
  #   - domínio padrão do CloudFront (site.tf)
  #   - https://sprintlaser.com e https://www.sprintlaser.com
  origens_permitidas = concat(
    [
      "http://localhost:5500",
      "http://127.0.0.1:5500",
      "https://${aws_cloudfront_distribution.site.domain_name}",
    ],
    [for d in local.dominios_site : "https://${d}"],
  )
}
