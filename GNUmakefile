
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

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

