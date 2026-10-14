/*
 ODataStore port: what differs between POSIX (Linux, macOS, iOS) and Windows,
 behind one set of names. GCDWebServerPlatformTypes.h, from
 GCDWebServer/Platform/POSIX or GCDWebServer/Platform/Windows (the build's
 include path chooses), brings the system's socket and file headers and
 GCDWebServerSocketHandle; GCDWebServerPlatform.m beside it implements these.
 Socket errors are POSIX errno values on both: Windows' are translated.
 */

#import <Foundation/Foundation.h>

#import "GCDWebServerPlatformTypes.h"

NS_ASSUME_NONNULL_BEGIN

/* Sockets: Winsock started once, before the first one (nothing elsewhere). */
void GCDWebServerSocketsStart(void);
BOOL GCDWebServerSocketIsValid(GCDWebServerSocketHandle socket);
int GCDWebServerSocketClose(GCDWebServerSocketHandle socket);
/* The last socket call's error, as an errno value. */
int GCDWebServerSocketLastError(void);
NSString* GCDWebServerSocketErrorString(int error);
/* Makes a pending read on the socket complete with end-of-file. */
void GCDWebServerSocketShutdownRead(GCDWebServerSocketHandle socket);
void GCDWebServerSocketSetReceiveTimeout(GCDWebServerSocketHandle socket, int seconds);
/* A write to a socket the peer has closed must not kill the process:
   SO_NOSIGPIPE on the socket where there is one, else SIGPIPE ignored
   process-wide unless the application handles it (Windows has none). */
void GCDWebServerSocketNoBrokenPipeSignal(GCDWebServerSocketHandle socket);
void GCDWebServerIgnoreBrokenPipe(void);

/* Files, in binary mode: created read-write for the user. */
int GCDWebServerOpenFile(NSString* path, int flags);
/* A regular file's size, modification date and ETag, its symbolic link not
   followed; NO for anything else. */
BOOL GCDWebServerRegularFileInfo(NSString* path, unsigned long long* size, NSDate* _Nullable* _Nonnull modified, NSString* _Nullable* _Nonnull eTag);

NS_ASSUME_NONNULL_END
