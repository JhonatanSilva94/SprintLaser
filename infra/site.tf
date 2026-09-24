# -----------------------------------------------------------------------------
# Hospedagem do front: S3 (guarda os arquivos) + CloudFront (entrega ao público)
# -----------------------------------------------------------------------------
# O bucket é privado: ninguém acessa os arquivos direto pelo S3. Quem lê o
# bucket é só o CloudFront, que entrega o site por HTTPS no domínio
# *.cloudfront.net e guarda cópias em cache perto dos visitantes.
#
# O Terraform só cria a "casa" vazia. O upload dos arquivos do site é feito
# à parte, com `aws s3 sync`, seguido de uma invalidação do CloudFront.

# Descobre o ID da conta AWS em uso. Serve para montar um nome de bucket
# único: nomes de bucket são globais, valem para todas as contas do mundo.
data "aws_caller_identity" "atual" {}

# ---------------------------------- S3 ---------------------------------------

# O bucket onde ficam index.html, cadastro.html, gravador.html, config.js e
# assets/. Sem bloco "website": não usamos o static website hosting do S3,
# quem faz o papel de servidor web é o CloudFront.
resource "aws_s3_bucket" "site" {
  bucket = "${local.prefixo}-site-${data.aws_caller_identity.atual.account_id}"
}

# Trava de segurança: bloqueia qualquer forma de acesso público (ACLs públicas
# e bucket policies públicas). A policy mais abaixo continua valendo porque
# ela libera um serviço específico (CloudFront), não "qualquer pessoa".
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: permite ler objetos (s3:GetObject) apenas ao serviço
# CloudFront E apenas quando a requisição vem da NOSSA distribuição
# (condição AWS:SourceArn). Outra distribuição, de outra conta, não consegue.
data "aws_iam_policy_document" "site_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json

  # Aplica o bloqueio de acesso público antes, para evitar conflito entre os
  # dois recursos na criação.
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# ------------------------------- CloudFront ----------------------------------

# Origin Access Control (OAC): faz o CloudFront assinar (SigV4) cada
# requisição que ele faz ao S3. É essa assinatura que o S3 confere contra a
# bucket policy acima. Sem OAC o CloudFront chegaria "anônimo" e levaria 403.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.prefixo}-site-oac"
  description                       = "Acesso do CloudFront ao bucket privado do site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Política de cache gerenciada pela AWS, pronta para conteúdo estático
# (cache longo, compressão gzip/brotli). Buscamos pelo nome para não precisar
# copiar o ID dela.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# A distribuição: o "site" propriamente dito, em https://xxxx.cloudfront.net
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "Front do SprintLaser"
  default_root_object = "index.html" # "/" entrega o index.html

  # Nomes próprios que esta distribuição aceita, além do *.cloudfront.net.
  # O CloudFront recusa um nome aqui se o certificado abaixo não cobrir ele.
  aliases = local.dominios_site

  # Responde também por IPv6 (necessário para os registros AAAA de dominio.tf).
  is_ipv6_enabled = true

  # PriceClass_All inclui os pontos de presença da América do Sul, onde estão
  # os corredores. As classes mais baratas (100/200) deixariam o Brasil de fora.
  price_class = "PriceClass_All"

  # Origem: de onde o CloudFront busca os arquivos. Usamos o endereço
  # "regional" do bucket (e não o de website) junto com a OAC.
  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # Comportamento padrão, vale para todos os caminhos.
  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https" # http:// vira https://
    allowed_methods        = ["GET", "HEAD"]     # site só leitura
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # Sem bloqueio por país.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado HTTPS do sprintlaser.com (dominio.tf). Vem do recurso de
  # validação, e não do certificado direto, para o CloudFront só recebê-lo
  # depois de emitido. O endereço *.cloudfront.net continua funcionando.
  # sni-only: o navegador informa o nome do site no início da conexão HTTPS
  # (todo navegador atual faz isso); a alternativa, IP dedicado, custa caro.
  # TLSv1.2_2021: recusa versões antigas e inseguras do TLS.
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
