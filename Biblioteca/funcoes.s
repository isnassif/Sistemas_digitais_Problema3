.syntax unified
    .arch armv7-a
    .text
    .align 2
    
@ ============================================================================
@ Definições de constantes
@ ============================================================================

    .equ LW_BRIDGE_BASE, 0xFF200000
    .equ LW_BRIDGE_SPAN, 0x30000
    .equ IMAGE_MEM_SIZE_DEFAULT, 0xC000
    
    .equ ST_RESET, 7
    .equ ST_REPLICACAO, 0
    .equ ST_DECIMACAO, 1
    .equ ST_ZOOMNN, 2
    .equ ST_MEDIA, 3
    .equ ST_COPIA_DIRETA, 4
    .equ ST_REPLICACAO4, 8
    .equ ST_DECIMACAO4, 9
    .equ ST_ZOOMNN4, 10
    .equ ST_MED4, 11
    
    .equ O_RDWR, 0x2
    .equ O_RDONLY, 0x0
    .equ O_SYNC, 0x101000
    .equ PROT_READ, 0x1
    .equ PROT_WRITE, 0x2
    .equ MAP_SHARED, 0x1

@ ============================================================================
@ Declarações de funções exportadas
@ ============================================================================

    .global carregarImagemMIF
    .global mapearPonte
    .global transferirImagemFPGA
    .global enviarComando
    .global limparRecursos
    .global obterCodigoEstado
    .type carregarImagemMIF, %function
    .type mapearPonte, %function
    .type transferirImagemFPGA, %function
    .type enviarComando, %function
    .type limparRecursos, %function
    .type obterCodigoEstado, %function

@ ============================================================================
@ Função: carregarImagemMIF
@ Argumentos: r0 = path (const char*)
@ Retorno: r0 = número de bytes carregados ou -1 em erro
@ ============================================================================

carregarImagemMIF:
    push    {r4-r11, lr}
    sub     sp, sp, #144
    
    mov     r4, r0              @ r4 = path
    ldr     r11, =0xC000        @ r11 = IMAGE_MEM_SIZE
    
    @ ========================================
    @ Alocar memória com malloc (mais seguro que brk direto)
    @ ========================================
    mov     r0, r11
    bl      malloc
    ldr     r6, =hps_img_buffer
    str     r0, [r6]
    mov     r7, r0              @ r7 = buffer alocado
    
    cmp     r7, #0
    beq     return_error
    
    @ ========================================
    @ Abrir arquivo com fopen
    @ ========================================
    mov     r0, r4
    ldr     r1, =mode_r
    bl      fopen
    mov     r5, r0              @ r5 = file pointer
    
    cmp     r5, #0
    beq     free_and_error
    
    @ ========================================
    @ Variáveis de controle
    @ ========================================
    mov     r8, #0              @ r8 = index saída
    mov     r10, sp             @ r10 = buffer linha
    
read_loop:
    @ ========================================
    @ Ler linha com fgets
    @ ========================================
    mov     r0, r10
    mov     r1, #128
    mov     r2, r5
    bl      fgets
    
    cmp     r0, #0
    beq     read_done
    
    @ ========================================
    @ Verificar strings a ignorar
    @ ========================================
    mov     r0, r10
    ldr     r1, =str_content
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_begin
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_end
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_addr_radix
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_data_radix
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_width
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    mov     r0, r10
    ldr     r1, =str_depth
    bl      my_strstr
    cmp     r0, #0
    bne     read_loop
    
    @ ========================================
    @ Parse hexadecimal
    @ ========================================
    mov     r0, r10
    bl      parse_mif_line
    cmp     r0, #0
    blt     read_loop
    
    @ ========================================
    @ Armazenar byte
    @ ========================================
    cmp     r8, r11
    bge     read_loop
    
    strb    r0, [r7, r8]
    add     r8, r8, #1
    
    b       read_loop

read_done:
    mov     r0, r5
    bl      fclose
    
    mov     r0, r8
    add     sp, sp, #144
    pop     {r4-r11, pc}

free_and_error:
    mov     r0, r7
    bl      free
    b       return_error

close_and_error:
    mov     r0, r5
    bl      fclose
    mov     r0, r7
    bl      free
    
return_error:
    mvn     r0, #0
    add     sp, sp, #144
    pop     {r4-r11, pc}

    .size carregarImagemMIF, .-carregarImagemMIF

@ ============================================================================
@ Função auxiliar: my_strstr
@ ============================================================================
my_strstr:
    push    {r4-r7, lr}
    mov     r4, r0              @ r4 = haystack
    mov     r5, r1              @ r5 = needle
    
    @ Verifica se needle é vazia
    ldrb    r6, [r5]
    cmp     r6, #0
    beq     strstr_found_start
    
strstr_outer:
    ldrb    r6, [r4]
    cmp     r6, #0
    beq     strstr_not_found
    
    @ Compara caracteres
    mov     r2, r4
    mov     r3, r5
    
strstr_inner:
    ldrb    r6, [r3]
    cmp     r6, #0
    beq     strstr_found
    
    ldrb    r7, [r2]
    cmp     r7, #0
    beq     strstr_not_found
    
    cmp     r6, r7
    bne     strstr_next
    
    add     r2, r2, #1
    add     r3, r3, #1
    b       strstr_inner
    
strstr_next:
    add     r4, r4, #1
    b       strstr_outer
    
strstr_found_start:
    mov     r0, r4
    pop     {r4-r7, pc}
    
strstr_found:
    mov     r0, r4
    pop     {r4-r7, pc}
    
strstr_not_found:
    mov     r0, #0
    pop     {r4-r7, pc}

@ ============================================================================
@ Função auxiliar: parse_mif_line
@ ============================================================================
parse_mif_line:
    push    {r4-r6, lr}
    mov     r4, r0
    
    @ Procura ':'
find_colon:
    ldrb    r1, [r4]
    cmp     r1, #0
    beq     parse_invalid
    
    cmp     r1, #':'
    beq     found_colon
    
    add     r4, r4, #1
    b       find_colon
    
found_colon:
    add     r4, r4, #1
    
    @ Pula espaços
skip_spaces:
    ldrb    r1, [r4]
    cmp     r1, #' '
    beq     skip_space_char
    cmp     r1, #0x09
    beq     skip_space_char
    b       start_convert
    
skip_space_char:
    add     r4, r4, #1
    b       skip_spaces
    
start_convert:
    @ Converte hex para int
    mov     r5, #0              @ r5 = resultado
    mov     r6, #0              @ r6 = contador de dígitos
    
convert_hex:
    ldrb    r1, [r4]
    
    @ Verifica fim
    cmp     r1, #0
    beq     check_valid
    cmp     r1, #' '
    beq     check_valid
    cmp     r1, #0x0A
    beq     check_valid
    cmp     r1, #0x0D
    beq     check_valid
    cmp     r1, #';'
    beq     check_valid
    cmp     r1, #0x09
    beq     check_valid
    
    @ Converte dígito hex
    cmp     r1, #'0'
    blt     parse_invalid
    cmp     r1, #'9'
    ble     convert_digit
    
    @ Converte A-F ou a-f
    orr     r1, r1, #0x20       @ Minúscula
    cmp     r1, #'a'
    blt     parse_invalid
    cmp     r1, #'f'
    bgt     parse_invalid
    
    sub     r1, r1, #'a'
    add     r1, r1, #10
    b       add_digit
    
convert_digit:
    sub     r1, r1, #'0'
    
add_digit:
    lsl     r5, r5, #4
    add     r5, r5, r1
    add     r4, r4, #1
    add     r6, r6, #1
    b       convert_hex

check_valid:
    @ Pelo menos 1 dígito deve ter sido lido
    cmp     r6, #0
    beq     parse_invalid
    
parse_done:
    mov     r0, r5
    pop     {r4-r6, pc}
    
parse_invalid:
    mvn     r0, #0
    pop     {r4-r6, pc}

@ ============================================================================
@ Função: mapearPonte
@ ============================================================================

mapearPonte:
    push    {r4-r7, lr}
    
    ldr     r4, =0xFF200000
    ldr     r5, =0x30000
    
    @ fd = open("/dev/mem", O_RDWR | O_SYNC);
    ldr     r0, =dev_mem_path
    ldr     r1, =0x101002
    bl      open
    ldr     r6, =fd
    str     r0, [r6]
    
    cmn     r0, #1
    beq     mapear_error
    
    mov     r7, r0
    
    @ mmap
    mov     r0, #0
    mov     r1, r5
    mov     r2, #3
    mov     r3, #1
    str     r7, [sp, #-8]!
    str     r4, [sp, #4]
    bl      mmap
    add     sp, sp, #8
    
    ldr     r6, =LW_virtual
    str     r0, [r6]
    
    cmn     r0, #1
    beq     mapear_error
    
    mov     r4, r0
    
    @ IMAGE_MEM_ptr
    ldr     r1, =IMAGE_MEM_BASE_VAL
    ldr     r1, [r1]
    add     r1, r4, r1
    ldr     r2, =IMAGE_MEM_ptr
    str     r1, [r2]
    
    @ CONTROL_PIO_ptr
    ldr     r1, =CONTROL_PIO_BASE_VAL
    ldr     r1, [r1]
    add     r1, r4, r1
    ldr     r2, =CONTROL_PIO_ptr
    str     r1, [r2]
    
    mov     r0, #0
    pop     {r4-r7, pc}
    
mapear_error:
    mvn     r0, #0
    pop     {r4-r7, pc}

    .size mapearPonte, .-mapearPonte

@ ============================================================================
@ Função: transferirImagemFPGA
@ ============================================================================

transferirImagemFPGA:
    push    {r4-r6, lr}
    
    mov     r4, r0
    
    ldr     r5, =IMAGE_MEM_ptr
    ldr     r0, [r5]
    
    ldr     r5, =hps_img_buffer
    ldr     r1, [r5]
    
    mov     r2, r4
    
    bl      memcpy
    
    pop     {r4-r6, pc}

    .size transferirImagemFPGA, .-transferirImagemFPGA

@ ============================================================================
@ Função: enviarComando
@ ============================================================================

enviarComando:
    push    {r4, lr}
    
    mov     r4, r0
    
    ldr     r0, =CONTROL_PIO_ptr
    ldr     r0, [r0]
    str     r4, [r0]
    
    dmb     sy
    
    ldr     r0, =10000
    bl      usleep
    
    pop     {r4, pc}

    .size enviarComando, .-enviarComando

@ ============================================================================
@ Função: limparRecursos
@ ============================================================================

limparRecursos:
    push    {r4-r6, lr}
    
    ldr     r4, =hps_img_buffer
    ldr     r0, [r4]
    cmp     r0, #0
    beq     limpar_skip_free
    
    bl      free
    
    mov     r0, #0
    str     r0, [r4]
    
limpar_skip_free:
    ldr     r5, =LW_virtual
    ldr     r0, [r5]
    cmn     r0, #1
    beq     limpar_skip_munmap
    
    ldr     r1, =0x30000
    bl      munmap
    
    mvn     r0, #0
    str     r0, [r5]
    
limpar_skip_munmap:
    ldr     r6, =fd
    ldr     r0, [r6]
    cmn     r0, #1
    beq     limpar_skip_close
    
    bl      close
    
    mvn     r0, #0
    str     r0, [r6]
    
limpar_skip_close:
    pop     {r4-r6, pc}

    .size limparRecursos, .-limparRecursos

@ ============================================================================
@ Função: obterCodigoEstado
@ ============================================================================

obterCodigoEstado:
    cmp     r0, #1
    blt     codigo_invalido
    cmp     r0, #10
    bgt     codigo_invalido
    
    sub     r0, r0, #1
    
    ldr     r1, =tabela_codigos
    
    ldr     r0, [r1, r0, lsl #2]
    
    bx      lr
    
codigo_invalido:
    mvn     r0, #0
    bx      lr

    .size obterCodigoEstado, .-obterCodigoEstado

@ ============================================================================
@ Tabela de códigos
@ ============================================================================

    .align 2
tabela_codigos:
    .word   7
    .word   0
    .word   1
    .word   2
    .word   3
    .word   4
    .word   8
    .word   9
    .word   10
    .word   11

@ ============================================================================
@ Seção de dados
@ ============================================================================

    .data
    .align 2

    .global IMAGE_MEM_ptr
    .global CONTROL_PIO_ptr
    .global fd
    .global LW_virtual
    .global hps_img_buffer

IMAGE_MEM_ptr:
    .word   0

CONTROL_PIO_ptr:
    .word   0

fd:
    .word   -1

LW_virtual:
    .word   -1

hps_img_buffer:
    .word   0

    .global IMAGE_MEM_BASE_VAL
    .global CONTROL_PIO_BASE_VAL

IMAGE_MEM_BASE_VAL:
    .word   0

CONTROL_PIO_BASE_VAL:
    .word   0

    .global EXPECTED_IMG_WIDTH
    .global EXPECTED_IMG_HEIGHT
    .global EXPECTED_IMG_SIZE

EXPECTED_IMG_WIDTH:
    .word   160

EXPECTED_IMG_HEIGHT:
    .word   120

EXPECTED_IMG_SIZE:
    .word   19200

@ ============================================================================
@ Strings e constantes
@ ============================================================================

    .section .rodata
    .align 2

mode_r:
    .asciz "r"

dev_mem_path:
    .asciz "/dev/mem"
    
str_content:
    .asciz "CONTENT"
    
str_begin:
    .asciz "BEGIN"
    
str_end:
    .asciz "END"
    
str_addr_radix:
    .asciz "ADDRESS_RADIX"
    
str_data_radix:
    .asciz "DATA_RADIX"
    
str_width:
    .asciz "WIDTH"
    
str_depth:
    .asciz "DEPTH"
