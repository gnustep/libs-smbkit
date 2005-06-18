/* SMBFileManager.h
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

#ifndef SMB_FILE_MANAGER_H
#define SMB_FILE_MANAGER_H

#include <Foundation/Foundation.h>

@class SMBDirectoryEnumerator;

@interface SMBFileManager: NSObject
{
  NSString *baseurl;
  NSString *address;
  NSString *usrname;
  NSString *usrpwd;
  NSString *lastError;
}

+ (id)managerForBaseUrl:(NSString *)url
             userName:(NSString *)name
             password:(NSString *)pswd;

- (id)initWithBaseUrl:(NSString *)url
             userName:(NSString *)name
             password:(NSString *)pswd;

- (NSString *)baseUrl;

- (NSString *)address;

- (NSString *)usrname;

- (NSString *)usrpwd;

- (NSArray *)directoryContentsAtUrl:(NSString *)url;

- (NSArray *)subpathsAtUrl:(NSString *)url;

- (NSDictionary *)fileAttributesAtUrl:(NSString *)url 
                         traverseLink:(BOOL)flag;

- (BOOL)fileExistsAtUrl:(NSString *)url;

- (BOOL)fileExistsAtUrl:(NSString *)url 
            isDirectory:(BOOL *)isDirectory;

- (BOOL)isReadableFileAtUrl:(NSString *)url;

- (BOOL)isWritableFileAtUrl:(NSString *)url; 

- (BOOL)isExecutableFileAtUrl:(NSString *)url; 

- (BOOL)isDeletableFileAtUrl:(NSString *)url; 

- (BOOL)changeFileAttributes:(NSDictionary *)attributes 
                       atUrl:(NSString *)url;

- (BOOL)createFileAtUrl:(NSString *)url 
               contents:(NSData *)contents 
             attributes:(NSDictionary *)attributes;

- (BOOL)createDirectoryAtUrl:(NSString *)url 
                  attributes:(NSDictionary *)attributes;

- (BOOL)copyUrl:(NSString *)source 
          toUrl:(NSString *)destination
        handler:(id)handler;

- (BOOL)moveUrl:(NSString *)source 
          toUrl:(NSString *)destination
        handler:(id)handler;

- (BOOL)removeFileAtUrl:(NSString *)url 
                handler:(id)handler;

- (BOOL)removeFileAtUrl:(NSString *)url;

- (BOOL)removeDirectoryAtUrl:(NSString *)url;

- (BOOL)copyFileContentsAtUrl:(NSString *)source
	                      toUrl:(NSString *)destination
	                    handler:(id)handler;

- (BOOL)copyDirectoryContentsAtUrl:(NSString *)source
	                           toUrl:(NSString *)destination
	                         handler:(id)handler;

- (SMBDirectoryEnumerator *)enumeratorAtUrl:(NSString *)url;

- (void)sendToHandler:(id)handler
       willProcessUrl:(NSString *)url;

- (BOOL)proceedAccordingToHandler:(id)handler
                         forError:(NSString *)error
                            atUrl:(NSString *)url;

- (BOOL)proceedAccordingToHandler:(id)handler
                         forError:(NSString *)error
                            atUrl:(NSString *)url
                         fromPath:(NSString *)fromPath
                           toPath:(NSString *)toPath;

@end

@interface NSObject (SMBFileManagerHandler)

- (BOOL)smbFileManager:(SMBFileManager *)fileManager
        shouldProceedAfterError:(NSDictionary *)errorDictionary;

- (void)smbFileManager:(SMBFileManager *)fileManager
        willProcessUrl:(NSString *)url;
     
@end

@interface SMBDirectoryEnumerator: NSObject
{
  NSMutableArray *stack;
  NSString *topPath;
  NSString *currentFilePath;
  SMBFileManager *manager;
}

- (id)initWithDirectoryUrl:(NSString *)url 
            smbFileManager:(SMBFileManager *)amanager;

- (NSString *)nextObject;

- (void)skipDescendents;

@end

#endif // SMB_FILE_MANAGER_H

