#ifndef _OVS_GAYA_
#define _OVS_GAYA_


char *get_gaya_folder();
void set_gaya_folder(char *folder);
int get_gaya_page();
void set_gaya_page(int page);
char *get_gaya_filter();
void show_page(char *folder,char *filter,int page);
char *gaya_image(char *image);
Array *gaya_get_files();

#endif
