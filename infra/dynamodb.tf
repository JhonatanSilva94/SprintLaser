# -----------------------------------------------------------------------------
# Tabela DynamoDB dos corredores
# -----------------------------------------------------------------------------
# Guarda um item por corredor:
#   { numero_camisa: "150", nome: "Marina", tempo: "01:42:08" }
#
# MUDANÇA: a chave era "codigo" (sequencial, gerado por um item CONTADOR).
# Agora é o número da camisa informado pelo corredor, e o CONTADOR deixou de
# existir. Trocar o hash_key não pode ser feito "no lugar": o Terraform
# destrói e recria a tabela (com o mesmo nome), apagando todos os dados.
#
# - PAY_PER_REQUEST (on-demand): paga só pelas leituras/escritas feitas, sem
#   precisar estimar capacidade. Ideal para um evento com uso esporádico.
# - hash_key "numero_camisa": é a chave primária; cada camisa identifica um
#   item. É string (e não número) e sempre gravada sem zeros à esquerda;
#   quem garante isso são as Lambdas. Ser a chave é também o que permite ao
#   PutItem condicional recusar uma camisa repetida.
#   No DynamoDB só declaramos os atributos que fazem parte de chaves; "nome"
#   e "tempo" não precisam aparecer aqui.
# - deletion_protection_enabled = false: permite recriar a tabela depois de
#   cada corrida com:
#     terraform apply -replace="aws_dynamodb_table.corredores"
#   Isso apaga todos os dados.
resource "aws_dynamodb_table" "corredores" {
  name         = "${local.prefixo}-corredores"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "numero_camisa"

  attribute {
    name = "numero_camisa"
    type = "S" # S = string
  }

  deletion_protection_enabled = false
}
