# -----------------------------------------------------------------------------
# Tabela DynamoDB dos corredores
# -----------------------------------------------------------------------------
# Guarda um item por corredor: { codigo: "01", nome: "Marina", tempo: "01:42:08" }
# e também um item especial { codigo: "CONTADOR", valor: N } usado pela Lambda
# de cadastro para gerar o próximo código sequencial.
#
# - PAY_PER_REQUEST (on-demand): paga só pelas leituras/escritas feitas, sem
#   precisar estimar capacidade. Ideal para um evento com uso esporádico.
# - hash_key "codigo": é a chave primária; cada código identifica um item.
#   No DynamoDB só declaramos os atributos que fazem parte de chaves; "nome"
#   e "tempo" não precisam aparecer aqui.
# - deletion_protection_enabled = false: permite recriar a tabela depois de
#   cada corrida com:
#     terraform apply -replace="aws_dynamodb_table.corredores"
#   Isso apaga todos os dados, inclusive o CONTADOR, então os códigos
#   recomeçam em 01.
resource "aws_dynamodb_table" "corredores" {
  name         = "${local.prefixo}-corredores"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "codigo"

  attribute {
    name = "codigo"
    type = "S" # S = string
  }

  deletion_protection_enabled = false
}
