#ifndef API_H
#define API_H

extern const unsigned int EXPECTED_IMG_WIDTH;
extern const unsigned int EXPECTED_IMG_HEIGHT;
extern const unsigned int EXPECTED_IMG_SIZE;

extern unsigned int IMAGE_MEM_BASE_VAL;
extern unsigned int CONTROL_PIO_BASE_VAL;

extern volatile unsigned char *IMAGE_MEM_ptr;
extern volatile unsigned int *CONTROL_PIO_ptr;

extern int fd;
extern void *LW_virtual;
extern unsigned char *hps_img_buffer;

extern int carregarImagemMIF(const char *path);

extern int mapearPonte(void);

extern void transferirImagemFPGA(int tamanho);

extern void enviarComando(int codigo);

extern void limparRecursos(void);

extern int obterCodigoEstado(int opcao);

#endif // API_H
