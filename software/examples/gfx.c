/*
Bare metal OpenCores GFX IP driver for Wishbone bus.

Anton Fosselius, Per Lenander 2012
  */

#include "gfx.h"
#include "gfx_regs.h"

#define GFX_STAT_COUNT_OFFSET 16
#define GFX_INSTRUCTION_FIFO_SIZE 2048

#define SUBPIXEL_WIDTH 16

/* VGA defines */
#define FRAMEBUF_BASEADDR   0xFD208000 /* Bus Adress to VGA */

//#define VGA_CTRL       (VGA_BASEADDR + 0x000) /* Control Register */
//#define VGA_STAT       (VGA_BASEADDR + 0x004) /* Status Register */
//#define VGA_HTIM       (VGA_BASEADDR + 0x008) /* Horisontal Timing Register */
//#define VGA_VTIM       (VGA_BASEADDR + 0x00c) /* Vertical Timing Register */
//#define VGA_HVLEN      (VGA_BASEADDR + 0x010) /* Horisontal and Vertical Total Screen Size, (Screen size + Blank) */
#define FRAMEBUF_VBARA     	(FRAMEBUF_BASEADDR + 0x010) /* Adress to Video Base Register A */
#define FRAMEBUF_VBARB     	(FRAMEBUF_BASEADDR + 0x018) /* Adress to Video Base Register B */
#define FRAMEBUF_PALETTE   	(FRAMEBUF_BASEADDR + 0x2000) /* Color Palette */
#define FRAMEBUF_COLOR_COMP	(FRAMEBUF_BASEADDR + 0x098)


//#define VGA_STAT_AVMP 16
//#define VGA_CTRL_VEN   0x00000001 /* Video Enable */
//#define VGA_CTRL_HIE   0x00000002 /* HSync Interrupt Enable */
//#define VGA_CTRL_PC    0x00000800 /* 8-bit Pseudo Color Enable*/
//#define VGA_CTRL_CD8   0x00000000 /* Color Depth 8 */
//#define VGA_CTRL_CD16  0x00000200 /* Color Depth 16 */
//#define VGA_CTRL_CD24  0x00000400 /* Color Depth 24 */
//#define VGA_CTRL_CD32  0x00000600 /* Color Depth 32 */
//#define VGA_CTRL_VBL1  0x00000000 /* Burst Length 1 */
//#define VGA_CTRL_VBL2  0x00000080 /* Burst Length 2 */
//#define VGA_CTRL_VBL4  0x00000100 /* Burst Length 4 */
//#define VGA_CTRL_VBL8  0x00000180 /* Burst Length 8 */
//#define VGA_CTRL_VBSWE 0x00000020 /* Bank switch enable */

// Generate bits from gfx_regs.h

/* ===================== */
/* Control register bits */
/* ===================== */
//#define GFX_CTRL_CD8         0                               /* Color Depth 8              */
//#define GFX_CTRL_CD16        (1 << GFX_CTRL_COLOR_DEPTH    ) /* Color Depth 16             */
//#define GFX_CTRL_CD24        (2 << GFX_CTRL_COLOR_DEPTH    ) /* Color Depth 24             */ // Not supported!
//#define GFX_CTRL_CD32        (3 << GFX_CTRL_COLOR_DEPTH    ) /* Color Depth 32             */
//#define GFX_CTRL_CDMASK      (3 << GFX_CTRL_COLOR_DEPTH    ) /* All color depth bits       */

#define GFX_TEXTURE_ENABLE   (1 << GFX_CTRL_TEXTURE        ) /* Enable Texture Reads       */
#define GFX_BLEND_ENABLE     (1 << GFX_CTRL_BLENDING       ) /* Enable Alpha Blending      */
#define GFX_COLORKEY_ENABLE  (1 << GFX_CTRL_COLORKEY       ) /* Enable Colorkeying         */
#define GFX_CLIPPING_ENABLE  (1 << GFX_CTRL_CLIPPING       ) /* Enable Clipping/Scissoring */
#define GFX_ZBUFFER_ENABLE   (1 << GFX_CTRL_ZBUFFER        ) /* Enable depth buffer        */


#define GFX_POINT            (1 << GFX_CTRL_POINT          ) /* Put point                   */
#define GFX_RECT             (1 << GFX_CTRL_RECT           ) /* Put rect                   */
#define GFX_LINE             (1 << GFX_CTRL_LINE           ) /* Put line                   */
#define GFX_TRI              (1 << GFX_CTRL_TRI            ) /* Put triangle               */
#define GFX_CHAR             (1 << GFX_CTRL_CHAR           ) /* Put character               */
#define GFX_FLOODFILL        (1 << GFX_CTRL_FLOODFILL      ) /* Put character               */

#define GFX_CURVE            (1 << GFX_CTRL_CURVE          ) /* Put curve                  */
#define GFX_INTERP           (1 << GFX_CTRL_INTERP         ) /* Activate interpolation     */
#define GFX_INSIDE           (1 << GFX_CTRL_INSIDE         ) /* Bezier inside/outside      */

#define GFX_ACTIVE_POINT0    0                               /* Set the active point to p0 */
#define GFX_ACTIVE_POINT1    (1 << GFX_CTRL_ACTIVE_POINT   ) /* Set the active point to p1 */
#define GFX_ACTIVE_POINT2    (2 << GFX_CTRL_ACTIVE_POINT   ) /* Set the active point to p2 */
#define GFX_ACTIVE_POINTMASK (3 << GFX_CTRL_ACTIVE_POINT   )
#define GFX_FORWARD_POINT    (1 << GFX_CTRL_FORWARD_POINT  ) /* Forward the active point   */
#define GFX_TRANSFORM_POINT  (1 << GFX_CTRL_TRANSFORM_POINT) /* Transform the active point */

/* ==================== */
/* Status register bits */
/* ==================== */
#define GFX_BUSY        (1 << GFX_STAT_BUSY           ) /* Ready for op */

/* Register access macros */
#define REG8(add)  *((volatile unsigned char  *)(add))
#define REG16(add) *((volatile unsigned short *)(add))
#define REG32(add) *((volatile unsigned int   *)(add))

// Wait until req_spaces number of places in the instruction fifo are clear
int gfx_wait(unsigned int reg_spaces)
{
//  while( REG32(GFX_STATUS)) & GFX_BUSY );
  while((REG32(GFX_STATUS) >> GFX_STAT_COUNT_OFFSET) + reg_spaces > GFX_INSTRUCTION_FIFO_SIZE)
  {
  	if (CheckForCtrlC())
  		return (0);
  }
  return (1);
}

unsigned int memory_base = GFX_VMEM;
struct gfx_surface* target_surface = 0;
struct gfx_surface* tex0_surface = 0;
struct gfx_surface* zbuffer_surface = 0;
unsigned int gfx_control_reg_memory = 0;

// Forward or transform points?
unsigned int transformation_mode = GFX_FORWARD_POINT;

void set_color_depth(unsigned int dev, unsigned int comp,  
	unsigned int r, unsigned int g, unsigned int b);
/*
void Set640x480_60(void)
{
    // Set horizontal timing register
    REG32(VGA_HTIM) = ((96 - 1) << 24) |
            ((48 - 1) << 16) |
            (640 - 1);
    // Set vertical timing register
    REG32(VGA_VTIM) = ((2 - 1) << 24) |
            ((31 - 1) << 16) |
            (480 - 1);
    // Set total vertical and horizontal lenghts
    REG32(VGA_HVLEN) = ((800 - 1) << 16) | (525 - 1);

    gfx_wait(2);
    REG32(GFX_TARGET_SIZE_X) = 640;
    REG32(GFX_TARGET_SIZE_Y) = 480;
}

void Set800x600_60(void)
{
    // Set horizontal timing register
    REG32(VGA_HTIM) = ((128 - 1) << 24) |
            ((88 - 1) << 16) |
            (800 - 1);
    // Set vertical timing register
    REG32(VGA_VTIM) = ((4 - 1) << 24) |
            ((23 - 1) << 16) |
            (600 - 1);
    // Set total vertical and horizontal lenghts
    REG32(VGA_HVLEN) = ((1056 - 1) << 16) | (628 - 1);

    gfx_wait(2);
    REG32(GFX_TARGET_SIZE_X) = 800;
    REG32(GFX_TARGET_SIZE_Y) = 600;
}

void Set1024x768_60(void)
{
    // Set horizontal timing register
    REG32(VGA_HTIM) = ((136 - 1) << 24) |
            ((160 - 1) << 16) |
            (1024 - 1);
    // Set vertical timing register
    REG32(VGA_VTIM) = ((6 - 1) << 24) |
            ((29 - 1) << 16) |
            (768 - 1);
    // Set total vertical and horizontal lenghts
    REG32(VGA_HVLEN) = ((1344 - 1) << 16) | (806 - 1);

    gfx_wait(2);
    REG32(GFX_TARGET_SIZE_X) = 1024;
    REG32(GFX_TARGET_SIZE_Y) = 768;
}
*/
void gfx_init(unsigned int memoryArea)
{
    memory_base = memoryArea;

    // Reset VGA+GFX first
//    REG32(VGA_CTRL) = 0;

    gfx_control_reg_memory = 0;
    gfx_wait(2);
    REG32(GFX_CONTROL) = gfx_control_reg_memory;

    gfx_vga_set_vbara(memory_base);
    gfx_vga_set_vbarb(memory_base);

    REG32(GFX_TARGET_BASE) = memory_base;
}

void gfx_vga_set_vbara(unsigned int addr)
{
    // Set base address for Video Base Register A
    REG32(FRAMEBUF_VBARA) = addr;
}

void gfx_vga_set_vbarb(unsigned int addr)
{
    // Set base address for Video Base Register B
    REG32(FRAMEBUF_VBARB) = addr;
}

void gfx_vga_bank_switch()
{
  gfx_wait(GFX_INSTRUCTION_FIFO_SIZE);
//    REG32(VGA_CTRL) = REG32(VGA_CTRL)|VGA_CTRL_VBSWE;
}

unsigned int gfx_vga_AVMP()
{
  // Get the active memory page bit
//  unsigned int status_reg = REG32(VGA_STAT);
//  status_reg = status_reg >> FRAMEBUF_STAT_AVMP;
//  return status_reg & 1;
}

/*
void set_color_depth(unsigned int dev, unsigned int comp)
{
  unsigned int vga_bpp = 0, gfx_bpp = 0;
  unsigned int r,g,b,p;
  
  r = comp << 8;
  g = comp << 4;
  b = comp;
  p = 0;
  switch(r+g+b)
  {
	case 6: p = 2 << 12; break;
	case 15: p = 1 << 12; break;
	case 30: p = 2 << 12; break;
  }
  
  comp = p|r|g|b;

	REG32(FRAMEBUF_COLOR_COMP) = comp;
  gfx_wait(1);
	REG32(GFX_COLOR_COMP) = comp;
}
*/
void gfx_vga_set_videomode(unsigned int width, unsigned int height, unsigned int cd)
{
/*
    if(width == 640 && height == 480)
        Set640x480_60();
    else if(width == 800 && height == 600)
        Set800x600_60();
    else if(width == 1024 && height == 768)
        Set1024x768_60();
    else // Default mode
        Set640x480_60();
*/
//    set_color_depth(7,cd);
}

struct gfx_surface gfx_init_surface(unsigned int width, unsigned int height)
{
  struct gfx_surface surface;
  surface.addr = memory_base;
  surface.w = width;
  surface.h = height;
  memory_base += (width << 1) * height; // TODO: Only true for 16 bit surfaces!
  return (surface);
}

void gfx_bind_rendertarget(struct gfx_surface *surface)
{
  target_surface = surface;
  gfx_wait(3);
  REG32(GFX_TARGET_BASE) = surface->addr;
  REG32(GFX_TARGET_SIZE_X) = surface->w;
  REG32(GFX_TARGET_SIZE_Y) = surface->h;
  // Clear clip rect
  gfx_cliprect(0,0,surface->w,surface->h);
}

void gfx_enable_zbuffer(unsigned int enable)
{
  if(enable)
    gfx_control_reg_memory |= GFX_ZBUFFER_ENABLE;
  else
    gfx_control_reg_memory &= ~GFX_ZBUFFER_ENABLE;

  gfx_wait(1);
  REG32(GFX_CONTROL) = gfx_control_reg_memory;
}

void gfx_bind_zbuffer(struct gfx_surface *surface)
{
  zbuffer_surface = surface;
  gfx_wait(1);
  REG32(GFX_ZBUFFER_BASE) = surface->addr;
}

void gfx_clear_zbuffer()
{
  int y, x;
  for(y = 0; y < zbuffer_surface->h; ++y)
  {
    for(x = 0; x < zbuffer_surface->w; x+=2)
    {
      int addr = (y*zbuffer_surface->w + x)*2; // TODO: only works for 16bits
      REG32(zbuffer_surface->addr+addr) = 0x00800080;//0x80008000;
    }
  }
}

void gfx_enable_cliprect(unsigned int enable)
{
  if(enable)
    gfx_control_reg_memory |= GFX_CLIPPING_ENABLE;
  else
    gfx_control_reg_memory &= ~GFX_CLIPPING_ENABLE;

  gfx_wait(1);
  REG32(GFX_CONTROL) = gfx_control_reg_memory;
}

void gfx_cliprect(unsigned int x0, unsigned int y0, unsigned int x1, unsigned int y1)
{
  gfx_wait(4);
  REG32(GFX_CLIP_PIXEL0_X) = x0;
  REG32(GFX_CLIP_PIXEL0_Y) = y0;
  REG32(GFX_CLIP_PIXEL1_X) = x1;
  REG32(GFX_CLIP_PIXEL1_Y) = y1;
}

void gfx_srcrect(unsigned int x0, unsigned int y0, unsigned int x1, unsigned int y1)
{
  gfx_wait(4);
  REG32(GFX_SRC_PIXEL0_X) = x0;
  REG32(GFX_SRC_PIXEL0_Y) = y0;
  REG32(GFX_SRC_PIXEL1_X) = x1;
  REG32(GFX_SRC_PIXEL1_Y) = y1;
}

void gfx_init_src()
{
  if((gfx_control_reg_memory & GFX_TEXTURE_ENABLE) && tex0_surface)
    gfx_srcrect(0, 0, tex0_surface->w, tex0_surface->h);
  else if(target_surface)
    gfx_srcrect(0, 0, target_surface->w, target_surface->h);
}

void gfx_set_pixel(int x, int y, unsigned int color)
{
  if(x >= 0 && y >= 0)
  {
    gfx_wait(5);
    REG32(GFX_COLOR0) = color;
    REG32(GFX_DEST_PIXEL_X) = x;
    REG32(GFX_DEST_PIXEL_Y) = y;
    REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT0 | transformation_mode;
    REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_POINT;
  }
}

// Copies a buffer into the current render target
void gfx_memcpy(unsigned int mem[], unsigned int size)
{
  unsigned int i;
  for(i=0; i < size; ++i)
    REG32(target_surface->addr+i*4) = mem[i];
}

void gfx_set_color(unsigned int color)
{
  gfx_wait(1);
  REG32(GFX_COLOR0) = color;
}


void gfx_set_colors(unsigned int color0, unsigned int color1, unsigned int color2)
{
  gfx_wait(3);
  REG32(GFX_COLOR0) = color0;
  REG32(GFX_COLOR1) = color1;
  REG32(GFX_COLOR2) = color2;
}

void gfx_rect(int x0, int y0, int x1, int y1)
{
  gfx_wait(7);
  REG32(GFX_DEST_PIXEL_X) = x0;
  REG32(GFX_DEST_PIXEL_Y) = y0;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT0 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x1;
  REG32(GFX_DEST_PIXEL_Y) = y1;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT1 | transformation_mode;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_RECT;
}

void gfx_line(int x0, int y0, int x1, int y1)
{
  gfx_line3d(x0, y0, 0, x1, y1, 0);
}

void gfx_triangle(int x0, int y0, int x1, int y1, int x2, int y2, unsigned int interpolate)
{
  gfx_triangle3d(x0, y0, 0, x1, y1, 0, x2, y2, 0, interpolate);
}

void gfx_curve(int x0, int y0, int x1, int y1, int x2, int y2, unsigned int inside)
{
  gfx_wait(14);
  REG32(GFX_DEST_PIXEL_Z) = 0; // Set all points depth value to zero

  REG32(GFX_DEST_PIXEL_X) = x0;
  REG32(GFX_DEST_PIXEL_Y) = y0;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT0 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x1;
  REG32(GFX_DEST_PIXEL_Y) = y1;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT1 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x2;
  REG32(GFX_DEST_PIXEL_Y) = y2;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT2 | transformation_mode;

  if(inside)
    gfx_control_reg_memory |= GFX_INSIDE;
  else
    gfx_control_reg_memory &= ~GFX_INSIDE;

  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_CURVE | GFX_TRI | GFX_INTERP;
}

void gfx_triangle3d(int x0, int y0, int z0,
                       int x1, int y1, int z1,
                       int x2, int y2, int z2,
                       unsigned int interpolate)
{
  gfx_wait(13);
  REG32(GFX_DEST_PIXEL_X) = x0;
  REG32(GFX_DEST_PIXEL_Y) = y0;
  REG32(GFX_DEST_PIXEL_Z) = z0;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT0 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x1;
  REG32(GFX_DEST_PIXEL_Y) = y1;
  REG32(GFX_DEST_PIXEL_Z) = z1;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT1 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x2;
  REG32(GFX_DEST_PIXEL_Y) = y2;
  REG32(GFX_DEST_PIXEL_Z) = z2;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT2 | transformation_mode;

  if(interpolate)
    REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_TRI | GFX_INTERP;
  else
    REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_TRI;
}

void gfx_line3d(int x0, int y0, int z0, int x1, int y1, int z1)
{
  gfx_wait(9);
  REG32(GFX_DEST_PIXEL_X) = x0;
  REG32(GFX_DEST_PIXEL_Y) = y0;
  REG32(GFX_DEST_PIXEL_Z) = z0;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT0 | transformation_mode;
  REG32(GFX_DEST_PIXEL_X) = x1;
  REG32(GFX_DEST_PIXEL_Y) = y1;
  REG32(GFX_DEST_PIXEL_Z) = z1;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_ACTIVE_POINT1 | transformation_mode;
  REG32(GFX_CONTROL) = gfx_control_reg_memory | GFX_LINE;
}

void gfx_uv(unsigned int u0, unsigned int v0,
               unsigned int u1, unsigned int v1,
               unsigned int u2, unsigned int v2)
{
  gfx_wait(6);
  REG32(GFX_U0) = u0;
  REG32(GFX_V0) = v0;
  REG32(GFX_U1) = u1;
  REG32(GFX_V1) = v1;
  REG32(GFX_U2) = u2;
  REG32(GFX_V2) = v2;
}

void gfx_enable_tex0(unsigned int enable)
{
  gfx_wait(1);
  if(enable)
  {
    gfx_control_reg_memory   |= GFX_TEXTURE_ENABLE;
    REG32(GFX_CONTROL) = gfx_control_reg_memory;
  }
  else
  {
    gfx_control_reg_memory &= ~GFX_TEXTURE_ENABLE;
    REG32(GFX_CONTROL) = gfx_control_reg_memory;
  }
  gfx_init_src();
}

void gfx_bind_tex0(struct gfx_surface* surface)
{
  gfx_wait(3);
  tex0_surface = surface;
  REG32(GFX_TEX0_BASE) = surface->addr;
  REG32(GFX_TEX0_SIZE_X) = surface->w;
  REG32(GFX_TEX0_SIZE_Y) = surface->h;
  gfx_init_src();
}

void gfx_enable_alpha(unsigned int enable)
{
  gfx_wait(1);
  if(enable)
    gfx_control_reg_memory |= GFX_BLEND_ENABLE;
  else
    gfx_control_reg_memory &= ~GFX_BLEND_ENABLE;

  REG32(GFX_CONTROL) = gfx_control_reg_memory;
}

void gfx_set_alpha(unsigned int alpha)
{
  gfx_wait(1);
  REG32(GFX_ALPHA) = alpha;
}

void gfx_enable_colorkey(unsigned int enable)
{
  gfx_wait(1);
  if(enable)
    gfx_control_reg_memory |= GFX_COLORKEY_ENABLE;
	else
    gfx_control_reg_memory &= ~GFX_COLORKEY_ENABLE;

  REG32(GFX_CONTROL) = gfx_control_reg_memory;
}

void gfx_set_colorkey(unsigned int colorkey)
{
  gfx_wait(1);
  REG32(GFX_COLORKEY) = colorkey;
}

void gfx_enable_transform(unsigned int enable)
{
  if(enable)
    transformation_mode = GFX_TRANSFORM_POINT;
  else
    transformation_mode = GFX_FORWARD_POINT;
}

void gfx_set_transformation_matrix(int aa, int ab, int ac, int tx,
                                      int ba, int bb, int bc, int ty,
                                      int ca, int cb, int cc, int tz)
{
  gfx_wait(12);
  REG32(GFX_AA) = aa;
  REG32(GFX_AB) = ab;
  REG32(GFX_AC) = ac;
  REG32(GFX_TX) = tx;
  REG32(GFX_BA) = ba;
  REG32(GFX_BB) = bb;
  REG32(GFX_BC) = bc;
  REG32(GFX_TY) = ty;
  REG32(GFX_CA) = ca;
  REG32(GFX_CB) = cb;
  REG32(GFX_CC) = cc;
  REG32(GFX_TZ) = tz;
}

