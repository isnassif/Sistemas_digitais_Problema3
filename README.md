<nav>
  <h2>Sumário</h2>
  <ul>
    <li><a href="#descricao">Descrição do projeto</a></li>
    <li><a href="#fluxo">Fluxo Geral de Execução</a></li> 
    <li><a href="#funcionamento">Funcionamento e Integração do Mouse</a></li>
    <li><a href="#captura">Mouse USB e Captura de Dados (linux/input.h)</a></li>  
     <li><a href="#exibicao">Exibição do Cursor pelo Verilog (Overlay de Hardware)</a></li>
      <li><a href="#quadro">Quadro de Seleção e Comando de Zoom</a></li>
      <li><a href="#pios">PIOs Utilizados no Controle do Mouse e Seleção</a></li>
    <li><a href="#main">Funções do C</a></li>
    <li><a href="#resultados">Resultados</a></li>
  </ul>
</nav>


# Sistemas_digitais_Problema3
<section id="descricao">
<h2>Descrição do Projeto</h2>

<p>O projeto desenvolvido nesta terceira etapa consiste em um <strong>sistema de zoom dinâmico</strong> com interação via <strong>mouse USB</strong>, executando sobre a plataforma <strong>DE1-SoC</strong>. O sistema combina um <strong>processador ARM (HPS)</strong> executando código em C e um <strong>coprocessador gráfico implementado em Verilog na FPGA</strong>, comunicando-se por meio da ponte AXI Lightweight.</p>

<p>O objetivo é permitir que o usuário selecione regiões da imagem exibida na saída VGA, realize cortes e aplique operações de <strong>zoom in</strong> e <strong>zoom out</strong> em tempo real, sem interferir no desempenho de exibição. Todo o processamento é controlado por comandos ISA enviados pelo HPS e interpretados pela controladora de hardware, que ativa os módulos específicos de ampliação e redução da imagem.</p>

<p>A principal inovação deste estágio está na introdução da <strong>interação direta por mouse</strong> e na <strong>geração do cursor e área de seleção via overlay em hardware</strong>, o que elimina a necessidade de reescrever a imagem na RAM a cada atualização. Essa abordagem garante resposta instantânea e visualização limpa das operações, integrando o pipeline de vídeo da FPGA com a interface do usuário no HPS.</p>
</section>



<section id="fluxo">
<h2>Fluxo Geral de Execução</h2>

<p>O sistema segue um fluxo de execução modular, dividindo claramente as responsabilidades entre software e hardware:</p>

<ol>
  <li><strong>Inicialização do Sistema</strong>  
    O programa em C inicializa as bases de memória (definidas em <code>hps_0.h</code>), carrega a imagem .MIF na memória do HPS e a transfere para o framebuffer da FPGA.</li>

  <li><strong>Mapeamento dos PIOs</strong>  
    As funções de mapeamento estabelecem acesso direto aos registradores da FPGA: controle do cursor (<code>CURSOR_X_PIO</code>, <code>CURSOR_Y_PIO</code>), ativação da seleção (<code>SELECTION_ENABLE_PIO</code>) e coordenadas da janela (<code>SEL_X1_PIO</code> a <code>SEL_Y2_PIO</code>).</li>

  <li><strong>Detecção e Leitura do Mouse</strong>  
    O dispositivo é identificado automaticamente dentro de <code>/dev/input/eventX</code>. Uma <strong>thread dedicada</strong> (<code>threadLeituraMouseUSB()</code>) lê continuamente os eventos <code>EV_REL</code> (movimento), <code>EV_KEY</code> (cliques) e <code>EV_WHEEL</code> (scroll), interpretando-os como comandos de movimento, corte e zoom.</li>

  <li><strong>Atualização do Overlay em Hardware</strong>  
    O módulo <code>vga_cursor_overlay.v</code> recebe as coordenadas do cursor e da seleção e as desenha diretamente sobre o vídeo VGA, sem alterar a imagem base. A comunicação ocorre em tempo real via PIOs, permitindo resposta imediata ao movimento do mouse.</li>

  <li><strong>Execução dos Algoritmos de Zoom</strong>  
    As operações de ampliação e redução são controladas por funções de alto nível (<code>aplicarZoomIn()</code> e <code>aplicarZoomOut()</code>), que enviam códigos ISA à controladora para ativar os módulos de <code>replicação</code>, <code>vizinho mais próximo</code>, <code>decimação</code> ou <code>média</code>. O resultado é exibido diretamente pela FPGA na tela VGA.</li>

  <li><strong>Corte e Atualização da Imagem</strong>  
    A função <code>aplicarCorte()</code> utiliza as coordenadas enviadas pelo mouse para copiar apenas a área selecionada para o centro da imagem. As demais regiões são preenchidas com <strong>preto (0x00)</strong>, e o buffer resultante é gravado novamente na RAM da FPGA, definindo a nova imagem de referência para operações posteriores.</li>

  <li><strong>Loop Contínuo e Multithreading</strong>  
    O programa roda em duas threads principais: uma para <strong>entrada de eventos</strong> e outra para <strong>atualização visual</strong>. Esse paralelismo garante que o cursor e a seleção sejam atualizados mesmo durante a execução de comandos de zoom, mantendo o sistema responsivo.</li>
</ol>

<p>Esse fluxo modular garante a integração completa entre o ambiente Linux do HPS e o hardware programável da FPGA, cumprindo todos os requisitos da etapa 3.</p>
</section>

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

<section id="main"> 
<h2>Principais Mudanças do C na Estrutura Atual do Sistema</h2> 

<p>Após compreender toda a integração entre o Verilog, os PIOs e a lógica de renderização em hardware, torna-se essencial analisar o papel da <code>main.c</code> dentro do funcionamento geral da aplicação. A versão atual passou por uma reestruturação profunda quando comparada à versão antiga, eliminando o antigo fluxo baseado em menus e introduzindo um modelo interativo, orientado por eventos do mouse, multithread e com atualização contínua dos registradores da FPGA. A seguir, são destacadas as principais mudanças e as funções centrais que compõem essa nova arquitetura.</p> 

<h3>1. Remoção do Menu Textual e Configuração Inicial</h3> 

<p>O antigo menu CLI foi completamente removido. A aplicação não opera mais por meio de entradas numéricas e loops de seleção. Em vez disso, o programa realiza apenas uma configuração inicial, na qual o usuário define os algoritmos desejados para zoom-in e zoom-out. Após esse momento, <strong>toda a interação ocorre por movimento e cliques do mouse</strong>. Esse novo comportamento é possibilitado pela inclusão de funções como <code>configurarAlgoritmos()</code> e <code>aplicarAlgoritmo()</code>, que encapsulam escolhas, regras e acionamentos dos modos de operação sem necessidade de navegação por menu.</p> 

<h3>2. Novas Funções de Mapeamento e Atualização de PIOs</h3> <p>Com a chegada dos novos PIOs — responsáveis pelo cursor, janela de seleção e sinais auxiliares — tornou-se necessário reorganizar o fluxo de escrita no hardware. Enquanto a versão antiga utilizava apenas o <code>CONTROL_PIO</code>, a versão atual controla <strong>oito registradores distintos</strong>, como <code>cursor_x_ptr</code>, <code>cursor_y_ptr</code>, <code>sel_x1_ptr</code>, <code>sel_x2_ptr</code>, entre outros.</p> <p>Para manter consistência e evitar condições de corrida em ambiente multithread, o código introduziu funções dedicadas, como:</p> <ul> <li><code>mapearRegistradoresCursor()</code> e <code>mapearRegistradoresSelecao()</code>, que isolam toda a lógica de mapeamento;</li> <li><code>atualizarCursorHardware()</code>, que sincroniza o envio da posição do cursor via PIO;</li> <li><code>atualizarCoordenadaImagem()</code>, responsável por projetar o movimento do mouse no espaço 160×120 da imagem.</li> </ul> <p>Essas funções trabalham em conjunto com um bloqueio <code>pthread_mutex</code> introduzido especificamente para garantir que leituras e escritas nos PIOs não ocorram simultaneamente entre diferentes threads.</p> <h3>3. Introdução de Multithreading para Responsividade</h3> <p>Uma das transformações mais importantes foi a adoção de threads. A versão antiga funcionava de maneira estritamente sequencial, o que tornava a interface lenta e fazia o programa travar enquanto operações demoradas ocorriam. Agora, a aplicação possui duas threads principais:</p> <ul> <li><code>threadLeituraMouseUSB()</code>: responsável por capturar eventos brutos do mouse (movimento, cliques e scroll) através de <code>linux/input.h</code>;</li> <li><code>threadAtualizacaoDisplay()</code>: encarregada de atualizar continuamente os PIOs, o overlay do cursor e o estado da seleção.</li> </ul> <p>Essa separação garante que o movimento do cursor nunca seja interrompido por cálculos de imagem ou operações de zoom, tornando o sistema fluido e altamente responsivo.</p> <h3>4. Nova Lógica de Zoom com Scroll do Mouse</h3> <p>O zoom, anteriormente controlado por opções no menu, agora é totalmente baseado no scroll do mouse. As funções <code>aplicarZoomIn()</code>, <code>aplicarZoomOut()</code> e <code>resetParaOriginal()</code> encapsulam regras internas, limites permitidos e comunicação com o hardware. A nova abordagem também introduziu buffers auxiliares em software (<code>imagem_original</code> e <code>imagem_backup</code>), permitindo restaurar o estado inicial da imagem sem depender do hardware — algo inexistente na implementação antiga.</p> <h3>5. Implementação Simples e Direta da Função de Corte</h3> <p>A funcionalidade de corte passou a operar de forma intuitiva para o usuário: basta clicar e arrastar para selecionar uma região. As coordenadas são enviadas continuamente aos PIOs, e, quando o corte é acionado, a função <code>aplicarCorte()</code> copia a região selecionada para o centro da imagem, preenche as áreas externas com preto e atualiza o buffer principal. O processo é simples, direto e totalmente integrado ao overlay da FPGA.</p> <h3>6. Estrutura Geral Mais Segura, Modular e Manutenível</h3> <p>Além de todas as novidades, a organização do código foi aprimorada. As funções agora possuem papéis bem definidos, evitam duplicação de lógica e seguem um fluxo claro: capturar → interpretar → atualizar PIOs → exibir. O uso de mutex, threads e funções especializadas tornou o sistema robusto e eliminou problemas de congelamento e inconsistência presentes na versão anterior.</p> <p>Com essas mudanças, a <code>main.c</code> deixa de ser apenas um controlador de fluxo textual e passa a ser o núcleo interativo de um sistema gráfico responsivo, concluindo integralmente os requisitos do projeto.</p> </section>
<section id="resultados">
<h2>Análise de Resultados</h2>

<p>Os testes realizados confirmaram que a integração HPS–FPGA se manteve estável e eficiente mesmo com a execução paralela de threads e o uso intensivo de eventos do mouse. O overlay de hardware eliminou o problema de cintilação observado nas primeiras versões, e a atualização do cursor passou a ser instantânea, sem atrasos perceptíveis.</p>

<p>O corte centralizado com pintura preta mostrou-se funcional e robusto, permitindo redefinir dinamicamente a imagem de referência sem interferir nos módulos de zoom. A troca entre algoritmos — replicação, vizinho mais próximo, decimação e média — é feita sem reinicialização do sistema, validando a eficiência da comunicação via PIO.</p>

<p>Durante os testes, o sistema atingiu taxas de atualização compatíveis com o clock de 25 MHz do VGA, mantendo a estabilidade visual mesmo em múltiplas operações consecutivas de zoom in/out. Não foram observados travamentos ou inconsistências entre o HPS e a FPGA, o que demonstra a maturidade da integração e da nova estrutura de software.</p>
</section>

<section id="referencias">
<h2>Referências</h2>

<ul>
  <li>INTEL FPGA. <em>DE1-SoC User Manual</em>. Terasic Technologies, 2023.</li>
  <li>INTEL FPGA. <em>AXI Bridge for HPS–FPGA Interface</em>. Documentation, 2022.</li>
  <li>Linux Kernel Documentation. <em>Input Subsystem and Event Devices</em> — <code>linux/input.h</code>.</li>
  <li>Tanenbaum, A. S. <em>Modern Operating Systems</em>. Pearson Education.</li>
  <li>Material didático da disciplina MI – Sistemas Digitais (UEFS, 2025.2).</li>
</ul>
</section>
