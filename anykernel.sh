# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=ViPER4AndroidFX 2.7.x Rootless Installer
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=auto;
is_slot_device=auto;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
# chmod -R 750 $ramdisk/*;
# chown -R root:root $ramdisk/*;


## AnyKernel install
device_check() {
  local PROP=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for i in "ro.product.device" "ro.build.product"; do
    [ "$(sed -n "s/^$i=//p" /system/build.prop 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$PROP" -o "$(sed -n "s/^$i=//p" $VEN/build.prop 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$PROP" ] && return 0
  done
  return 1
}
manufacturer_check() {
  local PROP=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  [ "$(sed -n "s/^ro.product.manufacturer=//p" /system/build.prop 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$PROP" -o "$(sed -n "s/^ro.product.manufacturer=//p" $VEN/build.prop 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$PROP" ] && return 0
  return 1
}

[ -L /system/vendor ] && VEN=/vendor || VEN=/system/vendor
API=`file_getprop /system/build.prop ro.build.version.sdk`
[ $API -ge 26 ] && { LIBPATCH="\/vendor"; LIBDIR=$VEN; } || { LIBPATCH="\/system"; LIBDIR=system; }
[ -f /system_root/sepolicy ] && SEPOL=/system_root/sepolicy || SEPOL=sepolicy

ui_print "- Unpacking boot img..."
split_boot;

# Apply sepolicy patches
ui_print "- Patching sepolicy..."
[ "$SEPOL" == "sepolicy" ] && $bin/magiskboot cpio $split_img/ramdisk.cpio "extract sepolicy sepolicy"
$bin/magiskpolicy --load $SEPOL --save $SEPOL "allow { audioserver mediaserver } { audioserver_tmpfs mediaserver_tmpfs } file { read write execute }" "allow { audioserver mediaserver } system_file file execmod" "allow audioserver unlabeled file { read write execute open getattr }" "allow hal_audio_default hal_audio_default process execmem" "allow hal_audio_default hal_audio_default_tmpfs file execute" "allow hal_audio_default audio_data_file dir search" "allow mtk_hal_audio mtk_hal_audio_tmpfs file execute" "allow app app_data_file file execute_no_trans" "permissive shell"
[ "$SEPOL" == "sepolicy" ] && $bin/magiskboot cpio $split_img/ramdisk.cpio "add 0644 sepolicy sepolicy"
cp -f $home/init.v4afx.rc /system/etc/init/init.v4afx.rc
cp -f $home/v4afx.sh /system/bin/v4afx.sh
chmod 0755 /system/bin/v4afx.sh


ui_print "- Installing driver..."
cp -f $bin/libv4a_fx.so $LIBDIR/lib/soundfx/libv4a_fx.so

#Patch files
ui_print "- Patching files..."
if ((manufacturer_check "google" || manufacturer_check "Essential Products") && ! device_check "sailfish" && ! device_check "marlin") || [ $API -ge 28 ]; then
  [ -f /system/lib/libstdc++.so ] && [ ! -f $VEN/lib/libstdc++.so ] && cp -f /system/lib/libstdc++.so $VEN/lib/libstdc++.so
fi

find -L /system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" | while read FILE; do
  sed -i "/v4a_standard_fx {/,/}/d" $FILE
  sed -i "/v4a_fx {/,/}/d" $FILE
  sed -i "/v4a_standard_fx/d" $FILE
  sed -i "/v4a_fx/d" $FILE
  sed -i "s/^effects {/effects {\n  v4a_standard_fx {\n    library v4a_fx\n    uuid 41d3c987-e6cf-11e3-a88a-11aba5d5c51b\n  }/g" $FILE
  sed -i "s/^libraries {/libraries {\n  v4a_fx {\n    path $LIBPATCH\/lib\/soundfx\/libv4a_fx.so\n  }/g" $FILE
  sed -i "/<libraries>/ a\        <library name=\"v4a_fx\" path=\"libv4a_fx.so\"\/>" $FILE
  sed -i "/<effects>/ a\        <effect name=\"v4a_standard_fx\" library=\"v4a_fx\" uuid=\"41d3c987-e6cf-11e3-a88a-11aba5d5c51b\"\/>" $FILE
done

ui_print "- Repacking boot img..."
flash_boot;

ui_print " " "Download the apk and install as regular app" "after rebooting"
sleep 3
