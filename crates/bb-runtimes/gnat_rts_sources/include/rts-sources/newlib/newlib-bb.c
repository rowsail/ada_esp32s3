/****************************************************************************
 *                                                                          *
 *               GNU ADA RUN-TIME LIBRARY (GNARL) COMPONENTS                *
 *                                                                          *
 *                          C Implementation File                           *
 *                                                                          *
 *                    Copyright (C) 2016-2025, AdaCore                      *
 *                                                                          *
 * GNAT is free software;  you can  redistribute it  and/or modify it under *
 * terms of the  GNU General Public License as published  by the Free Soft- *
 * ware  Foundation;  either version 2,  or (at your option) any later ver- *
 * sion.  GNAT is distributed in the hope that it will be useful, but WITH- *
 * OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY *
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License *
 * for  more details.  You should have  received  a copy of the GNU General *
 * Public License  distributed with GNAT;  see file COPYING.  If not, write *
 * to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, *
 * MA 02111-1307, USA.                                                      *
 *                                                                          *
 * As a  special  exception,  if you  link  this file  with other  files to *
 * produce an executable,  this file does not by itself cause the resulting *
 * executable to be covered by the GNU General Public License. This except- *
 * ion does not  however invalidate  any other reasons  why the  executable *
 * file might be covered by the  GNU Public License.                        *
 *                                                                          *
 * GNARL was developed by the GNARL team at Florida State University.       *
 * Extensive contributions were provided by Ada Core Technologies, Inc.     *
 * The  executive  was developed  by the  Real-Time  Systems  Group  at the *
 * Technical University of Madrid.                                          *
 *                                                                          *
 ****************************************************************************/

#include <errno.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/stat.h>

#ifdef __CHERI_PURE_CAPABILITY__
#include <cheriintrin.h>
#endif

/* Subprograms from System.Text_IO.  */
extern char system__text_io__initialized;
extern void system__text_io__initialize (void);
extern char system__text_io__is_tx_ready (void);
extern char system__text_io__is_rx_ready (void);
extern char system__text_io__use_cr_lf_for_new_line (void);
extern void system__text_io__put (char);
extern char system__text_io__get (void);

/* Assume that all fd are a tty.  */
int
isatty (int fd)
{
  return 1;
}

static void
write_console (char c)
{
  while (!system__text_io__is_tx_ready ())
    ;
  system__text_io__put (c);
}

static char
read_console (void)
{
  while (!system__text_io__is_rx_ready ())
    ;
  return system__text_io__get ();
}

int
_write (int fd, char *buf, int nbytes)
{
  int i;

  if (!system__text_io__initialized)
    system__text_io__initialize ();

  for (i = 0; i < nbytes; i++)
    {
      char c = buf[i];

      if (c == '\n' && system__text_io__use_cr_lf_for_new_line ())
	write_console ('\r');
      write_console (c);
    }

  return nbytes;
}

int
_close (int fd)
{
  return 0;
}

int
_fstat (int fd, struct stat*buf)
{
  return -1;
}

off_t
_lseek (int fd, off_t offset, int whence)
{
  errno = ESPIPE;
  return -1;
}

int
_read (int fd, char *buf, int count)
{
  int i;

  if (!system__text_io__initialized)
    system__text_io__initialize ();

  for (i = 0; i < count;)
    {
      char c = read_console ();

      if (c == '\r' && system__text_io__use_cr_lf_for_new_line ())
	continue;
      buf[i++] = c;
      if (c == '\n')
	break;
    }
  return i;
}

/* __heap_start and __heap_end are defined in the commands script for the
   linker. They define the space of RAM that has not been allocated
   for code or data. */

extern char __heap_start;
extern char __heap_end;

#if defined(__CHERI_PURE_CAPABILITY__)
static void *heap_ptr;
static void *heap_end;

void __gnat_heap_init(void)
{
  void *base    = &__heap_start;
  void *limit   = &__heap_end;
  size_t length = (base <= limit
                     ? (size_t)(limit - base)
                     : 0);

  /* Align the bounds to ensure the capability will be representable, taking
     care to avoid exceeding __heap_start and __heap_end */

  size_t rrmask     = cheri_representable_alignment_mask(length);
  size_t rrmask_inv = (size_t)~rrmask;

  base     = (void*)(((uintptr_t)base + rrmask_inv) & rrmask); /* round up */
  limit    = (void*)((uintptr_t)limit & rrmask);               /* round down */
  length   = (size_t)(limit - base);
  heap_end = limit;

  /* Create the heap capability from the DDC, without execute permissions */

  heap_ptr = cheri_address_set(cheri_ddc_get(), cheri_address_get(base));
  heap_ptr = cheri_bounds_set_exact(heap_ptr, length);
  heap_ptr = cheri_perms_and(heap_ptr, (size_t)~CHERI_PERM_EXECUTE);
}
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
static void *heap_ptr = &__heap_start;
static void *const heap_end = &__heap_end;
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

void *
_sbrk (int nbytes)
{
  void *base;

  if ((ptrdiff_t)(heap_end - heap_ptr) >= nbytes)
    {
      base = heap_ptr;
      heap_ptr += nbytes;
      return base;
    }
  else
    {
      return (void *)-1;
    }
}
