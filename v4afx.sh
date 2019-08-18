#!/system/bin/sh
(until [ $(getprop sys.boot_completed) -eq 1 ]; do
  sleep 5
done
am start -a android.intent.action.MAIN -n com.pittvandewitt.viperfx/com.audlabs.viperfx.main.MainActivity
until [ "$(pidof com.pittvandewitt.viperfx)" ]; do
  sleep 3
done
killall com.pittvandewitt.viperfx
killall audioserver
killall mediaserver)&
