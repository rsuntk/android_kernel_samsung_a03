#ifndef __RISSU_H
#define __RISSU_H

#include <linux/printk.h>

#ifdef pr_fmt
#undef pr_fmt
#define pr_fmt(fmt) "Rissu: " fmt
#endif

#endif
