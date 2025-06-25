ENTRY (_bootrom)

MEMORY {
	BIOS_DATA : ORIGIN = 0x00020000, LENGTH = 2k
}

MEMORY {
	BIOS_CODE : ORIGIN = 0x00021000, LENGTH = 60k
}

MEMORY {
	BIOS_RODATA : ORIGIN = 0x00030000, LENGTH = 4K
}

MEMORY {
	BIOS_BSS : ORIGIN = 0x000020800, LENGTH = 2k
}

MEMORY {
	SHARED_DATA:	ORIGIN = 0x00100000, LENGTH = 128k
}

MEMORY {
	DRAM:	ORIGIN = 0x41000000, LENGTH = 16384k
}

PHDRS {
	bios_hdr PT_LOAD AT (0x00000000);
	bios_data PT_LOAD AT (0x00020000);
	bios_code PT_LOAD AT (0x00021000);
	bios_rodata PT_LOAD AT (0x00030000);
	bios_bss PT_LOAD AT (0x00020800);
	shared_data PT_LOAD AT (0x00100000);
	dram PT_LOAD AT (0x41000000);
}

SECTIONS {
	data: {
		. = 0x00020000;
		_start_data = .;
		*(data);
		. = ALIGN(2);
		_end_data = .;
	} >BIOS_DATA
	code: {
		. = 0x00021000;
		*(code);
		. = ALIGN(2);
		_etext = .;
	} >BIOS_CODE
	rodata: {
		. = 0x00030000;
		_start_rodata = .;
		*(rodata);
		. = ALIGN(2);
		_end_rodata = .;
	} >BIOS_RODATA
	bss: {
		. = 0x00020800
		_start_bss = .;
		*(bss);
		. = ALIGN(2);
		_end_bss = .;
	} >BIOS_BSS
	gvars: {
		. = 0x00100000;
		_start_gvars = .;
		*(gvars);
		_end_gvars = .;
	} >SHARED_DATA
	dram: {
		. = 0x41000000;
		_start_dram = .;
		*(dram);
		_end_dram = .;
	} >DRAM
}
