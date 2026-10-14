# GCDWebServer on GNUstep, the library, built, tested and installed the
# familiar way (gnustep-release-actions runs these):
#
#   make                        libGCDWebServer
#   make check                  the smoke test, over plain BSD sockets
#   make install DESTDIR=...    the library, and its headers in GCDWebServer/
#                               (#import <GCDWebServer/GCDWebServer.h>)
#
# clang, ARC and blocks: libobjc2 with the gnustep-2.0 runtime. macOS and iOS:
# Makefile.apple.
include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = libGCDWebServer
VERSION = 3.5.4

GCDWebServer_PUBLIC_HEADERS = \
	GCDWebServer/Core/GCDWebServer.h \
	GCDWebServer/Core/GCDWebServerConnection.h \
	GCDWebServer/Core/GCDWebServerFunctions.h \
	GCDWebServer/Core/GCDWebServerHTTPStatusCodes.h \
	GCDWebServer/Core/GCDWebServerRequest.h \
	GCDWebServer/Core/GCDWebServerResponse.h \
	GCDWebServer/Requests/GCDWebServerDataRequest.h \
	GCDWebServer/Requests/GCDWebServerFileRequest.h \
	GCDWebServer/Requests/GCDWebServerMultiPartFormRequest.h \
	GCDWebServer/Requests/GCDWebServerURLEncodedFormRequest.h \
	GCDWebServer/Responses/GCDWebServerDataResponse.h \
	GCDWebServer/Responses/GCDWebServerErrorResponse.h \
	GCDWebServer/Responses/GCDWebServerFileResponse.h \
	GCDWebServer/Responses/GCDWebServerStreamedResponse.h

# What differs between POSIX and Windows (sockets, files) is in
# GCDWebServer/Platform/<platform>: GCDWebServerPlatform.m and the headers it
# brings, behind GCDWebServer/Core/GCDWebServerPlatform.h.
ifeq ($(findstring mingw, $(GNUSTEP_TARGET_OS)), mingw)
  GCDWebServer_PLATFORM = Windows
  GCDWebServer_PLATFORM_LIBS = -lws2_32 -liphlpapi
else
  GCDWebServer_PLATFORM = POSIX
  GCDWebServer_PLATFORM_LIBS =
endif

libGCDWebServer_OBJC_FILES = $(wildcard GCDWebServer/Core/*.m GCDWebServer/Requests/*.m GCDWebServer/Responses/*.m) \
	GCDWebServer/Platform/$(GCDWebServer_PLATFORM)/GCDWebServerPlatform.m
libGCDWebServer_INCLUDE_DIRS = -IGCDWebServer/Core -IGCDWebServer/Requests -IGCDWebServer/Responses \
	-IGCDWebServer/Platform/$(GCDWebServer_PLATFORM)
libGCDWebServer_OBJCFLAGS = -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 \
	-fconstant-string-class=NSConstantString -fobjc-exceptions -Wall
libGCDWebServer_LIBRARIES_DEPEND_UPON = -lgnustep-base -lobjc -ldispatch -lz $(GCDWebServer_PLATFORM_LIBS)

include $(GNUSTEP_MAKEFILES)/library.make

# The headers in one directory, GCDWebServer/, as the library's users import
# them (their sources keep upstream's Core, Requests and Responses).
after-install::
	$(MKDIRS) $(GNUSTEP_HEADERS)/GCDWebServer
	for header in $(GCDWebServer_PUBLIC_HEADERS); do \
	  $(INSTALL_DATA) $$header $(GNUSTEP_HEADERS)/GCDWebServer/; \
	done

after-uninstall::
	rm -rf $(GNUSTEP_HEADERS)/GCDWebServer

check::
	$(MAKE) -C Tests/GNUstep GCDWebServer_PLATFORM=$(GCDWebServer_PLATFORM) GCDWebServer_PLATFORM_LIBS="$(GCDWebServer_PLATFORM_LIBS)"
	LD_LIBRARY_PATH="$(CURDIR)/obj$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" \
	PATH="$(CURDIR)/obj:$$PATH" ./Tests/GNUstep/obj/gws-smoke
