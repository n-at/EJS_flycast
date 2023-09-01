DEBUG         := 0
DEBUG_ASAN    := 0
DEBUG_UBSAN   := 0
NO_REND       := 0
HAVE_GL       := 1
HAVE_GL2      := 0
HAVE_OIT      ?= 0
HAVE_VULKAN   := 0
HAVE_CORE     := 0
NO_THREADS    := 0
NO_EXCEPTIONS := 0
NO_NVMEM      := 0
NO_VERIFY     := 1
HAVE_LTCG     ?= 0
HAVE_GENERIC_JIT := 1
HAVE_GL3      := 0
FORCE_GLES    := 0
STATIC_LINKING:= 0
HAVE_TEXUPSCALE := 1
HAVE_OPENMP   := 1
HAVE_CHD      := 1
HAVE_CLANG    ?= 0
HAVE_CDROM    := 0
ENABLE_MODEM  := 1

TARGET_NAME   := flycast

ifeq ($(HAVE_CLANG),1)
	CXX      = ${CC_PREFIX}clang++
	CC       = ${CC_PREFIX}clang
	SHARED   := -fuse-ld=lld
else
	CXX      ?= ${CC_PREFIX}g++
	CC       ?= ${CC_PREFIX}gcc
	SHARED   :=
endif
ifeq ($(HAVE_LTCG),1)
	SHARED   += -flto
endif

ifneq (${AS},)
	CC_AS := ${AS}
endif
CC_AS    ?= ${CC_PREFIX}as

MFLAGS   := 
ASFLAGS  := 
LDFLAGS  :=
LDFLAGS_END :=
INCFLAGS :=
LIBS     :=
CFLAGS   := 
CXXFLAGS :=

GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
	CXXFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

UNAME=$(shell uname -a)

LIBRETRO_DIR := .

# Cross compile ?

ifeq (,$(ARCH))
	ARCH = $(shell uname -m)
endif

# Target Dynarec
WITH_DYNAREC = $(ARCH)

ifeq ($(ARCH), $(filter $(ARCH), i386 i686))
	WITH_DYNAREC = x86
endif

ifeq ($(platform),)
	platform = unix
	ifeq ($(UNAME),)
		platform = win
	else ifneq ($(findstring MINGW,$(UNAME)),)
		platform = win
	else ifneq ($(findstring Darwin,$(UNAME)),)
		platform = osx
	else ifneq ($(findstring win,$(UNAME)),)
		platform = win
	endif
endif

# system platform
system_platform = unix
ifeq ($(shell uname -a),)
	EXE_EXT = .exe
	system_platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
	system_platform = osx
	arch = intel
	ifeq ($(shell uname -p),powerpc)
		arch = ppc
	endif
else ifneq ($(findstring MINGW,$(shell uname -a)),)
	system_platform = win
endif

CORE_DIR := .

DYNAREC_USED = 0
CORE_DEFINES   := -D__LIBRETRO__  -DHAVE_GLSYM_PRIVATE

ifeq ($(NO_VERIFY),1)
	CORE_DEFINES += -DNO_VERIFY
endif

DC_PLATFORM=dreamcast

HOST_CPU_X86=0x20000001
HOST_CPU_ARM=0x20000002
HOST_CPU_MIPS=0x20000003
HOST_CPU_X64=0x20000004
HOST_CPU_ARM64=0x20000006

ifeq ($(STATIC_LINKING),1)
	EXT=a
endif

# emscripten
ifeq ($(platform), emscripten)
	EXT       ?= bc
	TARGET := $(TARGET_NAME)_libretro_$(platform).$(EXT)
	FORCE_GLES := 1
	WITH_DYNAREC =
	HAVE_GENERIC_JIT = 0
	DYNAREC_USED = 1
	CPUFLAGS += -Dasm=asmerror -D__asm__=asmerror -DNO_ASM -DNOSSE
	SINGLE_THREAD := 1
	PLATCFLAGS += -Drglgen_resolve_symbols_custom=reicast_rglgen_resolve_symbols_custom \
					  -Drglgen_resolve_symbols=reicast_rglgen_resolve_symbols
	NO_REC = 0
	HAVE_OPENMP = 0
	PLATFORM_EXT := unix
	#HAVE_SHARED_CONTEXT := 1
	CFLAGS += -s USE_ZLIB=1 -DTARGET_NO_EXCEPTIONS=1
    STATIC_LINKING = 1
endif

ifeq ($(STATIC_LINKING),1)
	fpic=
	SHARED=
endif

ifeq ($(SINGLE_PREC_FLAGS),1)
	CORE_DEFINES += -fno-builtin-sqrtf
endif

#ifeq ($(WITH_DYNAREC), $(filter $(WITH_DYNAREC), x86_64 x64))
#	HOST_CPU_FLAGS = -DHOST_CPU=$(HOST_CPU_X64)
#	HAVE_LTCG = 0
#endif

ifeq ($(WITH_DYNAREC), x86)
	HOST_CPU_FLAGS = -DHOST_CPU=$(HOST_CPU_X86)
endif

ifeq ($(FORCE_GLES),1)
	GLES = 1
	GL_LIB := -lGLESv2
else ifneq (,$(findstring gles,$(platform)))
	GLES = 1
	GL_LIB := -lGLESv2
else ifeq ($(platform), win)
	GL_LIB := -lopengl32
else ifneq (,$(findstring osx,$(platform)))
	GL_LIB := -framework OpenGL
else ifneq (,$(findstring ios,$(platform)))
	GL_LIB := -framework OpenGLES
else ifeq ($(GL_LIB),)
	GL_LIB := -lGL
endif

CFLAGS       += $(HOST_CPU_FLAGS)
CXXFLAGS     += $(HOST_CPU_FLAGS)
RZDCY_CFLAGS += $(HOST_CPU_FLAGS)

include Makefile.common

ifeq ($(WITH_DYNAREC), x86)
	HAVE_LTCG = 0
endif

ifeq ($(DEBUG_ASAN),1)
	DEBUG           = 1
	DEBUG_UBSAN     = 0
	LDFLAGS        += -lasan -fsanitize=address
	CFLAGS         += -fsanitize=address
endif

ifeq ($(DEBUG_UBSAN),1)
	DEBUG           = 1
	CFLAGS         += -fsanitize=undefined
	LDFLAGS        += -lubsan -fsanitize=undefined
endif

ifeq ($(DEBUG),1)
	OPTFLAGS       := -O0
	LDFLAGS        += -g
	CFLAGS         += -g
else
	ifneq (,$(findstring msvc,$(platform)))
		OPTFLAGS       := -O3
	else ifneq (,$(findstring classic_arm,$(platform)))
		OPTFLAGS       := -O3
	else ifeq (,$(findstring classic_arm,$(platform)))
		OPTFLAGS       := -O3
	endif

	CORE_DEFINES   += -DNDEBUG
	LDFLAGS        += -DNDEBUG

	ifeq ($(HAVE_LTCG), 1)
		CORE_DEFINES   += -flto
	endif
endif

ifeq ($(HAVE_GL3), 1)
	HAVE_CORE = 1
	CORE_DEFINES += -DHAVE_GL3
endif

RZDCY_CFLAGS	+= $(CFLAGS) -c $(OPTFLAGS) -frename-registers -ftree-vectorize -fomit-frame-pointer 
RZDCY_CFLAGS += -DTARGET_LINUX_x86

ifeq ($(NO_THREADS),1)
	CORE_DEFINES += -DTARGET_NO_THREADS
else
	NEED_PTHREAD=1
endif

ifeq ($(NO_REC),1)
	CORE_DEFINES += -DTARGET_NO_REC
endif

ifeq ($(NO_REND),1)
	CORE_DEFINES += -DNO_REND=1
endif

ifeq ($(NO_EXCEPTIONS),1)
	CORE_DEFINES += -DTARGET_NO_EXCEPTIONS=1
endif

ifeq ($(NO_NVMEM),1)
	CORE_DEFINES += -DTARGET_NO_NVMEM=1
endif

RZDCY_CXXFLAGS := $(RZDCY_CFLAGS) -fexceptions -fno-rtti -std=gnu++11

ifeq (,$(findstring msvc,$(platform)))
	CORE_DEFINES   += -funroll-loops
endif

ifeq ($(HAVE_OIT), 1)
	HAVE_CORE = 1
	CORE_DEFINES += -DHAVE_OIT -DHAVE_GL4
endif

ifeq ($(HAVE_CORE), 1)
	CORE_DEFINES += -DCORE
endif

ifeq ($(HAVE_TEXUPSCALE), 1)
	CORE_DEFINES += -DHAVE_TEXUPSCALE
ifeq ($(HAVE_OPENMP), 1)
	CFLAGS += -fopenmp
	CXXFLAGS += -fopenmp
	LDFLAGS += -fopenmp
else
	CFLAGS += -DTARGET_NO_OPENMP
	CXXFLAGS += -DTARGET_NO_OPENMP
endif
ifeq ($(platform), win)
	LDFLAGS_END += -Wl,-Bstatic -lgomp -lwsock32 -lws2_32 -liphlpapi
endif
	NEED_CXX11=1
	NEED_PTHREAD=1
endif

ifeq ($(NEED_PTHREAD), 1)
	LIBS         += -lpthread
endif

ifeq ($(HAVE_GL), 1)
	ifeq ($(GLES),1)
		CORE_DEFINES += -DHAVE_OPENGLES -DHAVE_OPENGLES2
	else
		CORE_DEFINES += -DHAVE_OPENGL
	endif
endif

ifeq ($(HAVE_VULKAN), 1)
	CORE_DEFINES += -DHAVE_VULKAN
endif

ifeq ($(DEBUG), 1)
	HAVE_GENERIC_JIT = 0
endif

ifeq ($(HAVE_GENERIC_JIT), 1)
	CORE_DEFINES += -DTARGET_NO_JIT
	NEED_CXX11=1
endif

ifeq ($(NEED_CXX11), 1)
	CXXFLAGS     += -std=c++11
endif

ifeq ($(HAVE_CHD),1)
CORE_DEFINES += -DHAVE_STDINT_H -DHAVE_STDLIB_H -DHAVE_SYS_PARAM_H -D_7ZIP_ST -DUSE_FLAC -DUSE_LZMA
endif

RZDCY_CFLAGS   += $(CORE_DEFINES)
RZDCY_CXXFLAGS += $(CORE_DEFINES)
CFLAGS         += $(CORE_DEFINES)
CXXFLAGS       += $(CORE_DEFINES)

CFLAGS   += $(OPTFLAGS) -c
CFLAGS   += -fno-strict-aliasing
CXXFLAGS += -fno-rtti -fpermissive -fno-operator-names
LIBS     += -lm 

PREFIX        ?= /usr/local

ifneq (,$(findstring arm, $(ARCH)))
	CC_AS    = ${CC_PREFIX}${CC} #The ngen_arm.S must be compiled with gcc, not as
	ASFLAGS  += $(CFLAGS)
endif

ifeq ($(PGO_MAKE),1)
	CFLAGS += -fprofile-generate -pg
	LDFLAGS += -fprofile-generate
else
	CFLAGS += -fomit-frame-pointer
endif

ifeq ($(PGO_USE),1)
	CFLAGS += -fprofile-use
endif

ifeq ($(LTO_TEST),1)
	CFLAGS += -flto -fwhole-program 
	LDFLAGS +=-flto -fwhole-program 
endif

CFLAGS     += $(fpic)
CXXFLAGS   += $(fpic)
LDFLAGS    += $(fpic)

OBJECTS := $(SOURCES_CXX:.cpp=.o) $(SOURCES_C:.c=.o) $(SOURCES_ASM:.S=.o)
OBJECTS:=$(OBJECTS:.cc=.o)

ifneq (,$(findstring msvc,$(platform)))
	OBJOUT = -Fo
	LINKOUT = -out:
	LD = link.exe
else
	LD = $(CXX)
endif

all: $(TARGET)	
$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(LD) $(MFLAGS) $(fpic) $(SHARED) $(LDFLAGS) $(OBJECTS) $(LDFLAGS_END) $(GL_LIB) $(LIBS) -o $@
endif

%.o: %.cpp
	$(CXX) $(INCFLAGS) $(CFLAGS) $(MFLAGS) $(CXXFLAGS) $< -o $@
	
%.o: %.c
	$(CC) $(INCFLAGS) $(CFLAGS) $(MFLAGS) $< -o $@

%.o: %.S
	$(CC_AS) $(ASFLAGS) $(INCFLAGS) $< -o $@

%.o: %.cc
	$(CXX) $(INCFLAGS) $(CFLAGS) $(MFLAGS) $(CXXFLAGS) $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)

