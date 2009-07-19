/* Like vsprintf but provides a pointer to malloc'd storage, which must
   be freed by the caller.
   Copyright (C) 1994 Free Software Foundation, Inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

#include "vasprintf.h"

int ovs_vasprintf (char **result, char *format, va_list args) {
  char *p = format;
  /* Add one to make sure that it is never zero, which might cause malloc
     to return NULL.  */
  int total_width = strlen (format) + 1;
  va_list ap = args;

  while (*p != '\0')
    {
      if (*p++ == '%')
        {
          while (strchr ("-+ #0", *p))
            ++p;
          if (*p == '*')
            {
              ++p;
              total_width += abs(va_arg (ap, int));
            }
          else
            total_width += strtoul (p, &p, 10);
          if (*p == '.')
            {
              ++p;
              if (*p == '*')
                {
                  ++p;
                  total_width += abs (va_arg (ap, int));
                }
              else
                total_width += strtoul (p, &p, 10);
            }
          while (strchr ("hlL", *p))
            ++p;
          /* Should be big enough for any format specifier except %s.  */
          total_width += 30;
          switch (*p)
            {
            case 'd':
            case 'i':
            case 'o':
            case 'u':
            case 'x':
            case 'X':
            case 'c':
              (void) va_arg (ap, int);
              break;
            case 'f':
            case 'e':
            case 'E':
            case 'g':
            case 'G':
              (void) va_arg (ap, double);
              break;
            case 's':
              total_width += strlen (va_arg (ap, char *));
              break;
            case 'p':
            case 'n':
              (void) va_arg (ap, char *);
              break;
            }
        }
    }
  *result = malloc (total_width);
  if (*result != NULL)
    return vsprintf (*result, format, args);
  else
    return 0;
}

int ovs_asprintf (char **result, char *format, ...)
{
  va_list args;
  int done;

  va_start (args, format);
  done = ovs_vasprintf (result, format, args);
  va_end (args);

  return done;
} 
