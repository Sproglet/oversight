#ifndef _OVS_GAYA_
#define _OVS_GAYA_


char *get_gaya_folder();
char *get_gaya_short_folder();
void set_gaya_folder(char *folder);
int get_gaya_page();
void set_gaya_page(int page);
char *get_gaya_filter();
void show_page(char *folder,char *filter,int page);
char *gaya_image(char *image);
Array *gaya_get_files();
void gaya_list(char *arg);
char *gaya_get_file_image(char *name);
int gaya_file_total();
int gaya_first_file();
int gaya_last_file();
int gaya_prev_file();
int gaya_next_page();
int gaya_prev_page();
char *gaya_filter_name(char filter_char);
int is_video(char *name);
int is_audio(char *name);
int is_image(char *name);
int is_other(char *name);
int is_visible(char filter,char *name);

void gaya_set_env(int argc,char **argv);
char *gaya_url(int argc,char **argv);
int gaya_file_browsing(int argc,char **argv);
int gaya_sent_post_data(int argc,char **argv);
char *gaya_sent_oversight_url(int argc,char **argv);
int gaya_set_output(int argc,char **argv);
void gaya_set_env(int argc,char **argv);
#endif
