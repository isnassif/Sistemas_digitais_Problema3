# Sistemas_digitais_Problema3

Funcionamento e integração do mouse

O controle interativo da aplicação — tanto para definir o ponto de interesse quanto para selecionar a área usada no zoom — é feito com um mouse USB ligado ao Hard Processor System (HPS) da DE1-SoC. Para que todo esse processo funcione de forma integrada, três componentes trabalham juntos: o driver do Linux, responsável por disponibilizar os eventos do dispositivo; a main em C, que faz a leitura e interpretação desses eventos; e a lógica implementada em Verilog no FPGA, que utiliza essas informações para atualizar a interface e executar as operações desejadas.

Mouse USB e captura de dados

A captura dos eventos do mouse no Linux — como o sistema que roda no HPS — é feita por meio da biblioteca linux/input.h, que oferece a interface necessária para lidar com dispositivos de entrada. Nesse ambiente, o mouse aparece como um Event Device, normalmente acessado em /dev/input/eventX, onde o próprio sistema gerencia cada dispositivo conectado. A biblioteca define a estrutura struct input_event, que organiza as informações enviadas pelo mouse. Cada evento contém três campos principais:

type, que indica o tipo de ação (por exemplo, EV_REL para movimentos ou EV_KEY para cliques);
code, que identifica exatamente qual eixo ou botão foi acionado, como REL_X, REL_Y ou BTN_LEFT;
value, que traz o valor associado ao evento, como o deslocamento em pixels ou o estado de um botão.

No programa em C — que se comunica também com rotinas em Assembly — o dispositivo é aberto como um arquivo comum. A leitura dos eventos acontece em um loop contínuo, utilizando a chamada read() para receber cada input_event à medida que ocorre. Isso permite que o sistema responda imediatamente aos movimentos e cliques do usuário, garantindo uma interação fluida entre o mouse e a aplicação. O mouse USB conectado ao HPS, todos os dados de movimento e clique passam primeiro pelo kernel do Linux, que interpreta essas informações e as disponibiliza para os programas do usuário por meio da interface de eventos. O movimento enviado pelo mouse é sempre relativo: cada pacote traz apenas os valores de deslocamento nos eixos X e Y (delta X e delta Y). Cabe à aplicação em C acumular esses valores para atualizar a posição absoluta do cursor ao longo do tempo.

Como a imagem processada tem resolução de 160 × 120 pixels, enquanto a saída VGA opera em 640 × 480, o software também precisa fazer a conversão entre esses dois sistemas de coordenadas. Isso envolve transformar a posição absoluta do cursor — obtida a partir dos movimentos do mouse — para os limites da imagem original: X variando de 0 a 159 e Y de 0 a 119. É essa tradução que garante que o ponto selecionado pelo usuário na tela corresponda exatamente ao ponto correto dentro da imagem sendo manipulada pelo FPGA.

*Exibição do cusor pelo verilog*

A exibição do cursor e do retângulo de seleção na tela não é feita diretamente na memória da imagem — Decisão tomada após diversas complicações com reescrita de imagem na ram — mas sim por meio de uma sobreposição gerada em hardware. Esse trabalho é realizado pelo módulo vga_cursor_overlay.v, implementado na FPGA. Dessa forma, o cursor é desenhado instantaneamente, sem atraso perceptível e sem gerar cintilação, já que o desenho acontece no próprio fluxo da saída VGA.

O módulo opera em tempo real dentro do VGA, que roda a 25 MHz. A cada ciclo, ele recebe as coordenadas atuais de varredura da tela (vga_x e vga_y) e utiliza essas informações para decidir o que deve ser mostrado no pixel correspondente. A lógica consiste basicamente em comparar essas coordenadas com as posições do cursor e da área de seleção, enviadas ao FPGA pelos PIOs. Quando a coordenada atual coincide com o cursor ou com a borda do retângulo de seleção, o módulo substitui o pixel vindo da imagem (pixel_in) por uma cor própria do overlay, através dos sinais CURSOR_COLOR ou SEL_COLOR. Isso permite que o cursor e a janela de seleção apareçam sobre a imagem sem modificar o conteúdo original. 

O quadro de seleção é o elemento central para definir a área que será escolhida para aplicar os algoritmos. Ele é criado pelo usuário por meio de um clique seguido de arrasto. Assim que os limites do retângulo são definidos, o software envia os valores de X1, Y1, X2 e Y2 diretamente aos PIOs correspondentes.

O módulo vga_cursor_overlay.v compara as coordenadas da varredura com esses limites e desenha uma borda fina em branco. Após a seleção, o clique final aciona um comando de zoom, convertido em um opcode (ZOOM_IN ou DOWNSCALE), que o software escreve no CONTROL_PIO. A partir disso, o coprocessador gráfico passa a operar somente dentro da área escolhida.

Para o pleno funcionamento tanto do mouse quando da área de seleção, foi necessário criar uma instância do vga_cursor_overlay dentro da unidade de controle, isso permitiu sua instância funcionar de forma correta, além disso, foram também criados alguns pios, assunto que será discutido logo abaixo.

*Pios utilizados no projeto*

A comunicação entre o software em C e o módulo de overlay na FPGA acontece por meio de um conjunto de PIOs de 32 bits, mapeados no espaço de endereçamento da ponte, onde cada registrador tem uma função específica no controle do cursor e da área de seleção.

O par CURSOR_X_PIO e CURSOR_Y_PIO armazena as coordenadas do centro do cursor. Esses valores são atualizados continuamente pelo software conforme os eventos de movimento do mouse são recebidos. Já o CURSOR_ENABLE_PIO funciona como uma flag de controle, permitindo ativar ou desativar a exibição do cursor quando o usuário entra no modo de seleção.

Para a janela de zoom, o sistema utiliza dois pares de registradores. Os PIOs SEL_X1_PIO e SEL_Y1_PIO guardam as coordenadas do canto superior esquerdo da área de seleção, definidas no primeiro clique do usuário. Em seguida, os PIOs SEL_X2_PIO e SEL_Y2_PIO armazenam o canto inferior direito, que pode ser atualizado imediatamente no segundo clique ou continuamente durante o arrasto do mouse. Esses registradores fornecem ao hardware todas as informações necessárias para desenhar a seleção com precisão na saída VGA.

