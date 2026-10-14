/* ODataStore port: POSIX's socket and file headers (GCDWebServerPlatform.h). */

#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <sys/types.h>
#import <unistd.h>

typedef int GCDWebServerSocketHandle;
#define kGCDWebServerInvalidSocket (-1)
/* open() does not follow a final symbolic link. */
#define kGCDWebServerOpenNoFollow O_NOFOLLOW
