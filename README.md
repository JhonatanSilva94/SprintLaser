# SprintLaser

Site da SprintLaser, empresa de gravação a laser em medalhas de corrida e brindes para eventos.

🔗 **https://sprintlaser.com**

## Como funciona

No dia da corrida, o site organiza a fila de gravação das medalhas:

1. O corredor escaneia um QR code e preenche nome e tempo de prova.
2. O site mostra um código na tela (`01`, `02`, `03`…).
3. Na fila, ele apresenta o código ao gravador.
4. O gravador digita o código e vê o que precisa gravar na medalha.

Ao fim de cada corrida, os dados são apagados.

## Tecnologias

- **Site:** HTML, CSS e JavaScript
- **Nuvem:** AWS (S3, CloudFront, API Gateway, Lambda, DynamoDB e Route 53)
- **Back-end:** Python
- **Infraestrutura como código:** Terraform
