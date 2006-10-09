
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = SMBKit
LIBRARY_VAR  = SMBKIT
LIBRARY_NAME = libSMBKit

libSMBKit_LIBRARIES_DEPEND_UPON += -lsmbclient

libSMBKit_OBJC_FILES = \
SMBKit.m \
SMBFileManager.m \
SMBFileHandle.m 

libSMBKit_HEADER_FILES = \
SMBKit.h \
SMBFileManager.h \
SMBFileHandle.h

libSMBKit_HEADER_FILES_DIR = .
libSMBKit_HEADER_FILES_INSTALL_DIR=/SMBKit
                        
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble

