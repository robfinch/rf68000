/* GFX defines */
#define GFX_BASEADDR   0xFD300000 /* Bus Adress to GFX  */

// Declarations of register addresses:
#define GFX_CONTROL        (GFX_BASEADDR + 0x100) /* Control Register */
#define GFX_STATUS         (GFX_BASEADDR + 0x104) /* Status Register */
#define GFX_ALPHA          (GFX_BASEADDR + 0x108) /* Alpha channel Register */
#define GFX_COLORKEY       (GFX_BASEADDR + 0x10c) /* Colorkey Register */

#define GFX_TARGET_BASE    (GFX_BASEADDR + 0x110) /* Offset to "Target" framebuffer */
#define GFX_TARGET_SIZE_X  (GFX_BASEADDR + 0x114) /* Target Width */
#define GFX_TARGET_SIZE_Y  (GFX_BASEADDR + 0x118) /* Target Height */

#define GFX_TEX0_BASE      (GFX_BASEADDR + 0x11c) /* Offset to texturebuffer */
#define GFX_TEX0_SIZE_X    (GFX_BASEADDR + 0x120) /* Texturebuffer Width */
#define GFX_TEX0_SIZE_Y    (GFX_BASEADDR + 0x124) /* Texturebuffer Height*/

#define GFX_SRC_PIXEL0_X   (GFX_BASEADDR + 0x128) /* source rect spanned by pixel0 and pixel1, ex a position in a image */
#define GFX_SRC_PIXEL0_Y   (GFX_BASEADDR + 0x12c) /*   0******   */
#define GFX_SRC_PIXEL1_X   (GFX_BASEADDR + 0x130) /*   *******   */
#define GFX_SRC_PIXEL1_Y   (GFX_BASEADDR + 0x134) /*   ******1   */

#define GFX_DEST_PIXEL_X   (GFX_BASEADDR + 0x138) /* Destination pixels, used to draw Rects,Lines,Curves or Triangles */
#define GFX_DEST_PIXEL_Y   (GFX_BASEADDR + 0x13c)
#define GFX_DEST_PIXEL_Z   (GFX_BASEADDR + 0x140)

#define GFX_AA             (GFX_BASEADDR + 0x144)
#define GFX_AB             (GFX_BASEADDR + 0x148)
#define GFX_AC             (GFX_BASEADDR + 0x14c)
#define GFX_TX             (GFX_BASEADDR + 0x150)
#define GFX_BA             (GFX_BASEADDR + 0x154)
#define GFX_BB             (GFX_BASEADDR + 0x158)
#define GFX_BC             (GFX_BASEADDR + 0x15c)
#define GFX_TY             (GFX_BASEADDR + 0x160)
#define GFX_CA             (GFX_BASEADDR + 0x164)
#define GFX_CB             (GFX_BASEADDR + 0x168)
#define GFX_CC             (GFX_BASEADDR + 0x16c)
#define GFX_TZ             (GFX_BASEADDR + 0x170)

#define GFX_CLIP_PIXEL0_X  (GFX_BASEADDR + 0x174) /* Clip Rect registers, only pixels inside the clip rect */
#define GFX_CLIP_PIXEL0_Y  (GFX_BASEADDR + 0x178) /* will be drawn on the screen when clipping is enabled. */
#define GFX_CLIP_PIXEL1_X  (GFX_BASEADDR + 0x17c)
#define GFX_CLIP_PIXEL1_Y  (GFX_BASEADDR + 0x180)

#define GFX_COLOR0         (GFX_BASEADDR + 0x184) /* Color registers, Color0 is mostly used.    */
#define GFX_COLOR1         (GFX_BASEADDR + 0x188) /* Color 1 & 2 is only used in interpolation  */
#define GFX_COLOR2         (GFX_BASEADDR + 0x18c) /* ex. triangle, one color from each corner   */

#define GFX_U0             (GFX_BASEADDR + 0x190)
#define GFX_V0             (GFX_BASEADDR + 0x194)
#define GFX_U1             (GFX_BASEADDR + 0x198)
#define GFX_V1             (GFX_BASEADDR + 0x19c)
#define GFX_U2             (GFX_BASEADDR + 0x1a0)
#define GFX_V2             (GFX_BASEADDR + 0x1a4)

#define GFX_ZBUFFER_BASE   (GFX_BASEADDR + 0x1a8)

#define GFX_TARGET_X0			 (GFX_BASEADDR + 0x1b0)
#define GFX_TARGET_Y0			(GFX_BASEADDR + 0x1b4)
#define GFX_TARGET_X1			 (GFX_BASEADDR + 0x1b8)
#define GFX_TARGET_Y1			 (GFX_BASEADDR + 0x1bc)
#define GFX_FONT_TABLE_BASE	(GFX_BASEADDR + 0x1c0)
#define GFX_FONT_ID				 	(GFX_BASEADDR + 0x1c8)
#define GFX_CHAR_CODE			 (GFX_BASEADDR + 0x1cc)
#define GFX_COLOR_COMP		 (GFX_BASEADDR + 0x1d0)
#define GFX_PPS						 (GFX_BASEADDR + 0x1d4)

/* ===================== */
/* Control register bits */
/* ===================== */
//#define GFX_CTRL_COLOR_DEPTH     0
#define GFX_CTRL_TEXTURE         2
#define GFX_CTRL_BLENDING        3
#define GFX_CTRL_COLORKEY        4
#define GFX_CTRL_CLIPPING        5
#define GFX_CTRL_ZBUFFER         6

#define GFX_CTRL_POINT					 7
#define GFX_CTRL_RECT            8
#define GFX_CTRL_LINE            9
#define GFX_CTRL_TRI             10
#define GFX_CTRL_CURVE           11
#define GFX_CTRL_INTERP          12
#define GFX_CTRL_INSIDE          13

#define GFX_CTRL_ACTIVE_POINT    16
#define GFX_CTRL_FORWARD_POINT   18
#define GFX_CTRL_TRANSFORM_POINT 19

#define GFX_CTRL_CHAR						20
#define GFX_CTRL_FLOODFILL			 21

/* ==================== */
/* Status register bits */
/* ==================== */
#define GFX_STAT_BUSY            0

