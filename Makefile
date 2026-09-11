ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang:latest:15.0
else
	TARGET = iphone:clang:latest:11.0
endif
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

# Unofficial fork fix: THEOS_PROJECT_DIR always points at the root-level
# project (it's exported once at the top and inherited as-is by every
# subproject's make -C invocation — see common.mk:76 `export
# THEOS_PROJECT_DIR`), never at this subproject's own directory. Theos's own
# makefiles hit the same issue and work around it the same way (see
# instance/rules.mk: "we use PWD instead of THEOS_PROJECT_DIR because the
# latter always refers to the root level project so it isn't correct for
# subprojects"). CURDIR is GNU Make's own reflection of the directory `make
# -C Tweaks/YTUHD` was invoked in (aggregate.mk uses exactly that), so it
# correctly resolves to .../Tweaks/YTUHD here.
YTUHD_DIR := $(CURDIR)

LIBVPX_BUILD = $(YTUHD_DIR)/vendor/libvpx_ios
LIBVPX_A     = $(LIBVPX_BUILD)/libvpx.a

DAV1D_BUILD  = $(YTUHD_DIR)/vendor/dav1d_ios
DAV1D_A      = $(DAV1D_BUILD)/libdav1d.a

# Build libvpx if the static library doesn't exist yet.
$(LIBVPX_A):
	@echo "==> Building libvpx (first-time setup)..."
	$(YTUHD_DIR)/vendor/build_libvpx.sh

# Build dav1d if the static library doesn't exist yet.
$(DAV1D_A):
	@echo "==> Building dav1d (first-time setup)..."
	$(YTUHD_DIR)/vendor/build_dav1d.sh

TWEAK_NAME = YTUHD
$(TWEAK_NAME)_FILES = Tweak.xm Settings.x VideoDecoderHelper.x HAMVPXVideoDecoder.m HAMDav1dVideoDecoder.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc \
    -I$(YTUHD_DIR)/vendor/libvpx \
    -I$(LIBVPX_BUILD) \
    -I$(YTUHD_DIR)/vendor/dav1d/include \
    -I$(DAV1D_BUILD)/install/include
$(TWEAK_NAME)_LDFLAGS = $(LIBVPX_A) $(DAV1D_A)
ifeq ($(SIDELOAD),1)
$(TWEAK_NAME)_FILES += libundirect_compact.m
else
$(TWEAK_NAME)_LIBRARIES = undirect
endif
$(TWEAK_NAME)_FRAMEWORKS = VideoToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

# Ensure libvpx and dav1d are built before compiling any tweak source.
#
# Unofficial fork fix: the previous approach declared this dependency as a
# pattern rule on $(THEOS_OBJ_DIR)/arm64/<file>.%.o *before* including
# tweak.mk. Theos names actual object files with a flags-hash suffix
# (e.g. HAMVPXVideoDecoder.m.4d165f00.o) that this repo has no way to predict,
# so the pattern never matched a real target and the prerequisite was
# silently a no-op: build_libvpx.sh/build_dav1d.sh never ran, and
# HAMVPXVideoDecoder.m/HAMDav1dVideoDecoder.m failed with "file not found"
# for vpx/vpx_decoder.h and dav1d/dav1d.h.
#
# before-all:: is Theos's own hook, guaranteed to run before any compilation
# (see theos/theos makefiles/master/rules.mk: "all:: ... before-all
# internal-all after-all") — no object-path guessing required.
before-all:: $(LIBVPX_A) $(DAV1D_A)

# `make libvpx` target for an explicit rebuild of the library.
.PHONY: libvpx
libvpx:
	$(YTUHD_DIR)/vendor/build_libvpx.sh

# `make dav1d` target for an explicit rebuild of the library.
.PHONY: dav1d
dav1d:
	$(YTUHD_DIR)/vendor/build_dav1d.sh
