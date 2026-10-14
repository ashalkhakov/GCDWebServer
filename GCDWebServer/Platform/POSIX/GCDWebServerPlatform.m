/*
 ODataStore port: GCDWebServerPlatform.h on POSIX (Linux, macOS, iOS), what
 the sources did themselves before Windows.
 */

#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#if defined(__APPLE__)
#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <SystemConfiguration/SystemConfiguration.h>
#endif
#endif

#import <ifaddrs.h>
#import <net/if.h>
#import <signal.h>
#import <string.h>

#import "GCDWebServerPrivate.h"

void GCDWebServerSocketsStart(void) {
}

BOOL GCDWebServerSocketIsValid(GCDWebServerSocketHandle socket) {
  return socket >= 0;
}

int GCDWebServerSocketClose(GCDWebServerSocketHandle socket) {
  return close(socket);
}

int GCDWebServerSocketLastError(void) {
  return errno;
}

NSString* GCDWebServerSocketErrorString(int error) {
  return [NSString stringWithUTF8String:strerror(error)];
}

void GCDWebServerSocketSetReceiveTimeout(GCDWebServerSocketHandle socket, int seconds) {
  struct timeval timeout = {seconds, 0};
  setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
}

void GCDWebServerSocketNoBrokenPipeSignal(GCDWebServerSocketHandle socket) {
#ifdef SO_NOSIGPIPE
  int noSigPipe = 1;
  setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
#endif
}

void GCDWebServerIgnoreBrokenPipe(void) {
#if !defined(SO_NOSIGPIPE)
  // Without SO_NOSIGPIPE a write to a socket the peer has closed raises SIGPIPE, which kills the
  // process by default: libdispatch does the writes, so MSG_NOSIGNAL is not an option. Ignore it
  // unless the application installed its own handler.
  struct sigaction currentAction;
  if ((sigaction(SIGPIPE, NULL, &currentAction) == 0) && (currentAction.sa_handler == SIG_DFL)) {
    signal(SIGPIPE, SIG_IGN);
  }
#endif
}

int GCDWebServerOpenFile(NSString* path, int flags) {
  return open([path fileSystemRepresentation], flags, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
}

static inline NSDate* _NSDateFromTimeSpec(const struct timespec* t) {
  return [NSDate dateWithTimeIntervalSince1970:((NSTimeInterval)t->tv_sec + (NSTimeInterval)t->tv_nsec / 1000000000.0)];
}

BOOL GCDWebServerRegularFileInfo(NSString* path, unsigned long long* size, NSDate** modified, NSString** eTag) {
  struct stat info;
  if (lstat([path fileSystemRepresentation], &info) || !(info.st_mode & S_IFREG)) {
    return NO;
  }
  *size = (unsigned long long)info.st_size;
#if defined(__APPLE__)
  *modified = _NSDateFromTimeSpec(&info.st_mtimespec);
  *eTag = [NSString stringWithFormat:@"%llu/%li/%li", (unsigned long long)info.st_ino, (long)info.st_mtimespec.tv_sec, (long)info.st_mtimespec.tv_nsec];
#else
  *modified = _NSDateFromTimeSpec(&info.st_mtim);
  *eTag = [NSString stringWithFormat:@"%llu/%li/%li", (unsigned long long)info.st_ino, (long)info.st_mtim.tv_sec, (long)info.st_mtim.tv_nsec];
#endif
  return YES;
}

NSString* GCDWebServerGetPrimaryIPAddress(BOOL useIPv6) {
  NSString* address = nil;
#if TARGET_OS_IPHONE
#if !TARGET_IPHONE_SIMULATOR && !TARGET_OS_TV
  const char* primaryInterface = "en0";  // WiFi interface on iOS
#endif
#elif defined(__APPLE__)
  const char* primaryInterface = NULL;
  SCDynamicStoreRef store = SCDynamicStoreCreate(kCFAllocatorDefault, CFSTR("GCDWebServer"), NULL, NULL);
  if (store) {
    CFPropertyListRef info = SCDynamicStoreCopyValue(store, CFSTR("State:/Network/Global/IPv4"));  // There is no equivalent for IPv6 but the primary interface should be the same
    if (info) {
      NSString* interface = [(__bridge NSDictionary*)info objectForKey:@"PrimaryInterface"];
      if (interface) {
        primaryInterface = [[NSString stringWithString:interface] UTF8String];  // Copy string to auto-release pool
      }
      CFRelease(info);
    }
    CFRelease(store);
  }
  if (primaryInterface == NULL) {
    primaryInterface = "lo0";
  }
#endif  // Without SystemConfiguration, take the first interface that is up and not loopback
  struct ifaddrs* list;
  if (getifaddrs(&list) >= 0) {
    for (struct ifaddrs* ifap = list; ifap; ifap = ifap->ifa_next) {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_TV
      // Assume en0 is Ethernet and en1 is WiFi since there is no way to use SystemConfiguration framework in iOS Simulator
      // Assumption holds for Apple TV running tvOS
      if (strcmp(ifap->ifa_name, "en0") && strcmp(ifap->ifa_name, "en1"))
#elif !defined(__APPLE__)
      if ((ifap->ifa_addr == NULL) || (ifap->ifa_flags & IFF_LOOPBACK))
#else
      if (strcmp(ifap->ifa_name, primaryInterface))
#endif
      {
        continue;
      }
      if ((ifap->ifa_flags & IFF_UP) && ((!useIPv6 && (ifap->ifa_addr->sa_family == AF_INET)) || (useIPv6 && (ifap->ifa_addr->sa_family == AF_INET6)))) {
        address = GCDWebServerStringFromSockAddr(ifap->ifa_addr, NO);
        break;
      }
    }
    freeifaddrs(list);
  }
  return address;
}
