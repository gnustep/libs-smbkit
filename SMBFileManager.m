/* SMBFileManager.m
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <errno.h>
#include <string.h>
#include "SMBKit.h"
#include "SMBFileManager.h"
#include "SMBFileHandle.h"

@implementation SMBFileManager

- (void)dealloc
{
  [SMBKit unregisterManager: self];
  
  TEST_RELEASE (baseurl);
  TEST_RELEASE (address);
  TEST_RELEASE (usrname);
  TEST_RELEASE (usrpwd);
  TEST_RELEASE (lastError);
  
	[super dealloc];	
}

+ (id)managerForBaseUrl:(NSString *)url
             userName:(NSString *)name
             password:(NSString *)pswd
{
  return AUTORELEASE ([[self alloc] initWithBaseUrl: url
                                           userName: name
                                           password: pswd]);
}

- (id)initWithBaseUrl:(NSString *)url
             userName:(NSString *)name
             password:(NSString *)pswd
{  
	self = [super init];

  if (self) {
    NSString *simurl = simplifyUrl(url);    
    NSString *path = [simurl pathPartOfSmbUrl];
    NSArray *components = [path pathComponents];
    
    if (components && ([components count] > 1)) {
      NSString *addr = [components objectAtIndex: 1];
  
      ASSIGN (baseurl, simurl);
      ASSIGN (address, addr);
      
      usrname = nil;
      usrpwd = nil;
      lastError = nil;
      
      if (name) {
        ASSIGN (usrname, name);
      }
      if (pswd) {
        ASSIGN (usrpwd, pswd);
      }
    
      if ([SMBKit registerManager: self] == NO) {
        fprintf(stderr, "SMBFileManager: can't register with SMBKit\n");
        DESTROY (self);
      }
    } else {
      DESTROY (self);
    }
  }
    
	return self;
}

- (NSString *)baseUrl
{
  return baseurl;
}

- (NSString *)address
{
  return address;
}

- (NSString *)usrname
{
  return usrname;
}

- (NSString *)usrpwd
{
  return usrpwd;
}

- (NSArray *)directoryContentsAtUrl:(NSString *)url
{
  NSString *simurl = simplifyUrl(url);
  int dh = smbc_opendir([simurl cString]);
  
  if (dh < 0) {
    if (errno == EACCES) {
      NSLog(@"%@: permission denied!", url);
      return [NSArray array];
    }
  
    NSLog(@"smbc_opendir() failed %@ %s", simurl, strerror(errno));
    return nil;
  } else {
    NSMutableArray *entries = [NSMutableArray array];
    struct smbc_dirent *ent;
    
    while ((ent = smbc_readdir(dh)) != NULL) {
      if ((ent->smbc_type == SMBC_DIR) 
                            || (ent->smbc_type == SMBC_FILE)
                                            || (ent->smbc_type == SMBC_LINK)) { 
 	      if ((strcmp(ent->name, ".") != 0) && (strcmp(ent->name, "..") != 0)) {
          [entries insertObject: [NSString stringWithCString: ent->name] 
                        atIndex: [entries count]];      
        }
      } else if ((ent->smbc_type == SMBC_FILE_SHARE) && [url isEqual: baseurl]) {
        [entries insertObject: [NSString stringWithCString: ent->name] 
                      atIndex: [entries count]];      
      }
    }

    if (errno != 0) {
      NSLog(@"smbc_readdir() failed %@ %s", simurl, strerror(errno));
      smbc_closedir(dh);
      return nil;
    }

    smbc_closedir(dh);
    
    return entries;
  }

  return nil;
}

- (NSArray *)subpathsAtUrl:(NSString *)url
{
  SMBDirectoryEnumerator *direnum;
  NSMutableArray *contents;
  NSString *subpath;
  BOOL isDir;
  IMP nxtImp;
  IMP addImp;
  
  if (([self fileExistsAtUrl: simplifyUrl(url) isDirectory: &isDir] && isDir) == NO) {
    return nil;
  }
    
  direnum = [[SMBDirectoryEnumerator alloc] initWithDirectoryUrl: url 
					                                        smbFileManager: self];
             
  contents = [NSMutableArray array];
  
  nxtImp = [direnum methodForSelector: @selector(nextObject)];
  addImp = [contents methodForSelector: @selector(addObject:)];
  
  while ((subpath = (*nxtImp)(direnum, @selector(nextObject))) != nil) {
    (*addImp)(contents, @selector(addObject:), subpath);
  }
  
  RELEASE(direnum);

  return [contents makeImmutableCopyOnFail: NO];
}  

- (NSDictionary *)fileAttributesAtUrl:(NSString *)url 
                         traverseLink:(BOOL)flag
{
  struct stat st;
  
  if (smbc_stat([url cString], &st) == 0) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
    if (st.st_ctime < st.st_mtime) {
      [dict setObject: [NSDate dateWithTimeIntervalSince1970: st.st_ctime] 
               forKey: @"NSFileCreationDate"];
    } else {
      [dict setObject: [NSDate dateWithTimeIntervalSince1970: st.st_mtime] 
               forKey: @"NSFileCreationDate"];
    }

    [dict setObject: [NSDate dateWithTimeIntervalSince1970: st.st_mtime] 
             forKey: @"NSFileModificationDate"];

#define SET_MODE(m) [dict setObject: m forKey: @"NSFileType"]; break  
    switch (st.st_mode & S_IFMT) {
      case S_IFREG: SET_MODE (NSFileTypeRegular);     
      case S_IFDIR: SET_MODE (NSFileTypeDirectory);      
      case S_IFCHR: SET_MODE (NSFileTypeCharacterSpecial);      
      case S_IFBLK: SET_MODE (NSFileTypeBlockSpecial);
      case S_IFLNK: SET_MODE (NSFileTypeSymbolicLink);
      case S_IFIFO: SET_MODE (NSFileTypeFifo);
      case S_IFSOCK: SET_MODE (NSFileTypeSocket);
      default: SET_MODE (NSFileTypeUnknown);
    }

    [dict setObject: [NSNumber numberWithUnsignedLongLong: st.st_size] 
             forKey: @"NSFileSize"];
    [dict setObject: [NSNumber numberWithUnsignedLong: (st.st_mode & ~S_IFMT)] 
             forKey: @"NSFilePosixPermissions"];
    [dict setObject: [NSNumber numberWithUnsignedLong: st.st_uid] 
             forKey: @"NSFileOwnerAccountID"];
    [dict setObject: [NSString stringWithFormat: @"%d", st.st_uid] 
             forKey: @"NSFileOwnerAccountName"];
    [dict setObject: [NSNumber numberWithUnsignedLong: st.st_gid] 
             forKey: @"NSFileGroupOwnerAccountID"];
    [dict setObject: [NSString stringWithFormat: @"%d", st.st_gid] 
             forKey: @"NSFileGroupOwnerAccountName"];
    [dict setObject: [NSNumber numberWithUnsignedInt: st.st_nlink] 
             forKey: @"NSFileReferenceCount"];
    [dict setObject: [NSNumber numberWithUnsignedInt: st.st_dev] 
             forKey: @"NSFileDeviceIdentifier"];
    [dict setObject: [NSNumber numberWithUnsignedLong: st.st_ino] 
             forKey: @"NSFileSystemFileNumber"];
    
    return dict;
    
  } else if ([url isEqual: baseurl] && (errno == EINVAL)) { 
    return [NSDictionary dictionaryWithObject: NSFileTypeDirectory 
                                       forKey: @"NSFileType"];
  } 
  
  return nil;
}

- (BOOL)fileExistsAtUrl:(NSString *)url 
{
  return [self fileExistsAtUrl: url isDirectory: NULL];
}

- (BOOL)fileExistsAtUrl:(NSString *)url 
            isDirectory:(BOOL *)isDirectory
{
  struct stat st;

  if (smbc_stat([url cString], &st) == 0) {
    if (isDirectory) {
      *isDirectory = ((st.st_mode & S_IFMT) == S_IFDIR);
    }
    return YES;
  } else if ([url isEqual: baseurl] && (errno == EINVAL)) { 
    *isDirectory = YES;
    return YES;
  }
  
  return NO;
}

- (BOOL)isReadableFileAtUrl:(NSString *)url 
{
  struct stat st;

  if (smbc_stat([url cString], &st) == 0) {
    return (((st.st_mode & ~S_IFMT) & S_IRUSR) == S_IRUSR);
  }

  return NO;
}

- (BOOL)isWritableFileAtUrl:(NSString *)url 
{
  struct stat st;

  if (smbc_stat([url cString], &st) == 0) {
    return (((st.st_mode & ~S_IFMT) & S_IWUSR) == S_IWUSR);
  }

  return NO;
}

- (BOOL)isExecutableFileAtUrl:(NSString *)url 
{
  struct stat st;

  if (smbc_stat([url cString], &st) == 0) {
    return (((st.st_mode & ~S_IFMT) & S_IXUSR) == S_IXUSR);
  }

  return NO;
}

- (BOOL)isDeletableFileAtUrl:(NSString *)url 
{
  struct stat st;

  if ([url isEqual: baseurl] == NO) {
    NSString *parenturl = [url stringByDeletingLastUrlPathComponent];
    
    if (smbc_stat([parenturl cString], &st) == 0) {
      return (((st.st_mode & ~S_IFMT) & S_IWUSR) == S_IWUSR);
    }
  }

  return NO;
}

- (BOOL)changeFileAttributes:(NSDictionary *)attributes 
                       atUrl:(NSString *)url 
{
/*                                                 */
/* smbc_chmod() is not implemented in libsmbclient */
/*                                                 */

  return YES;

/*
  id entry;
  unsigned long	num;
  NSDate *date;
  NSString *str;
  BOOL allOk = YES;

  if (attributes == nil) {
    return YES;
  }

  allOk = YES;

  entry = [attributes objectForKey: @"NSFilePosixPermissions"];
  if (entry) {
    num = [entry longValue];
    
    if (smbc_chmod([url cString], num) != 0) {
	    allOk = NO;
	    str = [NSString stringWithFormat:
	              @"Unable to change NSFilePosixPermissions to '%o' - %s", 
                                                      num, strerror(errno)];
	    ASSIGN(lastError, str);
	  }
  }

  date = [attributes objectForKey: @"NSFileModificationDate"];
  if (date) {
    BOOL ok = NO;
    struct stat st;

    if (smbc_stat([url cString], &st) != 0) {
	    ok = NO;
	  } else {
  //    time_t ub[2];

	//    ub[0] = sb.st_atime;
	//    ub[1] = [date timeIntervalSince1970];
	//    ok = (utime((char *)cpath, ub) == 0);
    }
    
    if (ok == NO) {
	    allOk = NO;
      str = [NSString stringWithFormat:
	                @"Unable to change NSFileModificationDate to '%@' - %s",
	                                                    date, strerror(errno)];
      ASSIGN(lastError, str);
	  }
  }

  return allOk;
*/
}

- (BOOL)createFileAtUrl:(NSString *)url 
               contents:(NSData *)contents 
             attributes:(NSDictionary *)attributes
{
// int smbc_creat(const char *furl, mode_t mode);

  return NO;
}

- (BOOL)createDirectoryAtUrl:(NSString *)url 
                  attributes:(NSDictionary *)attributes
{
  if (smbc_mkdir([url cString], 0644) == 0) {
    return YES;
  } else {
    ASSIGN(lastError, ([NSString stringWithFormat:
                                 @"Could not create directory at: %@", url]));
  }
  
  return NO;
}

- (BOOL)copyUrl:(NSString *)source 
          toUrl:(NSString *)destination
        handler:(id)handler
{
  NSDictionary *attrs;
  NSString *fileType;

  attrs = [self fileAttributesAtUrl: source traverseLink: NO];
  if (attrs == nil) {
    return NO;
  }
  
  fileType = [attrs fileType];

  if ([fileType isEqual: NSFileTypeDirectory]) {
    if ([[destination stringByAppendingString: @"/"]
	                    hasPrefix: [source stringByAppendingString: @"/"]]) {
	    return NO;
	  }
    
    [self sendToHandler: handler willProcessUrl: destination];

    if ([self createDirectoryAtUrl: destination attributes: attrs] == NO) {
      return [self proceedAccordingToHandler: handler
					                          forError: lastError 
                                       atUrl: destination
					                          fromPath: source 
                                      toPath: destination];
	  }

    if ([self copyDirectoryContentsAtUrl: source 
                                   toUrl: destination 
                                 handler: handler] == NO) {
	    return NO;
	  }

  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
    NSString *s = [NSString stringWithFormat: 
                    @"'%@' symbolik links not supported by samba", fileType];

    return [self proceedAccordingToHandler: handler
					                        forError: s 
                                     atUrl: destination
					                        fromPath: source 
                                    toPath: destination];

  } else {
    [self sendToHandler: handler willProcessUrl: source];

    if ([self copyFileContentsAtUrl: source 
                              toUrl: destination 
                            handler: handler] == NO) {
	    return NO;
	  }
  }

  [self changeFileAttributes: attrs atUrl: destination];
  
  return YES;
}

- (BOOL)moveUrl:(NSString *)source 
          toUrl:(NSString *)destination 
        handler:(id)handler
{     
  if (smbc_rename([source cString], [destination cString]) == 0) {
    return YES;
  }

  return NO;
}

- (BOOL)removeFileAtUrl:(NSString *)url 
                handler:(id)handler
{
  struct stat st;
  BOOL isdir;

  [self sendToHandler: handler willProcessUrl: url];

  if (smbc_stat([url cString], &st) != 0) {
    return NO;
  }
  
  isdir = ((st.st_mode & S_IFMT) == S_IFDIR);

  if (isdir == NO) {
    if (smbc_unlink([url cString]) < 0) {
    
      NSLog(@"REMOVE %@ FAILED %s", url, strerror(errno));
    
      return [self proceedAccordingToHandler: handler
	                  forError: [NSString stringWithCString: strerror(errno)]
	                     atUrl: url];
    } else {
      return YES;
    }

  } else {
    NSArray *contents = [self directoryContentsAtUrl: url];
    unsigned count = [contents count];
    unsigned i;

    for (i = 0; i < count; i++) {
	    CREATE_AUTORELEASE_POOL (arp);
	    NSString *item = [contents objectAtIndex: i];
	    NSString *next = [url stringByAppendingUrlPathComponent: item];
	    BOOL result = [self removeFileAtUrl: next handler: handler];
	    RELEASE(arp);

      if (result == NO) {
	      return NO;
	    }
    }

    if (smbc_rmdir([url cString]) < 0) {
    
      NSLog(@"REMOVE %@ FAILED %s", url, strerror(errno));
          
      return [self proceedAccordingToHandler: handler
	                  forError: [NSString stringWithCString: strerror(errno)]
	                     atUrl: url];
	  } else {
	    return YES;
	  }
  }
  
  return NO;
}

- (BOOL)removeFileAtUrl:(NSString *)url
{
  return (smbc_unlink([url cString]) >= 0);
}

- (BOOL)removeDirectoryAtUrl:(NSString *)url
{
  return (smbc_rmdir([url cString]) >= 0);
}

- (BOOL)copyFileContentsAtUrl:(NSString *)source
	                      toUrl:(NSString *)destination
	                    handler:(id)handler
{
  NSDictionary *attributes;
  SMBFileHandle *srcHandle;
  SMBFileHandle *dstHandle;
  int bufsize = 8096;
  char buffer[bufsize];
  int fileSize;
  int rbytes;
  int wbytes;
  int i;

  NSAssert1([self fileExistsAtUrl: source],
                      @"source file '%@' does not exist!", source);
 
  attributes = [self fileAttributesAtUrl: source traverseLink: NO];
  NSAssert1(attributes, @"could not get the attributes for file '%@'", source);

  fileSize = [attributes fileSize];

  srcHandle = [SMBFileHandle fileHandleForReadingAtUrl: source];
  if (srcHandle == nil) {
    return [self proceedAccordingToHandler: handler
				                          forError: @"cannot open file for reading"
				                             atUrl: source
				                          fromPath: source
				                            toPath: destination];
  }

  dstHandle = [SMBFileHandle fileHandleForWritingAtUrl: destination];
  if (dstHandle == nil) {
    [srcHandle closeFile];
    return [self proceedAccordingToHandler: handler
				                          forError: @"cannot open file for writing"
				                             atUrl: destination
				                          fromPath: source
				                            toPath: destination];
  }

  for (i = 0; i < fileSize; i += rbytes) {
    rbytes = [srcHandle read: buffer length: bufsize];

    if (rbytes < 0) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      return [self proceedAccordingToHandler: handler
				                            forError: @"cannot read from file"
				                               atUrl: source
				                            fromPath: source
				                              toPath: destination];
	  }
      
    wbytes =  [dstHandle write: buffer length: rbytes];

    if (wbytes != rbytes) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      return [self proceedAccordingToHandler: handler
				                            forError: @"cannot write to file"
				                               atUrl: destination
				                            fromPath: source
				                              toPath: destination];
    }
  }

  [srcHandle closeFile];
  [dstHandle closeFile];

  return YES;
}

- (BOOL)copyDirectoryContentsAtUrl:(NSString *)source
	                           toUrl:(NSString *)destination
	                         handler:(id)handler
{
  SMBDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  CREATE_AUTORELEASE_POOL (pool);

  enumerator = [self enumeratorAtUrl: source];

  while ((dirEntry = [enumerator nextObject])) {
    NSString *sourceFile;
    NSString *fileType;
    NSString *destinationFile;
    NSDictionary *attributes;

    sourceFile = [source stringByAppendingUrlPathComponent: dirEntry];
    destinationFile = [destination stringByAppendingUrlPathComponent: dirEntry];
    
    attributes = [self fileAttributesAtUrl: sourceFile traverseLink: NO];
    fileType = [attributes fileType];

    [self sendToHandler: handler willProcessUrl: sourceFile];

    if ([fileType isEqual: NSFileTypeDirectory]) {
	    if ([self createDirectoryAtUrl: destinationFile 
                          attributes: attributes] == NO) {

        if ([self proceedAccordingToHandler: handler
				                           forError: lastError
				                              atUrl: destinationFile
				                           fromPath: sourceFile
				                             toPath: destinationFile] == NO) {
          RELEASE (pool);
          return NO;
        }
      } else {
	      [enumerator skipDescendents];
        
	      if ([self copyDirectoryContentsAtUrl: sourceFile
                                       toUrl: destinationFile
                                     handler: handler] == NO) {
          RELEASE (pool);                           
		      return NO;
        }
      }
      
    } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if ([self copyFileContentsAtUrl: sourceFile
			                          toUrl: destinationFile
		                          handler: handler] == NO) {
        RELEASE (pool);                           
	      return NO;
      }

    } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
	    NSString *s = [NSString stringWithFormat: 
                  @"'%@' symbolik links not supported by samba", fileType];
	    ASSIGN(lastError, s);
	    NSLog(@"%@: %@", sourceFile, s);
	    continue;

    } else {
	    NSString *s = [NSString stringWithFormat: @"cannot copy file type '%@'", fileType];
	    ASSIGN(lastError, s);
	    NSLog(@"%@: %@", sourceFile, s);
	    continue;
    }
  }
  
  RELEASE (pool);
  
  return YES;
}

- (SMBDirectoryEnumerator *)enumeratorAtUrl:(NSString *)url
{
  return AUTORELEASE ([[SMBDirectoryEnumerator alloc] 
                          initWithDirectoryUrl: url  smbFileManager: self]);
}

- (void)sendToHandler:(id)handler
       willProcessUrl:(NSString *)url
{
  if (handler && [handler respondsToSelector: 
                                @selector (smbFileManager:willProcessUrl:)]) {
    [handler smbFileManager: self willProcessUrl: url];
  }
}

- (BOOL)proceedAccordingToHandler:(id)handler
                         forError:(NSString *)error
                            atUrl:(NSString *)url
{
  if (handler && [handler respondsToSelector:
                    @selector (smbFileManager:shouldProceedAfterError:)]) {
    NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                              url, @"url",
                                                          error, @"error", nil];
    return [handler smbFileManager: self shouldProceedAfterError: errorInfo];
  }
  
  return NO;
}

- (BOOL)proceedAccordingToHandler:(id)handler
                         forError:(NSString *)error
                            atUrl:(NSString *)url
                         fromPath:(NSString *)fromPath
                           toPath:(NSString *)toPath
{
  if (handler && [handler respondsToSelector:
                        @selector (smbFileManager:shouldProceedAfterError:)]) {
    NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                            url, @"url",
                                                      fromPath, @"frompath",
                                                            toPath, @"topath",
                                                          error, @"error", nil];
    return [handler smbFileManager: self shouldProceedAfterError: errorInfo];
  }
  
  return NO;
}

@end


@implementation SMBDirectoryEnumerator

- (void)dealloc
{
  RELEASE (topPath);
  RELEASE (stack);
  TEST_RELEASE (currentFilePath);

  [super dealloc];
}

- (id)initWithDirectoryUrl:(NSString *)url 
            smbFileManager:(SMBFileManager *)amanager;
{
  self = [super init];

  if (self) {
    NSArray *contents;
    
    manager = amanager;
    stack = [NSMutableArray new];
    ASSIGN (topPath, simplifyUrl(url));
    currentFilePath = nil;
    
    contents = [manager directoryContentsAtUrl: topPath];

    if (contents) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
      [dict setObject: contents forKey: @"contents"];
      [dict setObject: topPath forKey: @"dirname"];
      [dict setObject: [NSNumber numberWithInt: 0] forKey: @"index"];
      
      [stack addObject: dict];
    } else {
      NSLog(@"Failed to recurse into directory '%@'", topPath);
      RELEASE (self);
      return nil;
    }
  }
    
  return self;
}

- (NSString *)nextObject
{
  NSString *retFileName = nil;
  
  DESTROY (currentFilePath);

  while ([stack count] > 0) {
    NSMutableDictionary *dirdict = [stack objectAtIndex: 0];
    NSString *dirname = [dirdict objectForKey: @"dirname"];
    NSArray *contents = [dirdict objectForKey: @"contents"];
    int index = [[dirdict objectForKey: @"index"] intValue];
  
    if (index < [contents count]) {
      NSString *fname = [contents objectAtIndex: index];
      BOOL isdir = NO;
      
      if ([dirname isEqual: topPath] == NO) {
        retFileName = [dirname stringByAppendingString: @"/"];
        retFileName = [retFileName stringByAppendingString: fname];
	    } else {
        retFileName = fname;
      }

      ASSIGN (currentFilePath, [topPath stringByAppendingUrlPathComponent: retFileName]);

      if ([manager fileExistsAtUrl: currentFilePath 
                       isDirectory: &isdir] && isdir) {
        NSArray *contents = [manager directoryContentsAtUrl: currentFilePath];

        if (contents) {
          NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
          [dict setObject: contents forKey: @"contents"];
          [dict setObject: retFileName forKey: @"dirname"];
          [dict setObject: [NSNumber numberWithInt: 0] forKey: @"index"];
      
          [stack insertObject: dict atIndex: 0];
		    } else {
		      NSLog(@"Failed to recurse into directory '%@'", currentFilePath);
		    }
      }

      index++;
      [dirdict setObject: [NSNumber numberWithInt: index] forKey: @"index"];
      
      break;
      
    } else {
      [stack removeObjectAtIndex: 0];
      DESTROY (currentFilePath);
    }
  }
  
  return retFileName;
}

- (void)skipDescendents
{
  if ([stack count] > 0) {
    [stack removeObjectAtIndex: 0];
    DESTROY (currentFilePath);
  }
}

@end

