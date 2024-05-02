#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>'

#define pr_fmt(fmt) "Rissu: " fmt

MODULE_LICENSE("GPL");
MODULE_AUTHOR("rsuntk");
MODULE_DESCRIPTION("Rissu Kernel Sign");

static void processor_type(void)
{
#ifdef CONFIG_ARCH_SPRD
    pr_info("chipset is unisoc/sprd");
#elif CONFIG_ARCH_MEDIATEK
    pr_info("chipset is mediatek/mtk");
#elif CONFIG_ARCH_EXYNOS
    pr_info("chipset is exynos");
#elif CONFIG_ARCH_QCOM
    pr_info("chipset is qcom/msm");
#else
    pr_info("unknown chipset!");
#endif
}

static void check_rissu_patches(void)
{
#ifdef CONFIG_RISSU_SYSFS_PATCH
    pr_info("CONFIG_RISSU_SYSFS_PATCH: true!");
    pr_info("set rq_affinity flags to 2");
#endif

#ifdef CONFIG_RISSU_SPRD_OC
    pr_info("CONFIG_RISSU_SPRD_OC: true!");
    pr_info("gpu: set hz to 61000 kHz! idk is this right.");
    pr_info("cpu: unisoc overclocking is not possible. for now.");
#endif

#ifdef CONFIG_RISSU_FORCE_LZ4
    pr_info("CONFIG_RISSU_FORCE_LZ4: true!");
    pr_info("zram: force lz4 for zram compression.");
#endif
}
static int __init rissu_init(void)
{
    processor_type();
    check_rissu_patches();
    return 0;
}

static void __exit rissu_exit(void)
{
    pr_info("kernel module success, exit!");
}

module_init(rissu_init);
module_exit(rissu_exit);
