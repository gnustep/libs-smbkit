/* SMBKit.h
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

#ifndef SMBKIT_H
#define SMBKIT_H

#include <Foundation/Foundation.h>
#include <libsmbclient.h>

@class SMBFileManager;

@interface SMBKit: NSObject
{
}

+ (BOOL)initlibsmbc;

+ (BOOL)registerManager:(SMBFileManager *)amanager;

+ (void)unregisterManager:(SMBFileManager *)amanager;

+ (SMBFileManager *)managerWithAddress:(NSString *)address;

@end

@interface NSString (smbUrl)

- (NSString *)pathPartOfSmbUrl;

- (NSString *)stringByPrependingUrlPrefix;

- (NSString *)lastUrlPathComponent;

- (NSString *)urlPathExtension;

- (NSString *)stringByAppendingUrlPathComponent:(NSString *)aString;

- (NSString *)stringByAppendingUrlPathExtension:(NSString *)aString;

- (NSString *)stringByDeletingLastUrlPathComponent;

- (NSString *)stringByDeletingUrlPathExtension;

@end


void auth_fn(const char *server, const char *share,
	     char *workgroup, int wgmaxlen, char *username, int unmaxlen,
	     char *password, int pwmaxlen);

BOOL parse_url(char *url,
		   int *server_i, int *server_len,
		   int *share_i, int *share_len,
		   int *path_i, int *path_len,
		   int *username_i, int *username_len,
		   int *password_i, int *password_len);
       
void simplify_url(char *url);

NSString *simplifyUrl(NSString *url);

NSDictionary *urlDictionary(NSString *url);


extern NSString *SMBNotificationKey;
extern NSString *SMBFileHandleOperationException;
extern NSString *SMBFileHandleNotificationError;
extern NSString *SMBFileHandleReadCompletionNotification;
extern NSString *SMBFileHandleDataAvailableNotification;
extern NSString *SMBFileHandleWriteCompletionNotification;
extern NSString *SMBFileHandleNotificationDataItem;

#endif // SMBKIT_H

