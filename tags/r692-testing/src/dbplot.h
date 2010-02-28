#ifndef __OVS_DB_PLOT_H__
#define __OVS_DB_PLOT_H__

#define PLOT_POSITION_UNSET -1
char *get_plot(DbRowId *rid,PlotType ptype);
void get_plot_offsets_and_text(int num_rows,DbRowId **rows,int copy_plot_text);

#endif
