/* ODataStore port: Windows' socket and file headers (GCDWebServerPlatform.h),
   after Foundation, whose GSConfig.h keeps windows.h's BOOL apart from
   Objective-C's. */

#import <Foundation/Foundation.h>

#include <winsock2.h>
#include <ws2tcpip.h>
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#include <sys/types.h>

typedef SOCKET GCDWebServerSocketHandle;
#define kGCDWebServerInvalidSocket INVALID_SOCKET
/* No O_NOFOLLOW: GCDWebServerRegularFileInfo() refuses reparse points before a file is opened. */
#define kGCDWebServerOpenNoFollow 0
