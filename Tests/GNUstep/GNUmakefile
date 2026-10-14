# The smoke test, against the library as built at the repository's root.
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = gws-smoke
gws-smoke_OBJC_FILES = gws-smoke.m
gws-smoke_INCLUDE_DIRS = -I../../GCDWebServer/Core -I../../GCDWebServer/Requests -I../../GCDWebServer/Responses \
	-I../../GCDWebServer/Platform/$(GCDWebServer_PLATFORM)
gws-smoke_OBJCFLAGS = -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 \
	-fconstant-string-class=NSConstantString -fobjc-exceptions -Wall
gws-smoke_LIB_DIRS = -L../../obj
gws-smoke_TOOL_LIBS = -lGCDWebServer -ldispatch $(GCDWebServer_PLATFORM_LIBS)

include $(GNUSTEP_MAKEFILES)/tool.make
