# Três Corpos

[English](README.md) | **Português**

O problema gravitacional dos três corpos, ao vivo, escrito em [Bend](https://bend-lang.com). A física roda na CPU; cada pixel de cada quadro é calculado na GPU.

![Figura-8 de Moore, Chenciner e Montgomery](preview-figure8.png)

![Problema pitagórico de Burrau](preview-burrau.png)

## Como rodar

Instale o Bend 2 e compile o binário nativo:

```bash
curl -fsSL https://bend-lang.com/install.sh | sh
bend main.bend -o tres && ./tres
```

A compilação gera `tres` e `tres.gpu`, que precisam ficar na mesma pasta.

Requisitos:

- clang 19 ou mais novo
- macOS: Metal
- Linux: CUDA 12 em `/usr/local/cuda` e `libx11-dev`

A GPU é usada por padrão. Para comparar com a CPU:

```bash
./tres --gpu off       # roda tudo na CPU, em paralelo
./tres --threads 8     # escolhe o número de threads da CPU
```

Testado em um Apple M5 com Bend 2.0.25: 60 FPS em 1280 × 720.

## Controles

| Tecla | Ação |
| --- | --- |
| `1`–`9`, `0` | Escolhe o cenário |
| `N` / `B` ou `→` / `←` | Próximo / anterior |
| `R` | Reinicia o cenário |
| `Espaço` | Pausa |
| `↑` / `↓` | Acelera / desacelera (de 1/8× a 8×) |
| `G` | Liga ou desliga as linhas de campo |
| `T` | Liga ou desliga o tour |
| `Esc` | Sai |

Com o tour ligado, o próximo cenário entra quando um corpo é ejetado ou quando o tempo do cenário acaba.

## Cenários

| # | Cenário |
| --- | --- |
| 1 | Figura-8 (Moore, Chenciner-Montgomery) |
| 2 | Borboleta I (Šuvakov-Dmitrašinović) |
| 3 | Mariposa I (Šuvakov-Dmitrašinović) |
| 4 | Yin-Yang I (Šuvakov-Dmitrašinović) |
| 5 | Novelo (Šuvakov-Dmitrašinović) |
| 6 | Triângulo de Lagrange: da ordem ao caos |
| 7 | Problema pitagórico de Burrau (massas 3, 4 e 5) |
| 8 | Estrela, planeta e lua |
| 9 | Planeta de duas estrelas |
| 0 | Caos: três massas ao acaso |

Os cinco primeiros são soluções periódicas. O triângulo de Lagrange é instável para massas iguais: aguenta algumas voltas até o arredondamento do último bit desfazê-lo. O último cenário sorteia três corpos novos a cada vez.

O título da janela e os nomes dos cenários dentro do app estão em inglês.

## Como funciona

### Física

- Três massas pontuais sob a lei de Newton, com G = 1 e praticamente sem suavização (1e-6 de uma unidade de comprimento).
- Posições e velocidades em *double-single*: um `F32` e o erro de arredondamento que ele deixou, somados com o TwoSum de Knuth.
- Integrador simplético de 4ª ordem de Forest-Ruth, uma composição de três leapfrogs.
- Passo adaptativo: 2% do tempo de queda livre ou de passagem do par mais próximo, para resolver um estilingue gravitacional em vez de pular por cima dele.
- O título da janela mostra a deriva da energia total em partes por milhão.

### Imagem

- O quadro inteiro é uma única chamada `!`, que o Bend manda para a GPU: oito níveis de bifurcações em quatro, de uma raiz de 2048 px até ladrilhos de 8 px (160 × 90 = 14 400 ladrilhos).
- Cada pixel é uma forma fechada dos três corpos: o brilho de cada um, as linhas equipotenciais do campo somado (tingidas pelo corpo que domina a região), um campo de estrelas e os rastros.
- Os rastros moram na própria imagem: o byte mais alto de cada pixel, que a janela nunca mostra, guarda quem passou por ali e há quanto tempo. O quadro anterior desce pela árvore de bifurcações para ser lido, envelhecido e descartado pixel a pixel.

## Leis e provas

`LAWS.bend` diz o que o programa tem que fazer, e `PROOF.bend` prova. O verificador do Bend confere cada lei para todas as entradas possíveis, e não para uma amostra, como um teste faria:

```bash
bend PROOF.bend --check-only
```

As provas passam no Bend 2.0.25 e no 2.0.34.

### Do one-shot

| Lei | O que garante |
| --- | --- |
| `esc_quits` | Esc encerra, qualquer que seja o mundo e o que vier depois. |
| `close_quits` | Fechar a janela encerra. |
| `pause_freezes` | Um quadro pausado não move os corpos, diga o relógio o que disser. |
| `space_twice` | Espaço duas vezes não muda nada. |

### Adicionadas depois, pelo Claude Opus 5.5

| Lei | O que garante |
| --- | --- |
| `step_keeps_mass` | Um passo do integrador nunca muda uma massa, quaisquer que sejam os corpos e o tamanho do passo. |
| `run_keeps_mass` | Nem uma simulação inteira, com quantos passos for (por indução). |
| `esc_anywhere` | Esc encerra em qualquer ponto dos eventos de um quadro, não importa o que veio antes. |
| `close_anywhere` | Fechar a janela também. |
| `digits_pick` | As teclas 1–9 escolhem os cenários 1–9, e o 0 escolhe o 10º, a partir de qualquer estado. |
| `n_cycles` | A partir do primeiro cenário, N passa pelos outros nove em ordem e volta ao primeiro. |
| `b_cycles` | B faz o mesmo de trás para frente. |
| `restart_restores` | Em qualquer um dos nove cenários fixos, R devolve os corpos exatamente ao início do cenário, não importa o que aconteceu antes. |
| `pause_keeps_run` | Um quadro pausado mantém o cenário, o tempo simulado e o relógio do tour. |
| `pause_keeps_trails` | Um quadro desenhado em pausa não apaga rastro nenhum. |
| `load_wipes` | Um cenário novo apaga os rastros antigos, uma única vez. |
| `g_twice` | G duas vezes não muda nada. |
| `t_twice` | T duas vezes não muda nada. |

Cada lei nova também foi testada contra bugs injetados de propósito, como deixar o integrador mexer numa massa, fazer o N pular um cenário ou fazer o R ir para o próximo. Todos os bugs fizeram a verificação falhar.

### O que não está provado, e por quê

A física. O verificador do Bend trata as contas com `F32` como caixas-pretas: não consegue provar nem `1.5 + 2.25 == 3.75` em `F32`. Todas as posições, velocidades e energias deste programa são `F32`, então nenhuma lei sobre órbitas, energia ou momento pode ser provada no Bend hoje. E em ponto flutuante energia e momento não se conservam exatamente, só de forma aproximada.

No lugar de prova, o programa oferece uma medição: o título da janela mostra, ao vivo, quanto a energia total se desviou do valor inicial, em partes por milhão.

Também ficam de fora a imagem calculada na GPU e o código de janela e teclado que conversa com o sistema operacional, que as provas do Bend não alcançam.

## Arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `main.bend` | A simulação: física, cenários, pixels, teclado e laço principal |
| `LAWS.bend` | As leis: o que o programa tem que fazer |
| `PROOF.bend` | As provas |

## Licença

[MIT](LICENSE) © Adriel Santana
