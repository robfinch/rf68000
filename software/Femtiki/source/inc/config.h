#ifndef CONFIG_H
#define CONFIG_H

#define NR_MAPS	2048
#define NR_ACB  32
#define NR_TCB  1024
#define NR_MBX  1024
#define NR_MSG  16384
#define NR_RQB	256
#define NR_SERVICE	64
#define NR_MEMORY	128
#define NR_DCB	32
#define READYQ_DEPTH	256

#define leds 0xFDFFC000

// Memory management
#define DRAM_BASE	0x40000000
#define MEM_PAGE_SIZE	8192
#define PAGE_MASK	0xffffe000
#define LOG_PAGESIZE 13

#endif
