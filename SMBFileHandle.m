/* SMBFileHandle.m
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
#include "SMBFileHandle.h"
#include "SMBKit.h"

#define BUFSIZE 4096

@implementation SMBFileHandle

+ (id)fileHandleForReadingAtUrl:(NSString *)url
{
  SMBFileHandle *handle = [[self alloc] initForReadingAtUrl: url];
  
  if (handle) {
    return AUTORELEASE (handle);
  }
  
  return nil;
}

+ (id)fileHandleForWritingAtUrl:(NSString *)url
{
  SMBFileHandle *handle = [[self alloc] initForWritingAtUrl: url];
  
  if (handle) {
    return AUTORELEASE (handle);
  }
  
  return nil;
}

- (void)dealloc
{
  [self ignoreReadDescriptor];
  [self ignoreWriteDescriptor];

  if (descriptor != -1) {
    if (closeOnDealloc == YES) {
	    smbc_close(descriptor);
	    descriptor = -1;
	  }
  }

  TEST_RELEASE (readInfo);
  RELEASE (writeInfo);
  
  [super dealloc];
}

- (id)initForReadingAtUrl:(NSString *)url
{
  int fd = smbc_open([url cString], O_RDONLY, 0666);

  if (fd >= 0) {
    self = [self initWithFileDescriptor: fd closeOnDealloc: YES];
    
    if (self) {
	    writeOK = NO;
      return self;
	  }
  }
  
  return nil;
}

- (id)initForWritingAtUrl:(NSString *)url
{
  int fd = smbc_open([url cString], O_WRONLY | O_CREAT | O_EXCL, 0666);

  if (fd >= 0) {
    self = [self initWithFileDescriptor: fd closeOnDealloc: YES];
    
    if (self) {
	    readOK = NO;
      return self;
	  }
  }
  
  return nil;
}

- (id)initWithFileDescriptor:(int)desc 
              closeOnDealloc:(BOOL)flag
{
  self = [super init];
  
  if (self) {
    struct stat sbuf;

    if (smbc_fstat(desc, &sbuf) < 0) {
      fprintf(stderr, "smbkit: unable to get status of descriptor %d - %s\n", 
                                                    desc, strerror(errno));
      RELEASE (self);
      return nil;
	  } 

    descriptor = desc;
    closeOnDealloc = flag;
    readInfo = nil;
    writeInfo = [NSMutableArray new];
    readMax = 0;
    writePos = 0;
    readOK = YES;
    writeOK = YES;
    
    return self;
  }
    
  return nil;
}

- (void)closeFile
{
  if (descriptor < 0) {
    [NSException raise: SMBFileHandleOperationException
		            format: @"attempt to close closed file"];
  }
  
  [self ignoreReadDescriptor];
  [self ignoreWriteDescriptor];

  (void)smbc_close(descriptor);

  descriptor = -1;
  readOK = NO;
  writeOK = NO;

  if (readInfo) {
    [readInfo setObject: @"File handle closed locally"
                 forKey: SMBFileHandleNotificationError];
    [self postReadNotification];
  }

  if ([writeInfo count]) {
    NSMutableDictionary *info = [writeInfo objectAtIndex: 0];

    [info setObject: @"File handle closed locally"
              forKey: SMBFileHandleNotificationError];
    [self postWriteNotification];
    [writeInfo removeAllObjects];
  }
}

- (int)read:(void *)buf length:(int)len
{
  len = smbc_read(descriptor, buf, len);
  return len;
}

- (void)checkRead
{
  if (readOK == NO) {
    [NSException raise: SMBFileHandleOperationException
                format: @"read not permitted on this file handle"];
  }
  
  if (readInfo) {
    [NSException raise: SMBFileHandleOperationException
                format: @"read already in progress"];
  }
}

- (NSData *)readDataOfLength:(unsigned)len
{
  NSMutableData *d;
  int got;

  [self checkRead];
  
  if (len <= 65536) {
    char *buf;

    buf = NSZoneMalloc(NSDefaultMallocZone(), len);
    d = [NSMutableData dataWithBytesNoCopy: buf length: len];
    
    got = [self read: [d mutableBytes] length: len];
    
    if (got < 0) {
	    [NSException raise: SMBFileHandleOperationException
		              format: @"unable to read from descriptor - %s", strerror(errno)];
	  }
    
    [d setLength: got];
    
  } else {
    char buf[BUFSIZE];

    d = [NSMutableData dataWithCapacity: 0];
    
    do {
	    int	chunk = len > sizeof(buf) ? sizeof(buf) : len;

	    got = [self read: buf length: chunk];
	    
      if (got > 0) {
	      [d appendBytes: buf length: got];
	      len -= got;
	    } else if (got < 0) {
	      [NSException raise: SMBFileHandleOperationException
			              format: @"unable to read from descriptor - %s", strerror(errno)];
	    }
	  } while (len > 0 && got > 0);
  }
  
  return d;
}

- (NSData *)readDataToEndOfFile
{
  char buf[BUFSIZE];
  NSMutableData *d;
  int len;

  [self checkRead];

  d = [NSMutableData dataWithCapacity: 0];
  
  while ((len = [self read: buf length: sizeof(buf)]) > 0) {
    [d appendBytes: buf length: len];
  }

  if (len < 0) {
    [NSException raise: SMBFileHandleOperationException
                format: @"unable to read from descriptor - %s", strerror(errno)];
  }
  
  return d;
}

- (NSData *)availableData
{
  char buf[BUFSIZE];
  NSMutableData *d;
  int len;

  [self checkRead];

  d = [NSMutableData dataWithCapacity: 0];
    
  while ((len = [self read: buf length: sizeof(buf)]) > 0) {
    [d appendBytes: buf length: len];
  }

  if (len < 0) {
    [NSException raise: SMBFileHandleOperationException
                format: @"unable to read from descriptor - %s", strerror(errno)];
  }
  
  return d;
}

- (void)readInBackgroundAndNotify
{
  NSMutableData	*d = [[NSMutableData alloc] initWithCapacity: 0];

  [self checkRead];
  readMax = -1;		
  TEST_RELEASE (readInfo);
  readInfo = [NSMutableDictionary new];
  
  [readInfo setObject: SMBFileHandleReadCompletionNotification
	             forKey: SMBNotificationKey];
         
  [readInfo setObject: d 
               forKey: SMBFileHandleNotificationDataItem];
  RELEASE(d);
  
  [self watchReadDescriptor];
}

- (void)watchReadDescriptor
{
  if (descriptor < 0) {
    return;
  }
    
  [[NSRunLoop currentRunLoop] addEvent: (void*)(gsaddr)descriptor
	                                type: ET_RDESC
	                             watcher: self
	                             forMode: NSDefaultRunLoopMode];
}

- (void)ignoreReadDescriptor
{
  if (descriptor < 0) {
    return;
  }

  [[NSRunLoop currentRunLoop] removeEvent: (void*)(gsaddr)descriptor
		                                 type: ET_RDESC
	                                forMode: NSDefaultRunLoopMode
		                                  all: YES];
}

- (void)postReadNotification
{
  NSMutableDictionary	*info;
  NSNotification *n;
  NSNotificationQueue	*q;
  NSString *name;

  [self ignoreReadDescriptor];
  info = readInfo;
  readInfo = nil;
  readMax = 0;
  name = (NSString *)[info objectForKey: SMBNotificationKey];

  n = [NSNotification notificationWithName: name 
                                    object: self 
                                  userInfo: info];

  RELEASE (info);

  q = [NSNotificationQueue defaultQueue];
  
  [q enqueueNotification: n
	          postingStyle: NSPostASAP
	          coalesceMask: NSNotificationNoCoalescing
		            forModes: nil];
}

- (BOOL)readInProgress
{
  return (readInfo) ? YES : NO;
}

- (int)write:(const void *)buf length:(int)len
{
  len = smbc_write(descriptor, (void *)buf, len);
  return len;
}

- (void)checkWrite
{
  if (writeOK == NO) {
    [NSException raise: SMBFileHandleOperationException
                format: @"write not permitted in this file handle"];
  }
  
  if ([writeInfo count] > 0) {
    id info = [writeInfo objectAtIndex: 0];
    id operation = [info objectForKey: SMBNotificationKey];

    if (operation != GSFileHandleWriteCompletionNotification) {
      [NSException raise: SMBFileHandleOperationException
                  format: @"connect in progress"];
	  }
  }
}

- (void)writeData:(NSData *)item
{
  int rval = 0;
  const void *ptr = [item bytes];
  unsigned int len = [item length];
  unsigned int pos = 0;

  [self checkWrite];

  while (pos < len) {
    int	toWrite = len - pos;

    if (toWrite > BUFSIZE) {
	    toWrite = BUFSIZE;
	  }
    
    rval = [self write: (char*)ptr+pos length: toWrite];
    
    if (rval < 0) {
	    if (errno == EAGAIN || errno == EINTR) {
	      rval = 0;
	    } else {
	      break;
	    }
	  }
    
    pos += rval;
  }
  
  if (rval < 0) {
    [NSException raise: SMBFileHandleOperationException
                format: @"unable to write to descriptor - %s", strerror(errno)];
  }
}

- (void)writeInBackgroundAndNotify:(NSData *)item
{
  NSMutableDictionary *info;

  [self checkWrite];

  info = [NSMutableDictionary new];
  [info setObject: item forKey: SMBFileHandleNotificationDataItem];
  
  [info setObject: GSFileHandleWriteCompletionNotification
		       forKey: SMBNotificationKey];

  [writeInfo addObject: info];
  RELEASE (info);
  
  [self watchWriteDescriptor];
}

- (void)watchWriteDescriptor
{
  if (descriptor < 0) {
    return;
  }
  
  [[NSRunLoop currentRunLoop] addEvent: (void*)(gsaddr)descriptor
		                              type: ET_WDESC
	                             watcher: self
	                             forMode: NSDefaultRunLoopMode];
}

- (void)ignoreWriteDescriptor
{
  if (descriptor < 0) {
    return;
  }

  [[NSRunLoop currentRunLoop] removeEvent: (void*)(gsaddr)descriptor
		                                 type: ET_WDESC
	                                forMode: NSDefaultRunLoopMode
		                                  all: YES];
}

- (void)postWriteNotification
{
  NSMutableDictionary	*info;
  NSNotificationQueue	*q;
  NSNotification *n;
  NSString *name;

  [self ignoreWriteDescriptor];
  info = [writeInfo objectAtIndex: 0];
  name = (NSString*)[info objectForKey: SMBNotificationKey];

  n = [NSNotification notificationWithName: name 
                                    object: self 
                                  userInfo: info];

  writePos = 0;
  [writeInfo removeObjectAtIndex: 0];	

  q = [NSNotificationQueue defaultQueue];
  [q enqueueNotification: n
	          postingStyle: NSPostASAP
	          coalesceMask: NSNotificationNoCoalescing
		            forModes: nil];
                
  if (writeOK && [writeInfo count] > 0) {
    [self watchWriteDescriptor];	
  }
}

- (BOOL)writeInProgress
{
  return ([writeInfo count] > 0) ? YES : NO;
}

- (void)receivedEvent:(void *)data
		             type:(RunLoopEventType)type
	              extra:(void *)extra
	            forMode:(NSString *)mode
{
  NSString *operation;

  if (type == ET_RDESC) {
    operation = [readInfo objectForKey: SMBNotificationKey];
    
    if (operation == SMBFileHandleDataAvailableNotification) {
	    [self postReadNotification];
	  } else {
	    NSMutableData	*item;
	    int length;
	    int received = 0;
	    char buf[BUFSIZE];

	    item = [readInfo objectForKey: SMBFileHandleNotificationDataItem];

	    if (readMax > 0) {
	      length = (unsigned int)readMax - [item length];
        
	      if (length > (int)sizeof(buf)) {
		      length = sizeof(buf);
		    }
      } else {
	      length = sizeof(buf);
	    }

	    received = [self read: buf length: length];
	    
      if (received == 0) { // Read up to end of file.
	      [self postReadNotification];
      } else if (received < 0) {
	      if (errno != EAGAIN && errno != EINTR) {
		      NSString	*s = [NSString stringWithFormat: @"Read attempt failed - %s", strerror(errno)];
          [readInfo setObject: s forKey: SMBFileHandleNotificationError];
		      [self postReadNotification];
		    }
      } else {
	      [item appendBytes: buf length: received];
	      
        if (readMax < 0 || (readMax > 0 && (int)[item length] == readMax)) {
		      [self postReadNotification];
		    }
	    }
	  }
    
  } else {    // ET_WDESC
    NSMutableDictionary	*info = [writeInfo objectAtIndex: 0];
	  NSData *item = [info objectForKey: SMBFileHandleNotificationDataItem];
	  int length = [item length];
	  const void *ptr = [item bytes];

	  if (writePos < length) {
      int	written = [self write: (char*)ptr+writePos length: length-writePos];
      
      if (written <= 0) {
		    if (written < 0 && errno != EAGAIN && errno != EINTR) {
		      NSString	*s = [NSString stringWithFormat: @"Write attempt failed - %s", strerror(errno)];
		      [info setObject: s forKey: SMBFileHandleNotificationError];
		      [self postWriteNotification];
		    }
		  } else {
		    writePos += written;
		  }
    }
	  
    if (writePos >= length) { 
      [self postWriteNotification];
    }
  }
}

- (NSDate *)timedOutEvent:(void *)data
		                 type:(RunLoopEventType)type
		              forMode:(NSString *)mode
{
  return nil;
}

@end
