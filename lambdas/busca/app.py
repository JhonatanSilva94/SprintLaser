"""Lambda de busca: GET /corredor/{codigo}

Devolve:  200 {"codigo": "01", "nome": "Marina", "tempo": "01:42:08"}
          404 {"erro": "Corredor não encontrado."}
"""

import json
import os

import boto3  # já vem instalado no runtime Python da Lambda

tabela = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def resposta(status, corpo):
    """Monta a resposta no formato que o API Gateway (payload 2.0) espera."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, ensure_ascii=False),
    }


def handler(event, context):
    codigo = (event.get("pathParameters") or {}).get("codigo", "").strip()

    # Só aceitamos números. Isso também impede que alguém leia o item
    # interno "CONTADOR" pela URL /corredor/CONTADOR.
    if not codigo.isdigit():
        return resposta(404, {"erro": "Corredor não encontrado."})

    # "1" e "01" encontram o mesmo corredor, igual ao front simulado.
    codigo = codigo.zfill(2)

    item = tabela.get_item(Key={"codigo": codigo}).get("Item")
    if not item:
        return resposta(404, {"erro": "Corredor não encontrado."})

    return resposta(200, {"codigo": item["codigo"], "nome": item["nome"], "tempo": item["tempo"]})
