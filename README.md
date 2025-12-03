# Sistemas_digitais_Problema3

<nav>
  <h2>Sumário</h2>
  <ul>
    <li><a href="#funcionamento">Funcionamento e Integração do Mouse</a></li>
    <li><a href="#captura">Mouse USB e Captura de Dados (linux/input.h)</a></li>
    <li><a href="#exibicao">Exibição do Cursor pelo Verilog (Overlay de Hardware)</a></li>
    <li><a href="#quadro">Quadro de Seleção e Comando de Zoom</a></li>
    <li><a href="#pios">PIOs Utilizados no Controle do Mouse e Seleção</a></li>
  </ul>
</nav>

<section id="funcionamento">
<h2>Funcionamento e Integração do Mouse</h2>

<p>O controle interativo da aplicação — tanto para definir o ponto de interesse quanto para selecionar a área usada no zoom — é feito com um mouse USB ligado ao Hard Processor System (HPS) da DE1-SoC. Para que todo esse processo funcione de forma integrada, três componentes trabalham juntos: o driver do Linux, responsável por disponibilizar os eventos do dispositivo; a <code>main</code> em C, que faz a leitura e interpretação desses eventos; e a lógica implementada em Verilog no FPGA, que utiliza essas informações para atualizar a interface e executar as operações desejadas.</p>
</section>

<section id="captura">
<h2>Mouse USB e Captura de Dados (linux/input.h)</h2>

<p>A captura dos eventos do mouse no Linux — como o sistema que roda no HPS — é feita por meio da biblioteca <code>linux/input.h</code>, que oferece a interface necessária para lidar com dispositivos de entrada. Nesse ambiente, o mouse aparece como um Event Device, normalmente acessado em <code>/dev/input/eventX</code>, onde o próprio sistema gerencia cada dispositivo conectado. A biblioteca define a estrutura <code>struct input_event</code>, que organiza as informações enviadas pelo mouse. Cada evento contém três campos principais:</p>
<ol>
<li><code>type</code>, que indica o tipo de ação (por exemplo, <code>EV_REL</code> para movimentos ou <code>EV_KEY</code> para cliques);</li>
<li><code>code</code>, que identifica exatamente qual eixo ou botão foi acionado, como <code>REL_X</code>, <code>REL_Y</code> ou <code>BTN_LEFT</code>;</li>
<li><code>value</code>, que traz o valor associado ao evento, como o deslocamento em pixels ou o estado de um botão.</li>
</ol>
<p>No programa em C — que se comunica também com rotinas em Assembly — o dispositivo é aberto como um arquivo comum. A leitura dos eventos acontece em um loop contínuo, utilizando a chamada <code>read()</code> para receber cada <code>input_event</code> à medida que ocorre. Isso permite que o sistema responda imediatamente aos movimentos e cliques do usuário, garantindo uma interação fluida entre o mouse e a aplicação. O mouse USB conectado ao HPS, todos os dados de movimento e clique passam primeiro pelo kernel do Linux, que interpreta essas informações e as disponibiliza para os programas do usuário por meio da interface de eventos. O movimento enviado pelo mouse é sempre relativo: cada pacote traz apenas os valores de deslocamento nos eixos X e Y (delta X e delta Y). Cabe à aplicação em C acumular esses valores para atualizar a posição absoluta do cursor ao longo do tempo.</p>

<p>Como a imagem processada tem resolução de 160 × 120 pixels, enquanto a saída VGA opera em 640 × 480, o software também precisa fazer a conversão entre esses dois sistemas de coordenadas. Isso envolve transformar a posição absoluta do cursor — obtida a partir dos movimentos do mouse — para os limites da imagem original: X variando de 0 a 159 e Y de 0 a 119. É essa tradução que garante que o ponto selecionado pelo usuário na tela corresponda exatamente ao ponto correto dentro da imagem sendo manipulada pelo FPGA.</p>

</section>

<section id="exibicao">
<h2>Exibição do Cursor pelo Verilog (Overlay de Hardware)</h2>

<p>A exibição do cursor e do retângulo de seleção na tela não é feita diretamente na memória da imagem — Decisão tomada após diversas complicações com reescrita de imagem na RAM — mas sim por meio de uma sobreposição gerada em hardware. Esse trabalho é realizado pelo módulo <code>vga_cursor_overlay.v</code>, implementado na FPGA. Dessa forma, o cursor é desenhado instantaneamente, sem atraso perceptível e sem gerar cintilação, já que o desenho acontece no próprio fluxo da saída VGA.</p>

<p>O módulo opera em tempo real dentro do VGA, que roda a 25 MHz. A cada ciclo, ele recebe as coordenadas atuais de varredura da tela (<code>vga_x</code> e <code>vga_y</code>) e utiliza essas informações para decidir o que deve ser mostrado no pixel correspondente. A lógica consiste basicamente em comparar essas coordenadas com as posições do cursor e da área de seleção, enviadas ao FPGA pelos PIOs. Quando a coordenada atual coincide com o cursor ou com a borda do retângulo de seleção, o módulo substitui o pixel vindo da imagem (<code>pixel_in</code>) por uma cor própria do overlay, através dos sinais <code>CURSOR_COLOR</code> ou <code>SEL_COLOR</code>. Isso permite que o cursor e a janela de seleção apareçam sobre a imagem sem modificar o conteúdo original. Para o pleno funcionamento tanto do mouse quanto da área de seleção, foi necessário criar uma instância do <code>vga_cursor_overlay</code> dentro da unidade de controle do coprocessador, permitindo sua operação coordenada.</p>
</section>

<section id="quadro">
<h2>Quadro de Seleção e Comando de Zoom</h2>

<p>O quadro de seleção é o elemento central para definir a área que será escolhida para aplicar os algoritmos. Ele é criado pelo usuário por meio de um clique seguido de arrasto. Assim que os limites do retângulo são definidos, o software envia os valores de X1, Y1, X2 e Y2 diretamente aos PIOs correspondentes.</p>

<p>O módulo <code>vga_cursor_overlay.v</code> compara as coordenadas da varredura com esses limites e desenha uma borda fina em branco. Após a seleção, o clique final aciona um comando de zoom, convertido em um Opcode (<code>ZOOM_IN</code> ou <code>DOWNSCALE</code>), que o software escreve no <code>CONTROL_PIO</code>. A partir disso, o coprocessador gráfico passa a operar somente dentro da área escolhida.</p>

</section>

<section id="pios">
<h2>PIOs Utilizados no Controle do Mouse e Seleção</h2>

<p>A comunicação entre o software em C e o módulo de overlay na FPGA acontece por meio de um conjunto de PIOs de 32 bits, mapeados no espaço de endereçamento da ponte AXI-LW, onde cada registrador tem uma função específica no controle do cursor e da área de seleção.</p>

<p>O par <code>CURSOR_X_PIO</code> e <code>CURSOR_Y_PIO</code> armazena as coordenadas do centro do cursor. Esses valores são atualizados continuamente pelo software conforme os eventos de movimento do mouse são recebidos. Já o <code>CURSOR_ENABLE_PIO</code> funciona como uma flag de controle, permitindo ativar ou desativar a exibição do cursor quando o usuário entra no modo de seleção.</p>

<p>Para a janela de zoom, o sistema utiliza dois pares de registradores. Os PIOs <code>SEL_X1_PIO</code> e <code>SEL_Y1_PIO</code> guardam as coordenadas do canto superior esquerdo da área de seleção, definidas no primeiro clique do usuário. Em seguida, os PIOs <code>SEL_X2_PIO</code> e <code>SEL_Y2_PIO</code> armazenam o canto inferior direito, que pode ser atualizado imediatamente no segundo clique ou continuamente durante o arrasto do mouse. Esses registradores fornecem ao hardware todas as informações necessárias para desenhar a seleção com precisão na saída VGA.</p>
</section>
