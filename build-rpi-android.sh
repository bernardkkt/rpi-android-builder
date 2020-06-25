#!/bin/bash
set -x
set -e

WS=/workspace
GIT_NAME=admin
GIT_EMAIL=admin@example.com

apt update
apt install -y repo git python-mako build-essential

mkdir -p ${WS} && cd ${WS}
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_EMAIL}"
repo init --depth=1 -u https://android.googlesource.com/platform/manifest -b android-8.1.0_r46
git clone --depth=1 https://github.com/android-rpi/local_manifests .repo/local_manifests -b oreo
repo sync  -f --force-sync --no-clone-bundle --no-tags -j$(nproc --all)

apt install -y gcc-arm-linux-gnueabihf
cd kernel/rpi
ARCH=arm scripts/kconfig/merge_config.sh arch/arm/configs/bcm2709_defconfig kernel/configs/android-base.config kernel/configs/android-base-arm.config kernel/configs/android-recommended.config
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make zImage
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make dtbs

# Patch 1
cat > /tmp/p1.patch << EOF
graphics/allocator/2.0/default/Gralloc1Allocator.cpp
@@ line 167 @@ Gralloc1Allocator::allocate(const BufferDescriptor& descriptor,
     hidl_cb(error, stride, hidl_buffers);
 +   usleep(1000);
 // free the buffers
 for (const auto& buffer : buffers) {
EOF
git apply /tmp/p1.patch

# Patch 2
cat > /tmp/p2.patch << EOF
Settings/AndroidManifest.xml
@@ line 67 @@
         <action android:name="android.intent.action.MAIN" />
         <category android:name="android.intent.category.LEANBACK_SETTINGS" />
+        <category android:name="android.intent.category.LAUNCHER" />
     </intent-filter>
</activity>
EOF
git apply /tmp/p2.patch

# Patch 3
cat > /tmp/p3.patch << EOF
opengl/java/android/opengl/GLSurfaceView.java
@@ line 1004 @@ public class GLSurfaceView extends SurfaceView implements SurfaceHolder.Callback
         public SimpleEGLConfigChooser(boolean withDepthBuffer) {
-            super(8, 8, 8, 0, withDepthBuffer ? 16 : 0, 0);
+            super(8, 8, 8, 8, withDepthBuffer ? 24 : 0, 0);
         }
EOF
git apply /tmp/p3.patch

# Patch 4
cat > /tmp/p4.patch << EOF
core/java/android/os/StrictMode.java
@@ line 1199 @@ public final class StrictMode {
     if (IS_ENG_BUILD) {
-            doFlashes = true;
     }
EOF
git apply /tmp/p4.patch

source build/envsetup.sh
lunch rpi3-eng
make ramdisk systemimage
