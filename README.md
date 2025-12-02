# Sistemas_digitais_Problema3

Compreendido. Vou consolidar e expandir as seções do relatório técnico no formato de texto simples, conforme solicitado, para uma visualização mais clara e completa.

---

### Estrutura de Memória e Mapeamento

A comunicação entre o Hard Processor System (HPS), executando o software (API em Assembly), e os periféricos implementados na FPGA é fundamentalmente baseada em **Acesso Mapeado à Memória (Memory-Mapped I/O - MMIO)**.

Para que o software possa controlar o coprocessador gráfico (PIOs de controle e a memória de imagem), é imperativo que o Kernel do Linux e a aplicação realizem o mapeamento dos endereços físicos da FPGA para o espaço de endereçamento virtual do processo em execução.

#### Acesso à Ponte AXI Lightweight (AXI-LW)

Todos os periféricos de controle e a memória de imagem que residem na FPGA são acessados pelo HPS através da ponte **AXI Lightweight (AXI-LW)**, que oferece um caminho de baixa latência. O endereço base físico desta ponte no espaço de endereçamento do ARM é **`0xFF200000`**.

#### Mapeamento de Memória (`mmap`)

O processo da API em Assembly utiliza as chamadas de sistema do Linux para interagir com o kernel:

1.  **Abertura do Recurso:** A rotina inicia abrindo o arquivo de dispositivo de memória (`/dev/mem`), que concede acesso ao espaço de endereçamento físico.
2.  **Mapeamento (`mmap`):** A função `mmap()` é então utilizada para:
    * **Obter o ponteiro de base virtual:** Mapeia o endereço físico da AXI-LW Bridge (`0xFF200000`) para um endereço virtual acessível pelo programa (Ex: `virtual_base_addr`).
    * **Calcular endereços de PIOs:** A partir do ponteiro de base virtual, os endereços dos PIOs de controle, status e o endereço da Memória de Imagem são calculados por meio de seus offsets definidos no Platform Designer.

Essa técnica permite que instruções de leitura e escrita simples (como `LDR` e `STR` em Assembly) no endereço virtual correspondente ao PIO sejam traduzidas diretamente em transações de barramento (Avalon/AXI-LW) que alcançam e controlam o hardware na FPGA.



---

### Códigos de Operação (Opcode)

Os Códigos de Operação (Opcodes) definem o **Conjunto de Instruções (ISA)** do coprocessador gráfico. Estes códigos são a forma como o software (API) instrui o hardware sobre qual algoritmo ou tarefa específica executar. Eles são escritos no registrador **CONTROL\_PIO** pelo HPS, acionando a máquina de estados e a lógica de controle correspondente na FPGA.

| Opcode (Valor Hex) | Nome Simbólico | Descrição da Operação na FPGA |
| :--- | :--- | :--- |
| `0x00` | IDLE / RESET | Estado de repouso. O código é usado para limpar o estado do coprocessador, preparando-o para receber a próxima instrução válida. |
| `0x01` | ZOOM\_IN | Aplica o algoritmo de ampliação (**Zoom 2x**) na área de seleção definida. O hardware utiliza interpolação de vizinho mais próximo para preencher os pixels expandidos. |
| `0x02` | DOWNSCALE | Aplica o algoritmo de redução (**Downscale 2x**) na imagem completa. O hardware deve realizar o agrupamento (pooling) de pixels e redução por eliminação ou amostragem. |
| `0x03` | APLICAR\_MEDIA | Executa a suavização na área de seleção ou imagem completa. O hardware calcula a média aritmética de 4 pixels vizinhos (2x2) para gerar um único pixel de saída, reduzindo o ruído. |
| `0x04` | MOSTRAR\_ORIGINAL | Comando para reverter a saída VGA para a exibição da imagem original de **160x120** sem qualquer redimensionamento ou *overlay* de zoom. |

---

### Principais Funções da API (HPS)

A API foi projetada como uma biblioteca de funções em Assembly ARMv7. Seu objetivo principal é atuar como um *driver* de *software* de baixo nível, encapsulando a complexidade da comunicação MMIO e disponibilizando uma interface limpa para a aplicação em C.

#### 1. Funções de Inicialização e Comunicação (MMIO)

| Função | Descrição |
| :--- | :--- |
| `int mapearPonte(void)` | **CRÍTICA.** Abre o `/dev/mem` e utiliza `mmap()` para criar o mapeamento de memória virtual da AXI-LW Bridge, configurando os ponteiros globais para acesso aos PIOs. Retorna 0 (sucesso) ou -1 (falha). |
| `void desmapearPonte(void)` | Libera os recursos: utiliza `munmap()` para desfazer o mapeamento de memória e fecha o descritor do arquivo `/dev/mem`. |
| `void transferirImagemFPGA(void *buffer_ptr, int size)` | Copia o conteúdo da imagem (lida do `.mif`) do buffer do HPS (RAM) para a Memória de Imagem na FPGA (SRAM ou DRAM), utilizando instruções `STR` em *loop*. |

#### 2. Funções de Controle do Coprocessador

| Função | Descrição |
| :--- | :--- |
| `void enviarComando(int opcode)` | **AÇÃO DE HARDWARE.** Escreve o valor do Opcode fornecido no registrador **`CONTROL_PIO`**. Esta única escrita aciona o coprocessador para iniciar a operação definida (Zoom, Downscale, Média). |

#### 3. Funções de Controle da Interface Gráfica (Mouse)

| Função | Descrição |
| :--- | :--- |
| `void escreverCoordenadasCursor(int x, int y, int enable)` | Envia as coordenadas (x, y) e o estado de ativação (`enable`) do cursor para os PIOs `CURSOR_X_PIO`, `CURSOR_Y_PIO` e `CURSOR_ENABLE_PIO`. Utilizada para rastrear o movimento do mouse. |
| `void escreverAreaSelecao(int x1, int y1, int x2, int y2, int enable)` | Define os limites do retângulo de seleção na imagem (160x120), escrevendo as quatro coordenadas de canto nos PIOs de seleção. Este retângulo é lido pelo módulo `vga_cursor_overlay.v` para desenhar o *overlay*. |

---
