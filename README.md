# Três Corpos

O problema gravitacional dos três corpos, ao vivo, escrito em [Bend](https://bend-lang.com). A física roda na CPU; cada pixel de cada quadro é calculado na GPU.

![Figura-8 de Moore, Chenciner e Montgomery](previa-figura8.png)

![Problema pitagórico de Burrau](previa-burrau.png)

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

`LAWS.bend` enuncia quatro leis sobre o programa e `PROOF.bend` as prova:

- `esc_quits`: Esc encerra, qualquer que seja o mundo e o que vier depois.
- `close_quits`: fechar a janela encerra.
- `pause_freezes`: um mundo pausado não se move, diga o relógio o que disser.
- `space_twice`: Espaço duas vezes não muda nada.

Para conferir:

```bash
bend PROOF.bend --check-only
```

## Arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `main.bend` | A simulação: física, cenários, pixels, teclado e laço principal |
| `LAWS.bend` | As leis |
| `PROOF.bend` | As provas |

## Licença

[MIT](LICENSE) © Adriel Santana
