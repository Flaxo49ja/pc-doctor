# Lista do comprador — antes, durante e depois da inspeccao

## Pergunte no chat ANTES de encontrar (qualquer hesitacao = sinal de alerta)

1. Porque esta a vender?
2. Quantos anos tem e quantas horas por dia usava?
3. Bateria: quanto dura agora com carga completa?
4. Ja teve reparaocoes? Ecran, teclado, placa trocados?
5. Tem alguma senha (BIOS/supervisor, Windows)? Remova antes de nos encontrarmos.
6. Posso arrancar o meu proprio USB na maquina? (Se nao → nem perca tempo.)

## Sinais de alerta

- Recusa arrancar pelo USB, ou insiste "veja so os screenshots"
- Pede sinal/entrada antes de voce testar
- Tem pressa ("tenho outro comprador esperando")
- Preco muito abaixo do mercado "porque preciso de dinheiro urgente"
- Numero de serie diferente entre as fotos e a maquina
- Vende "para um amigo" e nao sabe responder perguntas basicas

## O que levar

- Pen drive 1: ISO live do pc-doctor (Ventoy + ISO + MemTest86+)
- Pen drive 2: vazia, para testar todas as portas e copiar o relatorio
- Extensao + seu proprio carregador (teste a carga com adaptador conhecido)
- Chave Phillips pequena (inspeccao do painel inferior)
- Telefone: fotografe cada ecran de teste
- Copia impressa desta lista

## No encontro — ordem das coisas

1. Encontrem-se em lugar publico (shopping, cafe com energia)
2. A maquina deve arrancar do DESLIGADO na sua frente (observe lentidao ou falhas)
3. Arranque o USB → rode pc-doctor.sh → escreva o que o vendedor afirma
4. Fotografe a tabela "anuncio vs realidade" e o veredicto
5. So rode os testes lentos (leitura completa do disco) se os rapidos passarem
6. Verifique o BIOS: horas de uso, senha de supervisor, bloqueios anti-furto
7. So entao fale de dinheiro, usando a tabela de descontos
8. Pague apenas depois de: o USB arrancar, relatorio gravado, sem linhas MAU

## Depois de comprar (primeiras 48 horas)

- Rode MemTest86+ a noite inteira (2 passagens no minimo)
- Leitura completa do disco com badblocks
- Reinstale o sistema do zero — nunca confie nos dados do anterior
- Actualize o BIOS/firmware so do site do fabricante
