# -----------------------------------------------------------------------------
# FASE 2: sprintlaser.com e www.sprintlaser.com apontando para o CloudFront
# -----------------------------------------------------------------------------
# Só aplique depois que os nameservers da HostGator estiverem trocados e
# propagados. A validação do certificado depende disso: a AWS confere um
# registro DNS consultando a internet, e a internet só "enxerga" o Route 53
# depois da troca. Antes disso, o apply fica esperando a validação e falha
# por tempo esgotado.
#
# Comandos:
#   Fase 1: terraform apply -target="aws_route53_zone.principal" -target="aws_route53_record.mx" -target="aws_route53_record.spf"
#   Fase 2: terraform apply
# (Na fase 2 o apply normal cria o que falta: tudo deste arquivo, mais as
# mudanças no CloudFront em site.tf e no CORS em providers.tf.)

# --------------------------- Certificado HTTPS -------------------------------

# Certificado SSL/TLS gratuito do ACM, válido para os dois nomes. É o que
# faz o cadeado aparecer em https://sprintlaser.com. Criado em us-east-1 (o
# provider com alias), exigência do CloudFront.
# validation_method = "DNS": para provar que o domínio é nosso, a AWS pede
# que um registro CNAME específico seja criado no DNS (recurso abaixo). A
# renovação também é automática enquanto esse registro existir.
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name               = local.dominio
  subject_alternative_names = ["www.${local.dominio}"]
  validation_method         = "DNS"

  # Se o certificado precisar ser trocado, cria o novo antes de apagar o
  # antigo, para o CloudFront nunca ficar sem certificado.
  lifecycle {
    create_before_destroy = true
  }
}

# Os registros CNAME de validação que o ACM pediu, um por domínio do
# certificado. O for_each cria um registro para cada item de
# domain_validation_options (sprintlaser.com e www.sprintlaser.com).
# allow_overwrite evita erro caso os dois nomes peçam o mesmo registro.
resource "aws_route53_record" "validacao_certificado" {
  for_each = {
    for opcao in aws_acm_certificate.site.domain_validation_options : opcao.domain_name => opcao
  }

  zone_id         = aws_route53_zone.principal.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  ttl             = 60
  records         = [each.value.resource_record_value]
  allow_overwrite = true
}

# Não cria nada na AWS: é uma "espera". O Terraform fica aqui até o ACM
# confirmar que encontrou os registros acima e marcar o certificado como
# emitido (costuma levar poucos minutos). O CloudFront (site.tf) usa o ARN
# que sai daqui, então ele só recebe o certificado quando já está válido.
resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for registro in aws_route53_record.validacao_certificado : registro.fqdn]
}

# ----------------------- Nomes apontando para o site -------------------------
# Registros "alias": recurso do Route 53 que aponta um nome direto para um
# serviço da AWS (aqui, a distribuição CloudFront). Diferente de um CNAME,
# funciona também na raiz do domínio (sprintlaser.com), não tem custo por
# consulta e acompanha sozinho qualquer mudança de IP do CloudFront.
# Um registro por nome, para cada tipo de endereço:
#   A    = endereços IPv4
#   AAAA = endereços IPv6 (por isso is_ipv6_enabled = true no CloudFront)

resource "aws_route53_record" "site_ipv4" {
  for_each = toset(local.dominios_site)

  zone_id = aws_route53_zone.principal.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_ipv6" {
  for_each = toset(local.dominios_site)

  zone_id = aws_route53_zone.principal.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
