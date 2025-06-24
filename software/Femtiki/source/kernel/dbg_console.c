extern memsetW(int *, int, int);
extern memsetT(long *, long, long);

// The text screen memory can only handle half-word transfers, hence the use
// of memsetH, memcpyH.
//#define DBGScreen	(__int32 *)0xFFD00000
#define TEXTVIDEO_REG	(unsigned long*)0xFD080000
#define DBGScreen	(unsigned long*)0xFD000000
#define DBGCOLS		64
#define DBGROWS		32

extern int IOFocusNdx;
extern __int8 DBGCursorCol;
extern __int8 DBGCursorRow;
extern int DBGAttr;
extern void puthexnum(int num, int wid, int ul, char padchar);
extern void out32(unsigned long* port, unsigned long val);
extern int get_coreno();

unsigned long rbo(unsigned long i)
{
	long o;
	
	o = (i >> 24) | ((i & 0xff0000) >> 8) | ((i & 0xff00) << 8) | ((i & 0xff) << 24);
	return (o);
}

unsigned long* DBGGetScreenLoc()
{
	return ((unsigned long *)((get_coreno() * DBGCOLS * DBGROWS) + DBGScreen));
}

void DBGClearScreen()
{
	unsigned long *p;
	unsigned long vc;

	p = DBGGetScreenLoc();
	//vc = AsciiToScreen(' ') | DBGAttr;
	vc = ' ' | DBGAttr;
	vc = rbo(vc);
	memsetT(p, vc, DBGROWS*DBGCOLS); //2604);
}

static void DBGSetVideoReg(int regno, unsigned long val)
{
	TEXTVIDEO_REG[regno] = rbo(val);
}

static unsigned long DBGGetVideoReg(int regno)
{
	return (rob(TEXTVIDEO_REG[regno]));
}

void DBGSetCursorPos(unsigned long pos)
{
	DBGSetVideoReg(11,pos);
}

void DBGUpdateCursorPos()
{
	unsigned long pos;

	pos = DBGGetScreenLoc();
	pos += DBGCursorRow * DBGCOLS + DBGCursorCol;
  DBGSetCursorPos(pos);
}

void DBGHomeCursor()
{
	DBGCursorCol = 0;
	DBGCursorRow = 0;
	DBGUpdateCursorPos();
}

void DBGBlankLine(int row)
{
	int *p;
	int nn;
	int mx;
	int vc;

	p = DBGScreen;
	p = p + row * DBGCOLS;
	vc = DBGAttr | ' ';
	vc = rbo(vc);
	memsetT(p, vc, DBGCOLS);
}

void DBGScrollUp()
{
	unsigned long *scrn = DBGGetScreenLoc();
	int nn;
	int count;

	count = DBGROWS * DBGCOLS;
	for (nn = 0; nn < count; nn++)
		scrn[nn] = scrn[nn+DBGCOLS];

	DBGBlankLine(DBGROWS-1);
}

void DBGIncrementCursorRow()
{
	if (DBGCursorRow < DBGROWS - 1) {
		DBGCursorRow++;
		DBGUpdateCursorPos();
		return;
	}
	DBGScrollUp();
}

void DBGIncrementCursorPos()
{
	DBGCursorCol++;
	if (DBGCursorCol < DBGCOLS) {
		DBGUpdateCursorPos();
		return;
	}
	DBGCursorCol = 0;
	DBGIncrementCursorRow();
}


void DBGDisplayChar(char ch)
{
	unsigned long *p;
	int nn;

	switch(ch) {
	case '\r':  DBGCursorCol = 0; DBGUpdateCursorPos(); break;
	case '\n':  DBGIncrementCursorRow(); break;
	case 0x91:
    if (DBGCursorCol < DBGCOLS - 1) {
       DBGCursorCol++;
       DBGUpdateCursorPos();
    }
    break;
	case 0x90:
    if (DBGCursorRow > 0) {
         DBGCursorRow--;
         DBGUpdateCursorPos();
    }
    break;
	case 0x93:
    if (DBGCursorCol > 0) {
         DBGCursorCol--;
         DBGUpdateCursorPos();
    }
    break;
	case 0x92:
    if (DBGCursorRow < DBGROWS-1) {
       DBGCursorRow++;
       DBGUpdateCursorPos();
    }
    break;
	case 0x94:
    if (DBGCursorCol==0)
       DBGCursorRow = 0;
    DBGCursorCol = 0;
    DBGUpdateCursorPos();
    break;
	case 0x99:  // delete
    p = DBGGetScreenLoc() + DBGCursorRow * DBGCOLS;
    for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
      p[nn] = p[nn+1];
    }
		p[nn] = rbo(DBGAttr | ' ');
    break;
	case 0x08: // backspace
    if (DBGCursorCol > 0) {
      DBGCursorCol--;
//	      p = DBGScreen;
  		p = DBGGetScreenLoc() + DBGCursorRow * DBGCOLS;
      for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
          p[nn] = p[nn+1];
      }
      p[nn] = rbo(DBGAttr | ' ');
		}
    break;
	case 0x0C:   // CTRL-L
    DBGClearScreen();
    DBGHomeCursor();
    break;
	case '\t':
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    break;
	default:
	  p = DBGGetScreenLoc();
	  nn = DBGCursorRow * DBGCOLS + DBGCursorCol;
	  //p[nn] = ch | DBGAttr;
	  out32rbo(&p[nn],ch | DBGAttr);
	  DBGIncrementCursorPos();
    break;
	}
}

void DBGCRLF()
{
   DBGDisplayChar('\r');
   DBGDisplayChar('\n');
}

void DBGDisplayString(char *s)
{
	// Declaring ch here causes the compiler to generate shorter faster code
	// because it doesn't have to process another *s inside in the loop.
	char ch;
  while (ch = *s) { DBGDisplayChar(ch); s++; }
}

void DBGDisplayAsciiString(unsigned char *s)
{
	// Declaring ch here causes the compiler to generate shorter faster code
	// because it doesn't have to process another *s inside in the loop.
	unsigned char ch;
  while (ch = *s) { DBGDisplayChar(ch); s++; }
}

void DBGDisplayStringCRLF(char *s)
{
   DBGDisplayString(s);
   DBGCRLF();
}

void DBGDisplayAsciiStringCRLF(unsigned char *s)
{
   DBGDisplayAsciiString(s);
   DBGCRLF();
}

void DBGHideCursor(int hide)
{
	unsigned int vr;

	if (hide) {
		vr = DBGGetVideoReg(8);
		DBGSetVideoReg(8,vr|0xffff);
	}
	else {
		vr = DBGGetVideoReg(8) & 0xFFFF0000;
		DBGSetVideoReg(8,vr|0x00E7);
	}
}
