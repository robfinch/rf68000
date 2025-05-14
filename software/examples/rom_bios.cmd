ENTRY (_start)

MEMORY {
	BIOS_DATA : ORIGIN = 0x00000000, LENGTH = 3k
}

MEMORY {
	BIOS_CODE : ORIGIN = 0x00001000, LENGTH = 40k
}

MEMORY {
	BIOS_RODATA : ORIGIN = 0x00010000, LENGTH = 12K
}

MEMORY {
	BIOS_BSS : ORIGIN = 0x00000800, LENGTH = 2k
}

PHDRS {
	bios_hdr PT_LOAD AT (0x00000000);
	bios_code PT_LOAD AT (0x00001000);
	bios_rodata PT_LOAD AT (0x00010000);
	bios_bss PT_LOAD AT (0x00000800);
}

SECTIONS {
	data: {
		. = 0x00000000;
		_start_data = .;
		*(data);
		. = ALIGN(2);
		_end_data = .;
	} >BIOS_DATA
	code: {
		. = 0x00001000;
		*(code);
		. = ALIGN(2);
		_etext = .;
	} >BIOS_CODE
	rodata: {
		. = 0x00010000;
		_start_rodata = .;
		*(rodata);
		. = ALIGN(2);
		_end_rodata = .;
	} >BIOS_RODATA
	bss: {
		. = 0x00000800
		_start_bss = .;
		*(bss);
		. = ALIGN(2);
		_end_bss = .;
	} >BIOS_BSS
	seg500: {
		. = 0x0000F00
		_start_seg500 = .;
		*(seg500);
		. = ALIGN(2);
		_end_seg500 = .;
	} >BIOS_BSS;
}
