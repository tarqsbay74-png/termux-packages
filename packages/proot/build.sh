# Contributor: @michalbednarski
TERMUX_PKG_HOMEPAGE=https://proot-me.github.io/
TERMUX_PKG_DESCRIPTION="Emulate chroot, bind mount and binfmt_misc for non-root users"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="Michal Bednarski @michalbednarski"
TERMUX_PKG_VERSION="5.1.107.92"
TERMUX_PKG_SRCURL=https://github.com/termux/proot/archive/v${TERMUX_PKG_VERSION}.zip
TERMUX_PKG_SHA256=29385d1ddb619a9c4449ab512bfd55032034b22f724ddf98fc95ff300ea32135
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"
TERMUX_PKG_DEPENDS="libtalloc, libtalloc-static"
TERMUX_PKG_SUGGESTS="proot-distro"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_MAKE_ARGS="-C src PROOT_WITH_LIBANDROID_SHMEM=true"

export PROOT_UNBUNDLE_LOADER=$TERMUX_PREFIX/libexec/proot

termux_step_pre_configure() {
    # بناء libandroid-shmem من المصدر مع تعطيل log
    local LIBSHMEM_SRC_DIR=$TERMUX_PKG_BUILDDIR/libandroid-shmem
    mkdir -p $LIBSHMEM_SRC_DIR
    cd $LIBSHMEM_SRC_DIR

    curl -L -o libandroid-shmem.zip https://github.com/termux/libandroid-shmem/archive/refs/tags/v0.7.zip
    unzip -q libandroid-shmem.zip
    cd libandroid-shmem-0.7

    # تعطيل استدعاءات __android_log_print
    sed -i 's/__android_log_print/\/\/ __android_log_print/g' shmem.c
    sed -i 's/#define LOG_TAG "libandroid-shmem"/\/\/ #define LOG_TAG "libandroid-shmem"/' shmem.c
    sed -i '/#include <android\/log.h>/d' shmem.c

    # تجميع المكتبة الثابتة (لـ aarch64)
    $CC $CFLAGS -c shmem.c -o shmem.o
    $AR rcs libandroid-shmem.a shmem.o

    mkdir -p $TERMUX_PKG_BUILDDIR/libs
    cp libandroid-shmem.a $TERMUX_PKG_BUILDDIR/libs/

    cd $TERMUX_PKG_BUILDDIR

    # إعداد LDFLAGS للتجميع الثابت بالكامل (static)
    LDFLAGS=" -static"
    LDFLAGS+=" -L$TERMUX_PKG_BUILDDIR/libs -L$TERMUX_PREFIX/lib"
    LDFLAGS+=" -ltalloc -Wl,-z,noexecstack"
    LDFLAGS+=" -landroid-shmem"
    export LDFLAGS

    # تعطيل System V IPC لأن Android لا يدعمه، ونعتمد على libandroid-shmem
    CPPFLAGS+=" -DARG_MAX=131072 -DVERSION=\\\"${TERMUX_PKG_VERSION}\\\""
    CPPFLAGS+=" -DWITHOUT_SYSVIPC"
}

termux_step_post_make_install() {
    mkdir -p $TERMUX_PREFIX/share/man/man1
    install -m600 $TERMUX_PKG_SRCDIR/doc/proot/man.1 $TERMUX_PREFIX/share/man/man1/proot.1

    sed -e "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
        $TERMUX_PKG_BUILDER_DIR/termux-chroot \
        > $TERMUX_PREFIX/bin/termux-chroot
    chmod 700 $TERMUX_PREFIX/bin/termux-chroot
}
