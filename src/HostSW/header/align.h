#ifndef __ALIGN_H_INCLUDED
#define __ALIGN_H_INCLUDED

/**
 * Map base characters to two-digit bit strings.
 * This mapping is computed branch-free and is not case sensitive.
 * The mapping of other characters are undefined.
 *
 *        | OLD  NEW
 *  ------+----------
 *   0:00 |  A    A
 *   1:01 |  G    C
 *   2:10 | T/U  T/U
 *   3:11 |  C    G
 *
 * The operation of the hardware is not sensitive to the chosen 
 * mapping as long as it is bijective.
 */
/* Original OLD Mapping */
/*#define PACK_BASE(c) ((((c)>>1)^((c)&2))&3)*/
/* Simplified NEW Mapping */
#define PACK_BASE(c) (((c)>>1)&3)

#endif
