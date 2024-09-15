#!/usr/bin/env bash

set_tz_to() {
	TZ="$1"
	if [[ -n "$TZ" ]] && [[ -n "$2" ]]; then
		echo "set_tz(): Max 1 Argument"
		exit 1
	elif [[ -z "$TZ" ]]; then
		echo "set_tz(): Recived 0 Argument, expected 1."
		exit 1
	fi

	if ! sudo ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>/dev/null; then
		echo "set_tz(): Failed to set Time Zone"
		exit 1
	fi
}

set_tz_to "Asia/Jakarta"

NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"

BB_NAME="Silent Busybox by VDBay"
BB_VER="v1"
BB_TIME_STAMP="$(date +%Y%m%d%H%M)"
BUILD_TYPE="dev"
BUILD_LOG="${NDK_PROJECT_PATH}/build.log"

# set 'true' if you wanna use the canary version of ndk
NDK_CANARY=false
# TIP: you can replace this ndk canary with your own ndk canary.
NDK_CANARY_LINK="https://github.com/eraselk/ndk-canary/releases/download/r28-canary-20240730/android-ndk-12157319-linux-x86_64.zip"

# set 'true' if you wanna use the stable version of ndk
NDK_STABLE=true
NDK_STABLE_VERSION="r27b"

RUN_ID="${GITHUB_RUN_ID:-local}"

VERSION_CODE="$(echo "$BB_VER" | tr -d 'v.')"

ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"

# Export all variables
export BB_NAME BB_VER BB_TIME_STAMP BUILD_TYPE BB_BUILDER VERSION_CODE NDK_STABLE NDK_STABLE_VERSION NDK_CANARY NDK_CANARY_LINK RUN_ID ZIP_NAME TZ NDK_PROJECT_PATH BUILD_LOG BUILD_SUCCESS

if $NDK_STABLE; then
	wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_STABLE_VERSION}-linux.zip" -O "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	unzip -q "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	rm "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	mv "android-ndk-${NDK_STABLE_VERSION}" ndk
elif $NDK_CANARY; then
	wget -q "$NDK_CANARY_LINK" -O ndk-tarball
	unzip -q ndk-tarball
	rm ndk-tarball
	mv android-ndk-* ndk
fi

{
	git clone --depth=1 https://github.com/eraselk/busybox
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

	[[ -x "run.sh" ]] || chmod +x run.sh

	bash run.sh generate

	if $NDK_PROJECT_PATH/ndk/ndk-build all -j$(nproc --all); then
		git clone --depth=1 https://github.com/eraselk/busybox-template

		cp "$NDK_PROJECT_PATH/libs/arm64-v8a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64"
		cp "$NDK_PROJECT_PATH/libs/armeabi-v7a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm"

		sed -i "s/version=.*/version=$BB_VER-$RUN_ID/" "$NDK_PROJECT_PATH/busybox-template/module.prop"
		sed -i "s/versionCode=.*/versionCode=$VERSION_CODE/" "$NDK_PROJECT_PATH/busybox-template/module.prop"

		cd "$NDK_PROJECT_PATH/busybox-template"
		zip -r9 "$ZIP_NAME" *
		mv "$ZIP_NAME" "$NDK_PROJECT_PATH"
		cd "$NDK_PROJECT_PATH"
	fi
	true
} | tee -a "${BUILD_LOG}"
