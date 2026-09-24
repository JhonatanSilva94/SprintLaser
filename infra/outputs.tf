# -----------------------------------------------------------------------------
# Saídas
# -----------------------------------------------------------------------------
# Valores impressos no fim do `terraform apply` (ou com `terraform output`).

# URL base da API, sem barra no final. Ex.:
#   https://abc123.execute-api.sa-east-1.amazonaws.com
# As rotas ficam em <api_url>/cadastro e <api_url>/corredor/{codigo}.
output "api_url" {
  description = "URL base da API do SprintLaser"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "tabela_dynamodb" {
  description = "Nome da tabela DynamoDB"
  value       = aws_dynamodb_table.corredores.name
}

# Destino do `aws s3 sync`.
output "site_bucket" {
  description = "Bucket S3 com os arquivos do front"
  value       = aws_s3_bucket.site.bucket
}

# Usado no comando de invalidação do cache.
output "site_distribution_id" {
  description = "ID da distribuição CloudFront do front"
  value       = aws_cloudfront_distribution.site.id
}

output "site_url" {
  description = "Endereço público do site (domínio padrão do CloudFront)"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

# Fase 1: os 4 nameservers da zona no Route 53. São eles que vão no painel
# da HostGator, no lugar de dns3/dns4.hostgator.com.br.
output "nameservers" {
  description = "Nameservers do Route 53 para configurar na HostGator"
  value       = aws_route53_zone.principal.name_servers
}

# Fase 2: endereços do site com o domínio próprio.
output "site_urls_dominio" {
  description = "Endereços do site com o domínio próprio"
  value       = [for d in local.dominios_site : "https://${d}"]
}
