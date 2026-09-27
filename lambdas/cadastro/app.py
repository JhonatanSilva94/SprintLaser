"""Lambda de cadastro: POST /cadastro

Recebe:   {"numero_camisa": "0150", "nome": "Marina", "tempo": "01:42:08"}
Devolve:  201 {"numero_camisa": "150", "nome": "Marina", "tempo": "01:42:08"}
          409 {"erro": "Camisa já cadastrada. Procure a equipe de gravação."}

MUDANÇA: antes a Lambda gerava um código sequencial (01, 02...) com um item
CONTADOR na tabela. Agora o próprio corredor informa o número da camisa, que
passa a ser a chave do item. O contador deixou de existir.
"""

import json
import os
import re

import boto3  # já vem instalado no runtime Python da Lambda

# Criado fora do handler para ser reaproveitado entre invocações.
tabela = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

TEMPO_VALIDO = re.compile(r"^\d{2}:[0-5]\d:[0-5]\d$")  # hh:mm:ss
TAMANHO_MAXIMO_NOME = 15  # mesmo limite do campo no cadastro.html

# NOVO: número da camisa. [0-9] em vez de \d porque \d também aceita dígitos
# de outros alfabetos (ex.: "١٥٠" em árabe), que não queremos como chave.
SOMENTE_DIGITOS = re.compile(r"^[0-9]+$")
TAMANHO_MAXIMO_CAMISA = 6  # mesmo limite do campo no cadastro.html

MENSAGEM_CAMISA_DUPLICADA = "Camisa já cadastrada. Procure a equipe de gravação."


def resposta(status, corpo):
    """Monta a resposta no formato que o API Gateway (payload 2.0) espera."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, ensure_ascii=False),
    }


def normalizar_camisa(valor):
    """NOVO: devolve o número da camisa sem zeros à esquerda, ou None se inválido.

    "0150" e "150" viram "150", assim a mesma camisa não pode ser cadastrada
    duas vezes só mudando os zeros. "0" / "000" são rejeitados (não existe
    camisa zero). A Lambda de busca aplica exatamente a mesma regra; se mudar
    aqui, mude lá também.
    """
    valor = str(valor).strip()
    if not SOMENTE_DIGITOS.match(valor):
        return None
    valor = valor.lstrip("0")
    if not valor or len(valor) > TAMANHO_MAXIMO_CAMISA:
        return None
    return valor


def handler(event, context):
    try:
        dados = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return resposta(400, {"erro": "Corpo precisa ser um JSON válido."})

    numero_camisa = normalizar_camisa(dados.get("numero_camisa", ""))
    nome = str(dados.get("nome", "")).strip()
    tempo = str(dados.get("tempo", "")).strip()

    if not numero_camisa:
        return resposta(400, {"erro": f"Número da camisa obrigatório, somente números, até {TAMANHO_MAXIMO_CAMISA} dígitos."})
    if not nome or len(nome) > TAMANHO_MAXIMO_NOME:
        return resposta(400, {"erro": f"Nome obrigatório, até {TAMANHO_MAXIMO_NOME} caracteres."})
    if not TEMPO_VALIDO.match(tempo):
        return resposta(400, {"erro": "Tempo precisa estar no formato hh:mm:ss."})

    corredor = {"numero_camisa": numero_camisa, "nome": nome, "tempo": tempo}

    # MUDANÇA: PutItem condicional. Sem a condição, um segundo cadastro com a
    # mesma camisa sobrescreveria o primeiro em silêncio (PutItem substitui o
    # item inteiro). Com attribute_not_exists o DynamoDB só grava se ainda não
    # houver item com essa chave, e a checagem é atômica: dois cadastros
    # simultâneos da mesma camisa não passam os dois.
    try:
        tabela.put_item(
            Item=corredor,
            ConditionExpression="attribute_not_exists(numero_camisa)",
        )
    except tabela.meta.client.exceptions.ConditionalCheckFailedException:
        print(f"Camisa já cadastrada: {numero_camisa}")
        return resposta(409, {"erro": MENSAGEM_CAMISA_DUPLICADA})

    print(f"Corredor cadastrado: {corredor}")  # aparece no CloudWatch Logs
    return resposta(201, corredor)
