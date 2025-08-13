#include "..\inc\const.h"
#include "..\inc\config.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"

//==============================================================================
// Keyboard stuff
//
// KeyState2_
// 76543210
// |||||||+ = left shift
// ||||||+- = alt
// |||||+-- = control
// ||||+--- = numlock
// |||+---- = capslock
// ||+----- = scrolllock
// |+------ = right shift
// +------- = extended
//
// The keyboard driver does not rely on the presence of an OS.
//==============================================================================

extern hMBX hKeybdMbx;
extern hMBX hKeybdIRQMbx;
unsigned char KeyState[256];
unsigned long KeybdTranslateThreadStack[260];
extern unsigned char keybdExtendedCodes[128];
extern unsigned char keybdControlCodes[128];
extern unsigned char shiftedScanCodes[256];
extern unsigned char unshiftedScanCodes[256];

void rotate_io_focus(int dir)
{
	if (IOFocusList==0)
		IOFocusList = 1;
	// Search for the next App to have focus according to search direction.
	do {
		IOFocusNdx += dir;
		if (IOFocusNdx >= NR_ACB)
			IOFocusNdx = 0;
		else if (IOFocusNdx < 0)
			IOFocusNdx = NR_ACB-1;
	} while (((IOFocusList >> IOFocusNdx) & 1) == 0);
	hKeybdMbx = ACBPtrs[IOFocusNdx]->hMailbox;
}

void KeybdTranslateThread()
{
	long d1,d2,d3;
	int er;
	int sr;
	unsigned char ScanCode;
	unsigned short int VirtKey;
	signed char KeyState1;
	unsigned char KeyState2;
	hMBX hMbx;
	MSG msg;

	DisplayStringCRLF("KbdTransThread");
	KeyState1 = 0;
	KeyState2 = 0;
	hKeybdMbx = ACBPtrs[0]->hMailbox;
	// All keys are up to begin with
	for (er = 0; er < 256; er++)
		KeyState[er] = 0xff;
	while(1) {
waitIRQ:
		DisplayStringCRLF("KbdTransThread: WaitMsg()");
		er = FMTK_WaitMsg(hKeybdIRQMbx, (long)&msg, MAX_INT);
		DisplayStringCRLF("KbdTransThread: after WaitMsg");
		if (er < 0)
			continue;
		// Keyboard query: return the state (up/down) of four requested keys.
		if ((msg.d1 & 0xffffL)==FM_QUERY_KEYBD) {
			hMbx = msg.d3 & 0xffffL;
			d3 = KeyState[msg.d2 & 0xffL]|
				(KeyState[(msg.d2 >> 8) & 0xff]<<8)|
				(KeyState[(msg.d2 >> 16) & 0xff]<<16)|
				(KeyState[(msg.d2 >> 24) & 0xff]<<24)
				;
			msg.d3 = d3;
			FMTK_SendMsg(hMbx,(long)&msg);
			continue;
		}
		if ((msg.d1 & 0xffffL) != FM_IRQ)
			continue;
		DisplayStringCRLF("KbdTransThread: IRQ Msg");
		ScanCode = msg.d3 & 0xffL;
		switch(ScanCode) {
		case SC_KEYUP:	KeyState1 = -1; break;
		case SC_EXTEND: KeyState2 |= 0x80; break;
		case SC_CTRL:		if (KeyState1 < 0) KeyState2 &= ~0x04; else KeyState2 |= 0x04; KeyState1 = 0; break;
		case SC_LSHIFT:	if (KeyState1 < 0) KeyState2 &= ~0x01; else KeyState2 |= 0x01; KeyState1 = 0; break;
		case SC_RSHIFT:	if (KeyState1 < 0) KeyState2 &= ~0x40; else KeyState2 |= 0x40; KeyState1 = 0; break;
		case SC_NUMLOCK:	KeyState2 ^= 0x08; break;
		case SC_CAPSLOCK:	KeyState2 ^= 0x10; break;
		case SC_SCROLLLOCK:	KeyState2 ^= 0x20; break;
		case SC_ALT:	if (KeyState1 < 0) KeyState2 &= ~0x02; else KeyState2 |= 0x02; KeyState1 = 0; break;
		default:
			if (KeyState1) {
				KeyState[VirtKey] = 0xff;
				msg.d1 = FM_KEYUP;
				msg.d2 =
					((unsigned long)KeyState2 << 24) |
					((unsigned long)ScanCode << 16) |
					VirtKey;
				msg.d3 = 0;
				FMTK_SendMsg(hKeybdMbx, (long)&msg);
			}
			else {
				if (KeyState2 & 0x80) {	// Extended?
					KeyState1 = 0;
					VirtKey = keybdExtendedCodes[ScanCode & 0x7f];
					msg.d1 = FM_KEYDOWN;
					msg.d2 =
						((unsigned long)KeyState2 << 24) |
						((unsigned long)ScanCode << 16) |
						VirtKey;
					msg.d3 = 0;
					FMTK_SendMsg(hKeybdMbx, (long)&msg);
					KeyState2 &= 0x7f;
					KeyState[VirtKey] = 0x00;
				}
				else if (KeyState2 & 0x04) {	// Control?
					KeyState1 = 0;
					VirtKey = keybdControlCodes[ScanCode & 0x7f];
					// CTRL-C?
					if (ScanCode==SC_C) {
						msg.d1 = FM_ABORT;
						msg.d2 =
							((unsigned long)KeyState2 << 24) |
							((unsigned long)ScanCode << 16) |
							VirtKey;
						msg.d3 = 0;
						FMTK_SendMsg(hKeybdMbx, (long)&msg);
					}
					else {
						msg.d1 = FM_KEYDOWN;
						msg.d2 =
							((unsigned long)KeyState2 << 24) |
							((unsigned long)ScanCode << 16) |
							VirtKey;
						msg.d3 = 0;
						FMTK_SendMsg(hKeybdMbx, (long)&msg);
					}
					KeyState2 &= 0xFB;
					KeyState[VirtKey] = 0x00;
				}
				else if (KeyState2 & 0x41) {	// Shift?
					KeyState1 = 0;
					VirtKey = shiftedScanCodes[ScanCode];
					// Alt-Shift-TAB?
					if ((KeyState2 & 2) && ScanCode==SC_TAB)
						rotate_io_focus(-1);
					else {
						msg.d1 = FM_KEYDOWN;
						msg.d2 =
							((unsigned long)KeyState2 << 24) |
							((unsigned long)ScanCode << 16) |
							VirtKey;
						msg.d3 = 0;
						FMTK_SendMsg(hKeybdMbx, (long)&msg);
					}
					KeyState2 &= 0xBE;
					KeyState[VirtKey] = 0x00;
				}
				else {	// Unshifted?
					KeyState1 = 0;
					VirtKey = unshiftedScanCodes[ScanCode];
					// Alt-TAB?
					if ((KeyState2 & 2) && ScanCode==SC_TAB)
						rotate_io_focus(1);
					else {
						msg.d1 = FM_KEYDOWN;
						msg.d2 =
							((unsigned long)KeyState2 << 24) |
							((unsigned long)ScanCode << 16) |
							VirtKey;
						msg.d3 = 0;
						FMTK_SendMsg(hKeybdMbx, (long)&msg);
					}
					KeyState[VirtKey] = 0x00;
				}			
			}
		}
	}	
}
