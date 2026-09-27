"""Lambda de busca: GET /corredor/{numero_camisa}

Devolve:  200 {"nome": "Marina", "tempo": "01:42:08"}
          404 {"erro": "Corredor não encontrado."}

MUDANÇA: a busca era pelo código sequencial; agora é pelo número da camisa,
que é a nova chave da tabela.
"""

import json
import os
import re

import boto3  # já vem instalado no runtime Python da Lambda

tabela = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

# NOVO: mesma regra da Lambda de cadastro (ver normalizar_camisa lá).
SOMENTE_DIGITOS = re.compile(r"^[0-9]+$")
TAMANHO_MAXIMO_CAMISA = 6


def resposta(status, corpo):
    """Monta a resposta no formato que o API Gateway (payload 2.0) espera."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, ensure_ascii=False),
    }


def normalizar_camisa(valor):
    """NOVO: devolve o número sem zeros à esquerda, ou None se inválido.

    Precisa ser idêntica à do cadastro: o item foi gravado como "150", então
    o gravador digitando "0150" tem que buscar "150".
    """
    valor = str(valor).strip()
    if not SOMENTE_DIGITOS.match(valor):
        return None
    valor = valor.lstrip("0")
    if not valor or len(valor) > TAMANHO_MAXIMO_CAMISA:
        return None
    return valor


def handler(event, context):
    # MUDANÇA: o parâmetro de caminho agora se chama numero_camisa (api.tf).
    numero_camisa = normalizar_camisa((event.get("pathParameters") or {}).get("numero_camisa", ""))

    # Número inválido não tem como existir na tabela: responde 404 direto,
    # sem gastar uma leitura no DynamoDB.
    if not numero_camisa:
        return resposta(404, {"erro": "Corredor não encontrado."})

    item = tabela.get_item(Key={"numero_camisa": numero_camisa}).get("Item")
    if not item:
        return resposta(404, {"erro": "Corredor não encontrado."})

    return resposta(200, {"nome": item["nome"], "tempo": item["tempo"]})
