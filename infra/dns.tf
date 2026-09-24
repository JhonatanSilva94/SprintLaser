# -----------------------------------------------------------------------------
# FASE 1: DNS do sprintlaser.com no Route 53 (zona + e-mail)
# -----------------------------------------------------------------------------
# Aplicada sozinha, com -target (os comandos estão no fim de dominio.tf).
# Depois disso você troca os nameservers na HostGator pelos que aparecem no
# output "nameservers". A partir daí, quem responde "onde fica
# sprintlaser.com?" para o mundo é o Route 53, e não mais a HostGator.
#
# Por isso os registros de e-mail precisam existir aqui ANTES da troca: se
# não existirem, os e-mails para comercial@sprintlaser.com param de chegar.

# Hosted zone: o "arquivo de zona" do domínio dentro do Route 53. Ao ser
# criada, a AWS gera automaticamente os registros NS (os 4 nameservers da
# zona) e SOA. Custa US$ 0,50 por mês.
resource "aws_route53_zone" "principal" {
  name    = local.dominio
  comment = "Domínio do SprintLaser (site + e-mail Titan)"
}

# MX: diz para onde vão os e-mails de @sprintlaser.com. Número menor tem
# prioridade: os servidores tentam mx1 primeiro e mx2 se o mx1 falhar.
# name = "" significa o próprio domínio (sprintlaser.com), sem subdomínio.
resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.principal.zone_id
  name    = ""
  type    = "MX"
  ttl     = 3600
  records = [
    "10 mx1.titan.email",
    "20 mx2.titan.email",
  ]
}

# SPF (registro TXT): lista quem pode ENVIAR e-mail em nome de
# @sprintlaser.com. Sem ele, e-mails enviados pelo Titan tendem a cair em spam.
# "~all" = e-mails vindos de outros servidores são suspeitos, não rejeitados.
# O Route 53 só aceita um registro TXT por nome, então se um dia precisar de
# outro TXT na raiz (ex.: verificação do Google), ele entra nesta mesma lista.
resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.principal.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 include:spf.titan.email ~all"]
}
