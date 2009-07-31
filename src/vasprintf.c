/* Like vsprintf but provides a pointer to MALLOC'd storage, which must
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
#include <assert.h>

#include "vasprintf.h"
#include "util.h" //for MALLOC

#define TEST
#ifdef TEST
int ovs_vasprintf (char **result, char *format, va_list args) {
  char *p = format;
  /* Add one to make sure that it is never zero, which might cause MALLOC
     to return NULL.  */
  int total_width = strlen (format) + 1;

  va_list ap;

  memcpy(&ap,&args,sizeof(va_list));

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
              { char *ss=va_arg (ap, char *);
                  if (ss) {
                      total_width += strlen (ss);
                  } else {
                      total_width += 6; /* "(null)" */
                  }
              }
              break;
            case 'p':
            case 'n':
              (void) va_arg (ap, char *);
              break;
            }
        }
    }
  *result = MALLOC (total_width);
  if (*result != NULL)
    return vsprintf (*result, format, args);
  else
    return 0;
}
#else
int ovs_vasprintf (char **result, char *format, va_list args) {
#define BUFLEN 300
    char buf[BUFLEN];
    int result_len;

    vsnprintf(buf,BUFLEN,format,args);
    buf[BUFLEN]='\0';

    result_len = strlen(buf);
    *result=strdup(buf);
    return result_len;
}
#endif

int ovs_asprintf (char **result, char *format, ...)
{
  va_list args;
  int done;

  assert(result);

  va_start (args, format);
  done = ovs_vasprintf (result, format, args);
  assert(*result);
  va_end (args);

  return done;
} 
