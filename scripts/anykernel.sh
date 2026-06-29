### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
properties() { '
kernel.string=Seiran Kernel — vili by superuseryu
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=vili
supported.versions=13-16
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

# Detect available images
HAS_KSU=0; HAS_SUKI=0; HAS_NOKSU=0;
[ -f "$AKHOME/Image.vili.ksu" ]   && HAS_KSU=1;
[ -f "$AKHOME/Image.vili.suki" ]  && HAS_SUKI=1;
[ -f "$AKHOME/Image.vili.noksu" ] && HAS_NOKSU=1;
TOTAL=$((HAS_KSU + HAS_SUKI + HAS_NOKSU));

SELECTED_IMAGE="";

flush_keys() { sleep 0.15; }

# AIO: show selection menu
if [ "$TOTAL" -gt 1 ]; then
  ui_print " ";
  ui_print "  Select Variant  (VOL+ = Next  |  VOL- = Confirm)";
  OPTION=1;

  print_menu() {
    ui_print " ";
    I=0;
    [ "$HAS_NOKSU" = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && ui_print "  > NoKSU (Vanilla)" || ui_print "    NoKSU (Vanilla)"; }
    [ "$HAS_KSU"   = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && ui_print "  > KSU-Next + SUSFS" || ui_print "    KSU-Next + SUSFS"; }
    [ "$HAS_SUKI"  = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && ui_print "  > SukiSU Ultra + SUSFS" || ui_print "    SukiSU Ultra + SUSFS"; }
  }
  print_menu;
  flush_keys;

  while true; do
    input=$(getevent -qlc 1 2>/dev/null);
    case "$input" in
      *KEY_VOLUMEUP*DOWN*)
        OPTION=$(( OPTION % TOTAL + 1 ));
        print_menu; flush_keys ;;
      *KEY_VOLUMEDOWN*DOWN*)
        flush_keys; break ;;
    esac
  done

  I=0;
  [ "$HAS_NOKSU" = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && { SELECTED_IMAGE="Image.xiaomi.noksu"; ui_print "  >> NoKSU (Vanilla)"; }; }
  [ "$HAS_KSU"   = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && { SELECTED_IMAGE="Image.xiaomi.ksu";   ui_print "  >> KSU-Next + SUSFS"; }; }
  [ "$HAS_SUKI"  = "1" ] && { I=$((I+1)); [ "$OPTION" = "$I" ] && { SELECTED_IMAGE="Image.xiaomi.suki";  ui_print "  >> SukiSU Ultra + SUSFS"; }; }

# Single image: auto-detect
elif [ "$HAS_NOKSU" = "1" ]; then SELECTED_IMAGE="Image.vili.noksu"; ui_print "  >> NoKSU (auto)";
elif [ "$HAS_KSU"   = "1" ]; then SELECTED_IMAGE="Image.vili.ksu";   ui_print "  >> KSU-Next (auto)";
elif [ "$HAS_SUKI"  = "1" ]; then SELECTED_IMAGE="Image.vili.suki";  ui_print "  >> SukiSU (auto)";
elif [ -f "$AKHOME/Image" ]; then
  ui_print "  Single image found, flashing...";
else
  ui_print "ERROR: No kernel image found!";
  exit 1;
fi

# Swap selected to Image
if [ -n "$SELECTED_IMAGE" ]; then
  mv -f "$AKHOME/$SELECTED_IMAGE" "$AKHOME/Image";
  rm -f "$AKHOME/Image.vili.ksu" "$AKHOME/Image.vili.suki" "$AKHOME/Image.vili.noksu";
fi

[ -f "$AKHOME/Image" ] || { ui_print "ERROR: Image prep failed!"; exit 1; }

# Flash — auto-detect init_boot vs boot
if [ -L "/dev/block/bootdevice/by-name/init_boot_a" ] || \
   [ -L "/dev/block/by-name/init_boot_a" ]; then
  ui_print "  Detected init_boot partition";
  split_boot; flash_boot;
else
  ui_print "  Using boot partition";
  dump_boot; write_boot;
fi
## end boot install
