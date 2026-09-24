"""Lambda de cadastro: POST /cadastro

Recebe:   {"nome": "Marina", "tempo": "01:42:08"}
Devolve:  201 {"codigo": "01", "nome": "Marina", "tempo": "01:42:08"}
"""

import json
import os
import re

import boto3  # já vem instalado no runtime Python da Lambda

# Criado fora do handler para ser reaproveitado entre invocações.
tabela = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

TEMPO_VALIDO = re.compile(r"^\d{2}:[0-5]\d:[0-5]\d$")  # hh:mm:ss
TAMANHO_MAXIMO_NOME = 15  # mesmo limite do campo no cadastro.html


def resposta(status, corpo):
    """Monta a resposta no formato que o API Gateway (payload 2.0) espera."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, ensure_ascii=False),
    }


def proximo_codigo():
    """Incrementa o item CONTADOR e devolve o novo valor.

    ADD é atômico: se dois corredores se cadastrarem ao mesmo tempo, cada um
    recebe um número diferente. Se o item ainda não existir (tabela nova),
    o DynamoDB o cria com valor 0 + 1 = 1.
    """
    resultado = tabela.update_item(
        Key={"codigo": "CONTADOR"},
        UpdateExpression="ADD valor :um",
        ExpressionAttributeValues={":um": 1},
        ReturnValues="UPDATED_NEW",
    )
    return int(resultado["Attributes"]["valor"])


def handler(event, context):
    try:
        dados = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return resposta(400, {"erro": "Corpo precisa ser um JSON válido."})

    nome = str(dados.get("nome", "")).strip()
    tempo = str(dados.get("tempo", "")).strip()

    if not nome or len(nome) > TAMANHO_MAXIMO_NOME:
        return resposta(400, {"erro": f"Nome obrigatório, até {TAMANHO_MAXIMO_NOME} caracteres."})
    if not TEMPO_VALIDO.match(tempo):
        return resposta(400, {"erro": "Tempo precisa estar no formato hh:mm:ss."})

    # 1 -> "01", 2 -> "02"... (a partir de 100 fica com três dígitos)
    codigo = str(proximo_codigo()).zfill(2)

    corredor = {"codigo": codigo, "nome": nome, "tempo": tempo}
    tabela.put_item(Item=corredor)

    print(f"Corredor cadastrado: {corredor}")  # aparece no CloudWatch Logs
    return resposta(201, corredor)
