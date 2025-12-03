# Sistemas_digitais_Problema3

Funcionamento e integração do mouse

O controle interativo da aplicação — tanto para definir o ponto de interesse quanto para selecionar a área usada no zoom — é feito com um mouse USB ligado ao Hard Processor System (HPS) da DE1-SoC. Para que todo esse processo funcione de forma integrada, três componentes trabalham juntos: o driver do Linux, responsável por disponibilizar os eventos do dispositivo; a main em C, que faz a leitura e interpretação desses eventos; e a lógica implementada em Verilog no FPGA, que utiliza essas informações para atualizar a interface e executar as operações desejadas.

A captura dos eventos do mouse no Linux — como o sistema que roda no HPS — é feita por meio da biblioteca linux/input.h, que oferece a interface necessária para lidar com dispositivos de entrada. Nesse ambiente, o mouse aparece como um Event Device, normalmente acessado em /dev/input/eventX, onde o próprio sistema gerencia cada dispositivo conectado.

A biblioteca define a estrutura struct input_event, que organiza as informações enviadas pelo mouse. Cada evento contém três campos principais:

type, que indica o tipo de ação (por exemplo, EV_REL para movimentos ou EV_KEY para cliques);

code, que identifica exatamente qual eixo ou botão foi acionado, como REL_X, REL_Y ou BTN_LEFT;

value, que traz o valor associado ao evento, como o deslocamento em pixels ou o estado de um botão.

No programa em C — que se comunica também com rotinas em Assembly — o dispositivo é aberto como um arquivo comum. A leitura dos eventos acontece em um loop contínuo, utilizando a chamada read() para receber cada input_event à medida que ocorre. Isso permite que o sistema responda imediatamente aos movimentos e cliques do usuário, garantindo uma interação fluida entre o mouse e a aplicação.
