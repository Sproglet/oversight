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
  int vdbg = util_starts_with(format,"vdbg:");

  if (vdbg) {
      printf("<!--  ovs_vasprintf start(%d) -->\n",total_width);
      printf("<!--  ovs_vasprintf format(%s) -->\n",format);
      fflush(stdout);
  }
  va_list ap;

  memcpy(&ap,&args,sizeof(va_list));

  while (*p != '\0') {

      if (*p == '%') {

          p++;

          if (*p == '%') {

              p++;

          } else {
              char type_size = '\0';

              while (strchr ("-+ #0", *p)) {
                ++p;
              }

              if (*p == '*') {

                  ++p;
                  total_width += abs(va_arg (ap, int));

                } else {
                    total_width += strtoul (p, &p, 10);
              }

              if (*p == '.') {
                  ++p;
                  if (*p == '*')
                    {
                      ++p;
                      total_width += abs (va_arg (ap, int));
                    }
                  else
                    total_width += strtoul (p, &p, 10);
              }

              switch(*p) {
                  case 'h' :
                  case 'l' :
                  case 'L' :
                      type_size=*p;
                      p++;

              }

              /* Should be big enough for any format specifier except %s.  */
              total_width += 30;
                //printf("<!-- %c%c -->",type_size,*p); fflush(stdout);
              switch (*p) {

                case 'd':
                case 'i':
                case 'o':
                case 'u':
                case 'x':
                case 'X':

                    switch(type_size) {

                    case 'h':

                        {
                            unsigned short tmp = va_arg(ap, int );
                            if (vdbg){ printf("<!-- ovs_vasprintf  short-%c(%hd) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    case 'l':

                        {
                            long tmp = va_arg(ap, long );
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%ld) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    case '\0':
                        {
                            int tmp = va_arg(ap, int );
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%d) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;
                    default:
                        printf("bad type\n");fflush(stdout);
                        assert(0);
                    }

                  break;
                case 'c':


                    switch(type_size) {

                    case 'l':

                        {
                            printf("no whcar\n");fflush(stdout);
                            assert(0); //not implemented - no wchar header in cross compile
                        }
                        break;

                    case '\0':

                        {
                            char tmp = va_arg(ap, int );
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%c) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    default:
                        printf("bad type\n");fflush(stdout);
                        assert(0);
                    }
                    break;


                case 'f':
                case 'e':
                case 'E':
                case 'g':
                case 'G':

                    switch(type_size) {

                    case 'l':

                        {
                            double tmp = va_arg(ap, double );
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%lf) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    case 'L':

                        {
                            long double tmp = va_arg(ap, long  double);
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%Lf) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    case '\0':

                        {
                            float tmp = va_arg(ap, double );
                            if (vdbg){ printf("<!-- ovs_vasprintf  int-%c(%f) -->\n",*p,tmp); fflush(stdout); }
                        }
                        break;

                    default:
                        printf("bad type\n");fflush(stdout);
                        assert(0);
                    }
                    break;

                case 's':
                  {
                      char *ss=va_arg (ap, char *);
                      if (ss) {
                          if (vdbg) {
                              printf("<!-- ovs_vasprintf %%s ptr(%ld) -->\n",(long)ss);
                              fflush(stdout);
                          }
                          int len = strlen(ss);
                          if (vdbg) {
                              printf("<!-- ovs_vasprintf %%s(%d) -->\n",len);
                              fflush(stdout);
                          }
                          total_width += len;
                      } else {
                          total_width += 6; /* "(null)" */
                          if (vdbg) {
                              printf("<!-- ovs_vasprintf %%s(null) -->\n");
                              fflush(stdout);
                          }
                      }
                  }
                  break;
                case 'p':
                case 'n':
                  (void) va_arg (ap, char *);
                  break;
                }
            }
        } else {
            p++;
        }
    }

  if (vdbg) {
      printf("<!--  ovs_vasprintf total(%d) -->\n",total_width);
      fflush(stdout);
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
