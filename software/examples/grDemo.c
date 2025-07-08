#define VIDEO_X	800
#define VIDEO_Y 600
#define VIDEO_Z 256

extern void clear(int);
extern void set_color(int,int);
extern void set_color_depth(int,int,int,int,int);
extern void set_dimen(int,int,int,int);
extern void drawbuf(int,int);
extern void dispbuf(int,int);
extern int get_char(int);
extern void plot_point3d(int,int,int,int,int);
extern void draw_line3d(int,int,int,int,int,int,int,int);
extern void draw_rectangle3d(int,int,int,int,int,int,int,int);
extern void draw_triangle3d(int,int,int,int,int,int,int,int,int,int,int);
extern void draw_curve3d(int,int,int,int,int,int,int,int,int,int,int);

static int hRand;
static int hGfx;
static int hKeybd;

static void white_rect()
{
	draw_rectangle3d(
		hGfx,		// device
		100<<16,		// x0
		300<<16,		// y0
		20<<16,			// z0
		250<<16,		// x1
		550<<16,		// y1
		20<<16,			// z1
		0xffffffff	// color
	);
}

static void rand_points()
{
	int nn;
	int xx,yy,zz,cc;

	for (nn = 0; nn < 20000; nn++) {
		xx = get_char(hRand) & 0xffff;		
		yy = get_char(hRand) & 0xffff;		
		zz = 20<<16;
		cc = get_char(hRand);
		plot_point3d(hGfx,xx,yy,zz,cc);
		if (get_char(hKeybd)==' ')
			break;
	}	
}

static void rand_lines()
{
	int nn;
	int xx0,yy0,zz0;
	int xx1,yy1,zz1;
	int cc;

	for (nn = 0; nn < 20000; nn++) {
		xx0 = get_char(hRand) & 0xffff;		
		yy0 = get_char(hRand) & 0xffff;		
		zz0 = 20<<16;
		xx1 = get_char(hRand) & 0xffff;		
		yy1 = get_char(hRand) & 0xffff;		
		zz1 = 20<<16;
		cc = get_char(hRand);
		draw_line3d(
			hGfx,
			xx0,
			yy0,
			zz0,
			xx1,
			yy1,
			zz1,
			cc
		);
		if (get_char(hKeybd)==' ')
			break;
	}	
}

static void rand_rects()
{
	int nn;
	int xx0,yy0,zz0;
	int xx1,yy1,zz1;
	int cc;

	for (nn = 0; nn < 20000; nn++) {
		xx0 = get_char(hRand) & 0xffff;		
		yy0 = get_char(hRand) & 0xffff;		
		zz0 = 20<<16;
		xx1 = get_char(hRand) & 0xffff;		
		yy1 = get_char(hRand) & 0xffff;		
		zz1 = 20<<16;
		cc = get_char(hRand);
		draw_rectangle3d (
			hGfx,
			xx0,
			yy0,
			zz0,
			xx1,
			yy1,
			zz1,
			cc
		);
		if (get_char(hKeybd)==' ')
			break;
	}	
}

static void rand_triangles()
{
	int nn;
	int xx0,yy0,zz0;
	int xx1,yy1,zz1;
	int xx2,yy2,zz2;
	int cc;

	for (nn = 0; nn < 20000; nn++) {
		xx0 = get_char(hRand) & 0xffff;		
		yy0 = get_char(hRand) & 0xffff;		
		zz0 = 20<<16;
		xx1 = get_char(hRand) & 0xffff;		
		yy1 = get_char(hRand) & 0xffff;		
		zz1 = 20<<16;
		xx2 = get_char(hRand) & 0xffff;		
		yy2 = get_char(hRand) & 0xffff;		
		zz2 = 20<<16;
		cc = get_char(hRand);
		draw_triangle3d (
			hGfx,
			xx0,
			yy0,
			zz0,
			xx1,
			yy1,
			zz1,
			xx2,
			yy2,
			zz2,
			cc
		);
		if (get_char(hKeybd)==' ')
			break;
	}	
}

static void rand_curves()
{
	int nn;
	int xx0,yy0,zz0;
	int xx1,yy1,zz1;
	int xx2,yy2,zz2;
	int cc;

	for (nn = 0; nn < 20000; nn++) {
		xx0 = get_char(hRand) & 0xffff;		
		yy0 = get_char(hRand) & 0xffff;		
		zz0 = 20<<16;
		xx1 = get_char(hRand) & 0xffff;		
		yy1 = get_char(hRand) & 0xffff;		
		zz1 = 20<<16;
		xx2 = get_char(hRand) & 0xffff;		
		yy2 = get_char(hRand) & 0xffff;		
		zz2 = 20<<16;
		cc = get_char(hRand);
		draw_curve3d (
			hGfx,
			xx0,
			yy0,
			zz0,
			xx1,
			yy1,
			zz1,
			xx2,
			yy2,
			zz2,
			cc
		);
		if (get_char(hKeybd)==' ')
			break;
	}	
}

void grDemo()
{
	int xx,yy;
	int* p;

	hKeybd = 0x20000;
	hRand = 0x90000;
	hGfx = 0x70000;
	set_color_depth(hGfx,8,8,8,8);
	set_color_depth(0x60000,8,8,8,8);
	set_dimen(hGfx,VIDEO_X,VIDEO_Y,VIDEO_Z);	
	set_dimen(0x60000,VIDEO_X,VIDEO_Y,VIDEO_Z);	
	drawbuf(hGfx,0);
	clear(hGfx);
	dispbuf(0x60000,0);
	// Draw criss-cross lines
	p = (int*)0x40000000;
	xx = 0;
	for (yy = 0; yy < 600; yy++) {
		xx = yy;
		p[xx+yy*VIDEO_X] = 0xffffff;	// white
		p[VIDEO_X-xx-1+yy*VIDEO_Y] = 0xffffff;
	}
	DBGDisplayString("Press w,p,r,t,c or x\r\n");
	while(1) {
		switch(get_char(hKeybd)) {
		case 'w':	white_rect(); break;
		case 'p': rand_points(); break;
		case 'r':	rand_rects(); break;
		case 't':	rand_triangles(); break;
		case 'c':	rand_curves(); break;
		case 'x':	return;
		}	
	}
}
