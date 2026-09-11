ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang:latest:15.0
else
	TARGET = iphone:clang:latest:11.0
endif
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

LIBVPX_BUILD = $(THEOS_PROJECT_DIR)/vendor/libvpx_ios
LIBVPX_A     = $(LIBVPX_BUILD)/libvpx.a

DAV1D_BUILD  = $(THEOS_PROJECT_DIR)/vendor/dav1d_ios
DAV1D_A      = $(DAV1D_BUILD)/libdav1d.a

# Build libvpx if the static library doesn't exist yet.
$(LIBVPX_A):
	@echo "==> Building libvpx (first-time setup)..."
	$(THEOS_PROJECT_DIR)/vendor/build_libvpx.sh

# Build dav1d if the static library doesn't exist yet.
$(DAV1D_A):
	@echo "==> Building dav1d (first-time setup)..."
	$(THEOS_PROJECT_DIR)/vendor/build_dav1d.sh

TWEAK_NAME = YTUHD
$(TWEAK_NAME)_FILES = Tweak.xm Settings.x VideoDecoderHelper.x HAMVPXVideoDecoder.m HAMDav1dVideoDecoder.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc \
    -I$(THEOS_PROJECT_DIR)/vendor/libvpx \
    -I$(LIBVPX_BUILD) \
    -I$(THEOS_PROJECT_DIR)/vendor/dav1d/include \
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
	$(THEOS_PROJECT_DIR)/vendor/build_libvpx.sh

# `make dav1d` target for an explicit rebuild of the library.
.PHONY: dav1d
dav1d:
	$(THEOS_PROJECT_DIR)/vendor/build_dav1d.sh
