/* SMBKit.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep SMBKit Library
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include "SMBKit.h"
#include "SMBFileManager.h"

NSMutableArray *managers = nil;
NSRecursiveLock *ptrLock = nil;

@implementation SMBKit

+ (BOOL)initlibsmbc
{
  static BOOL smbcinited = NO;

  if (smbcinited == NO) {
    int err = smbc_init(auth_fn, 1);

    if (err >= 0) {
      fprintf(stderr, "smbkit: smbclient library initialized\n");

      if (ptrLock == nil) {
        ptrLock = [NSRecursiveLock new];
        managers = [NSMutableArray new];
      }
      
      smbcinited = YES;
    } else {
      fprintf(stderr, "smbkit: smbclient init error: %s\n", strerror(errno));
    }
  }
  
  return smbcinited;
}

+ (BOOL)registerManager:(SMBFileManager *)amanager
{
  if ([self initlibsmbc] == NO) {
    return NO;
  } else {
    [ptrLock lock];
    if ([managers containsObject: amanager] == NO) {
      if ([self managerWithAddress: [amanager address]]) {
        [ptrLock unlock];
        return NO;
      }
      
      [managers addObject: amanager];
      [ptrLock unlock];
    }
  }
  
  return YES;
}

+ (void)unregisterManager:(SMBFileManager *)amanager
{
  [ptrLock lock];
  if ([managers containsObject: amanager]) {
    [managers removeObject: amanager];
  }
  [ptrLock unlock];
  
  NSLog(@"smbkit: manager unregistered");
}

+ (SMBFileManager *)managerWithAddress:(NSString *)address
{
  int i;
  
  [ptrLock lock];
  for (i = 0; i < [managers count]; i++) {
    SMBFileManager *manager = [managers objectAtIndex: i];
  
    if ([[manager address] isEqual: address]) {
      [ptrLock unlock];
      return manager;
    }
  }
  [ptrLock unlock];
  
  return nil;
}

@end


static NSString *smbUrlPrefix = @"smb:/";

@implementation NSString (smbUrl)

- (NSString *)pathPartOfSmbUrl
{
  return [self substringFromIndex: 5];
}

- (NSString *)stringByPrependingUrlPrefix
{
  NSString *url = [NSString stringWithString: smbUrlPrefix];
  return [url stringByAppendingString: self];
}

- (NSString *)lastUrlPathComponent
{
  NSString *path = [self pathPartOfSmbUrl];
  return [path lastPathComponent];
}

- (NSString *)urlPathExtension
{
  NSString *path = [self pathPartOfSmbUrl];
  return [path pathExtension];
}

- (NSString *)stringByAppendingUrlPathComponent:(NSString *)aString
{
  NSString *path = [self pathPartOfSmbUrl];
  path = [path stringByAppendingPathComponent: aString];
  return [path stringByPrependingUrlPrefix];
}

- (NSString *)stringByAppendingUrlPathExtension:(NSString *)aString
{
  NSString *path = [self pathPartOfSmbUrl];
  path = [path stringByAppendingPathExtension: aString];
  return [path stringByPrependingUrlPrefix];
}

- (NSString *)stringByDeletingLastUrlPathComponent
{
  NSString *path = [self pathPartOfSmbUrl];
  path = [path stringByDeletingLastPathComponent];
  return [path stringByPrependingUrlPrefix];
}

- (NSString *)stringByDeletingUrlPathExtension
{
  NSString *path = [self pathPartOfSmbUrl];
  path = [path stringByDeletingPathExtension];
  return [path stringByPrependingUrlPrefix];
}

@end


void auth_fn(const char *server, const char *share,
	     char *workgroup, int wgmaxlen, char *username, int unmaxlen,
	     char *password, int pwmaxlen)
{
  NSString *address;
  SMBFileManager *manager;

  [ptrLock lock];
  address = [NSString stringWithCString: server];
  manager = [SMBKit managerWithAddress: address];
    
  if (manager) {
    NSString *usrname = [manager usrname];
    NSString *usrpwd = [manager usrpwd];
  
    if (usrname && usrpwd) {
      strncpy(username, [usrname cString], unmaxlen - 1);
      strncpy(password, [usrpwd cString], pwmaxlen - 1);
    }
  }

  [ptrLock unlock];
}


#define PREFIX "smb:"

BOOL parse_url(char *url,
		   int *server_i, int *server_len,
		   int *share_i, int *share_len,
		   int *path_i, int *path_len,
		   int *username_i, int *username_len,
		   int *password_i, int *password_len)
{
  int len = strlen(PREFIX);
  char *p;
  char *q, *r, *i;

  *server_i = *share_i = *path_i = *username_i = *password_i = 0;
  *server_len = *share_len = *path_len = *username_len = *password_len = 0;
  
  /* check for prefix */
  if (strncasecmp(url, PREFIX, len) || (url[len] != '/' && url[len] != 0)) {
    return NO;
  }
  
  p = url + len;
  
  /* check for slashes */
  if (strncmp(p, "//", 2)) {
    return NO;
  }
  
  p += 2;

  if (*p == '\0')
    return NO;

  q = strchr(p, '@');
  r = strchr(p, '/');
  
  /* if there's an @, parse domain, user, pass */
  if (q && (!r || q < r)) {
    i = strchr(p, ';');
    /* domain */
    if (i && i < q) {
      p = i + 1; /* skip it */
    }
    i = strchr(p, ':');
    /* pass? */
    if (i && i < q) {
      *username_i = p - url;
      *username_len = i - p;
      *password_i = i + 1 - url;
      *password_len = q - i - 1;
    }
    else {
      *username_i = p - url;
      *username_len = q - p;
    }
    p = q + 1;
  }

  /* do we have server? */
  if (*p == '\0') {
    return YES;
  }
  if (*p == '/') {
    return NO;
  }
  
  *server_i = p - url;
  
  /* if there's slash */
  if (r) {
    *server_len = r - p;
  } else {
    *server_len = strlen(p);
    return YES;
  }
  
  p += *server_len + 1;

  /* share? */
  if (*p == '\0') {
    return YES;
  }
  
  *share_i = p - url;
  r = strchr(p, '/');
  
  if (!r) {
    *share_len = strlen(p);
    return YES;
  } else {
    *share_len = r - p;
  }
  
  p += *share_len;

  /* the rest is path */
  if (*p == '\0' || p[1] == '\0') {
    return YES;
  }
  
  *path_i = p - url;
  *path_len = strlen(p);

  return YES;
}

/*
  Simplifies .., . and / in url.
*/
void simplify_url(char *url)
{
  int server_i, server_len;
  int share_i, share_len;
  int path_i, path_len;
  int username_i, username_len;
  int password_i, password_len;
  char *src;
  char *dest;
  char *buf;

  if (parse_url(url,
		      &server_i, &server_len,
		      &share_i, &share_len,
		      &path_i, &path_len,
		      &username_i, &username_len,
		      &password_i, &password_len) == NO) {
    printf("smbkit: invalid url\n");
  }

  if (server_i) {
    if (strncmp(url + server_i, ".", server_len) == 0 || strncmp(url + server_i, "..", server_len) == 0) {
      printf("smbkit: can't simplify . and .. in server name\n");
    }
  }
  if (! share_i) {
    return;
  }
  
  buf = (char *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(char) * (strlen(url) + 1));  
  
  strcpy(buf, url);
  dest = buf + share_i;
  src = url + share_i;
  while (*src) {
    if (strncmp(src, "..", 2) == 0 && (src[2] == '/' || src[2] == '\0')) {
      for (dest -= 2; *dest != '/'; dest--) { 
      }
      src += 2;
    } else if (strncmp(src, ".", 1) == 0) {
      if (src[1] == '/') {
	      src += 2;
	      continue;
      } else if (src[1] == '\0') {
	      src++;
	      continue;
      }
    }

    *dest = *src;
    dest++;
    src++;
  }

  *dest = '\0';
  strcpy(url, buf);
  
  NSZoneFree(NSDefaultMallocZone(), buf);
}

NSString *simplifyUrl(NSString *url)
{
  const char *urlc = [url cString];
  char *buf = NSZoneMalloc(NSDefaultMallocZone(), sizeof(char) * (strlen(urlc) + 1));
  NSString *simpurl = nil;

  strcpy(buf, urlc);
  simplify_url(buf);
  simpurl = [NSString stringWithCString: buf];
  NSZoneFree(NSDefaultMallocZone(), buf);

  return simpurl;
}

NSDictionary *urlDictionary(NSString *url)
{
  NSMutableDictionary *dict = nil;

#define ADD_ENTRY(e, i, l) \
if (i != 0) { \
entry = [parsurl substringWithRange: NSMakeRange(i, l)]; \
[dict setObject: entry forKey: e]; \
}

  if (url) {
    const char *urlc;
    char *url_p;
    NSString *parsurl;
    NSString *entry;
    int server_i;
    int share_i;
    int path_i;
    int username_i;
    int password_i;
    int server_len;
    int share_len;
    int path_len;
    int username_len;
    int password_len;
    
    urlc = [url cString];
    url_p = NSZoneMalloc(NSDefaultMallocZone(), sizeof(char) * (strlen(urlc) + 1));
    strcpy(url_p, urlc);
        
    if (parse_url(url_p,
		       &server_i, &server_len,
		       &share_i, &share_len,
		       &path_i, &path_len,
		       &username_i, &username_len,
		       &password_i, &password_len) == NO) {
      printf("smbkit: invalid url\n");
      NSZoneFree(NSDefaultMallocZone(), url_p);
      return nil;
    }
    
    parsurl = [NSString stringWithCString: url_p];
    NSZoneFree(NSDefaultMallocZone(), url_p);

    dict = [NSMutableDictionary dictionary];

    ADD_ENTRY (@"server", server_i, server_len);
    ADD_ENTRY (@"share", share_i, share_len);
    ADD_ENTRY (@"path", path_i, path_len);
    ADD_ENTRY (@"username", username_i, username_len);
    ADD_ENTRY (@"password", password_i, password_len);
  }

  return dict;
}


NSString *SMBNotificationKey = @"SMBNotificationKey";
NSString *SMBFileHandleOperationException = @"SMBFileHandleOperationException";
NSString *SMBFileHandleNotificationError = @"SMBFileHandleNotificationError";
NSString *SMBFileHandleReadCompletionNotification = @"SMBFileHandleReadCompletionNotification";
NSString *SMBFileHandleDataAvailableNotification = @"SMBFileHandleDataAvailableNotification";
NSString *SMBFileHandleWriteCompletionNotification = @"SMBFileHandleWriteCompletionNotification";
NSString *SMBFileHandleNotificationDataItem = @"SMBFileHandleNotificationDataItem";



