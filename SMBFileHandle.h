/* SMBFileHandle.h
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

#ifndef SMB_FILE_HANDLE_H
#define SMB_FILE_HANDLE_H

#include <Foundation/Foundation.h>

@interface SMBFileHandle: NSObject <RunLoopEvents>
{
  int descriptor;

  NSMutableDictionary	*readInfo;
  int readMax;
  NSMutableArray *writeInfo;
  int writePos;
  
  BOOL closeOnDealloc;
  BOOL readOK;
  BOOL writeOK;
}

+ (id)fileHandleForReadingAtUrl:(NSString *)url;

+ (id)fileHandleForWritingAtUrl:(NSString *)url;

- (id)initForReadingAtUrl:(NSString *)url;

- (id)initForWritingAtUrl:(NSString *)url;

- (id)initWithFileDescriptor:(int)desc 
              closeOnDealloc:(BOOL)flag;
       
- (void)closeFile;
              
- (int)read:(void *)buf length:(int)len;              
              
- (void)checkRead;

- (NSData *)readDataOfLength:(unsigned)len;

- (NSData *)readDataToEndOfFile;

- (NSData *)availableData;

- (void)readInBackgroundAndNotify;

- (void)watchReadDescriptor;

- (void)ignoreReadDescriptor;

- (void)postReadNotification;

- (BOOL)readInProgress;

- (int)write:(const void *)buf length:(int)len;

- (void)checkWrite;

- (void)writeData:(NSData *)item;

- (void)writeInBackgroundAndNotify:(NSData *)item;

- (void)watchWriteDescriptor;

- (void)ignoreWriteDescriptor;

- (void)postWriteNotification;

- (BOOL)writeInProgress;

- (void)receivedEvent:(void *)data
		             type:(RunLoopEventType)type
	              extra:(void *)extra
	            forMode:(NSString *)mode;

- (NSDate *)timedOutEvent:(void *)data
		                 type:(RunLoopEventType)type
		              forMode:(NSString *)mode;

@end

#endif // SMB_FILE_HANDLE_H

