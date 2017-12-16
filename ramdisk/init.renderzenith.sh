#!/system/bin/sh

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}

# macro to write pids to system-background cpuset
function writepid_sbg() {
    if [ ! -z "$1" ]
        then
            echo -n $1 > /dev/cpuset/system-background/tasks
    fi
}

function writepid_top_app() {
    if [ ! -z "$1" ]
        then
            echo -n $1 > /dev/cpuset/top-app/tasks
    fi
}
################################################################################

sleep 10

target=`getprop ro.board.platform`

case "$target" in
	"msm8996")
		# disable thermal bcl hotplug to switch governor
		echo 0 > /sys/module/msm_thermal/core_control/enabled
		echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode
		bcl_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_mask`
		echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_mask
		bcl_soc_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask`
		echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask
		echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode

		# Enable Adaptive LMK
		echo 1 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
		echo "18432,23040,27648,51256,150296,200640" > /sys/module/lowmemorykiller/parameters/minfree
		echo 202640 > /sys/module/lowmemorykiller/parameters/vmpressure_file_min

		# configure governor settings for little cluster
		echo "sched" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

		# online CPU2
		echo 1 > /sys/devices/system/cpu/cpu2/online

		# configure governor settings for big cluster
		echo "sched" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor

		# re-enable thermal and BCL hotplug
		echo 1 > /sys/module/msm_thermal/core_control/enabled
		echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode
		echo $bcl_hotplug_mask > /sys/devices/soc/soc:qcom,bcl/hotplug_mask
		echo $bcl_soc_hotplug_mask > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask
		echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode

		# Enable bus-dcvs
		for cpubw in /sys/class/devfreq/*qcom,cpubw*
		do
			echo "bw_hwmon" > $cpubw/governor
			echo 50 > $cpubw/polling_interval
			echo 1525 > $cpubw/min_freq
			echo "1525 5195 11863 13763" > $cpubw/bw_hwmon/mbps_zones
			echo 4 > $cpubw/bw_hwmon/sample_ms
			echo 34 > $cpubw/bw_hwmon/io_percent
			echo 20 > $cpubw/bw_hwmon/hist_memory
			echo 10 > $cpubw/bw_hwmon/hyst_length
			echo 0 > $cpubw/bw_hwmon/low_power_ceil_mbps
			echo 34 > $cpubw/bw_hwmon/low_power_io_percent
			echo 20 > $cpubw/bw_hwmon/low_power_delay
			echo 0 > $cpubw/bw_hwmon/guard_band_mbps
			echo 250 > $cpubw/bw_hwmon/up_scale
			echo 1600 > $cpubw/bw_hwmon/idle_mbps
		done

		for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
		do
			echo "mem_latency" > $memlat/governor
			echo 10 > $memlat/polling_interval
		done
		echo "cpufreq" > /sys/class/devfreq/soc:qcom,mincpubw/governor

	soc_revision=`cat /sys/devices/soc0/revision`
	if [ "$soc_revision" == "2.0" ]; then
		#Disable suspend for v2.0
		echo pwr_dbg > /sys/power/wake_lock
	elif [ "$soc_revision" == "2.1" ]; then
		# Enable C4.D4.E4.M3 LPM modes
		# Disable D3 state
		echo 0 > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled
		echo 0 > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled
		# Disable DEF-FPC mode
		echo N > /sys/module/lpm_levels/system/pwr/cpu0/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/pwr/cpu1/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/perf/cpu2/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/perf/cpu3/fpc-def/idle_enabled
	else
		# Enable all LPMs by default
		# This will enable C4, D4, D3, E4 and M3 LPMs
		echo N > /sys/module/lpm_levels/parameters/sleep_disabled
	fi
	echo N > /sys/module/lpm_levels/parameters/sleep_disabled
		# Starting io prefetcher service
		start iop

	if [ -f "/defrag_aging.ko" ]; then
		insmod /defrag_aging.ko
	else
		insmod /system/lib/modules/defrag.ko
	fi
	sleep 1
	lsmod | grep defrag
	if [ $? != 0 ]; then
		echo 1 > /sys/module/defrag_helper/parameters/disable
	fi
	;;
esac

setprop sys.post_boot.parsed 1
