SDK      := $(shell xcrun --sdk iphoneos --show-sdk-path)
CXX      := xcrun --sdk iphoneos clang++
ARCH     := arm64
MIN_IOS  := 15.0

CFLAGS   := -arch $(ARCH) -isysroot $(SDK) -miphoneos-version-min=$(MIN_IOS) \
            -O2 -fobjc-arc -fmodules -fblocks -fno-exceptions -fno-rtti \
            -I../luau/VM/include -I../luau/Compiler/include \
            -I../luau/Common/include

LDFLAGS  := -arch $(ARCH) -isysroot $(SDK) -miphoneos-version-min=$(MIN_IOS) \
            -dynamiclib -framework Foundation -framework UIKit \
            -framework CoreGraphics -framework QuartzCore \
            -Wl,-install_name,@executable_path/Frameworks/executor.dylib \
            -Wl,-dead_strip

SOURCES  := entry.mm executor.mm api.mm hooks.mm ui/overlay.mm
OBJECTS  := $(SOURCES:.mm=.o)
LUAU_VM  := ../luau/build/release/libluauvm.a
LUAU_CC  := ../luau/build/release/libluaucompiler.a

all: executor.dylib

executor.dylib: $(OBJECTS) $(LUAU_VM) $(LUAU_CC)
	$(CXX) $(LDFLAGS) -o $@ $(OBJECTS) $(LUAU_VM) $(LUAU_CC) -lobjc -lz

%.o: %.mm
	$(CXX) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS) executor.dylib
