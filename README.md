# Experimental Oberon
Various simplifications, generalizations and enhancements of functionality, the module structure and the boot process of the Original Oberon operation system (2013 Edition, www.projectoberon.com).

**Documentation:** [**DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf**](Documentation/DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf)

**Compressed archive of the S3RISCinstall directory (for emulator):** [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz)

**Demo video 1:** [**DemoMultipleVirtualDisplays.mov**](Documentation/DemoMultipleVirtualDisplays.mov)

**Demo video 2:** [**DemoFractionalLineScrollVariableLineSpace.mov**](Documentation/DemoFractionalLineScrollVariableLineSpace.mov)

Click on the "Raw" button to download the file to your computer if Github doesn't let you display the videos in the browser.

------------------------------------------------------

# Instructions for converting an existing Original Oberon system to Experimental Oberon

**PREREQUISITES**: A working Original Oberon system and compiler, current as of May 9, 2016 or later (see projectoberon.com). If you run an older version of Original Oberon or the compiler, please upgrade to the latest version first.

**STEP 1**: Download the following files from the [**Sources**](Sources/) directory of this repository to your Oberon system (these are the files that have been added or have changed relative to Oberon 2013):

     Modules.Mod
     Display.Mod
     Viewers.Mod
     Cursors.Mod
     Tasks.Mod
     Oberon.Mod
     MenuViewers.Mod
     TextViewers.Mod
     System.Mod
     ORG.Mod              (!)
     Edit.Mod
     Tools.Mod
     PCLink1.Mod
     Linker.Mod
     Builder.Mod
     BootLoad.Mod
     GraphicViewers.Mod
     Draw.Mod
     Clipboard.Mod
     System.Tool          (optional)
     Times24.Scn.Fnt      (optional)

------------------------------------------------------

**STEP 2**: Download the following files from the [**Sources**](Sources/) directory of this repository or from the Oberon 2013 repository (available online at http://www.projectoberon.com) to your Oberon system, if you don't have them on your Oberon system yet (no changes will be made to these files, they'll just need to be recompiled):

     Kernel.Mod
     FileDir.Mod
     Files.Mod
     Input.Mod
     Fonts.Mod
     Texts.Mod
     ORS.Mod
     ORB.Mod
     ORP.Mod
     ORTool.Mod
     Graphics.Mod
     GraphTool.Mod

**Note**: If you run Oberon in an emulator on a host system (e.g., using **https://github.com/pdewacht/oberon-risc-emu**), first download the files listed in steps 1 and 2 to your host system (into directory *oberon-risc-emu*), start the Oberon emulator on your host system, click on the *PCLink1.Run* link in the *System.Tool* viewer within Oberon, and execute the following command on the command shell of your host system (example shown for Linux or MacOS):

     cd oberon-risc-emu
     for x in System.Tool Times24.Scn.Fnt *.Mod ; do ./pcreceive.sh $x ; sleep 1 ; done

------------------------------------------------------

**STEP 3:** Recompile module *ORG* of the Oberon compiler (increases the constant maxCode from 8000 to 12000). This is needed in order to be able to compile large modules such as TextViewers. The symbol file of ORG will not change. If necessary, also compile the other modules of the compiler (ORS, ORB and ORP).

    ORP.Compile ORS.Mod ORB.Mod ~
    ORP.Compile ORG.Mod ~            # sets ORG.maxCode to 12000
    ORP.Compile ORP.Mod ~
    System.Free ORP ORG ORB ORS ~

------------------------------------------------------

**STEP 4:** Compile modules *Linker* and *Builder* and load them into main memory.

    ORP.Compile Linker.Mod/s Builder.Mod/s ~        # also reloads the (new) compiler itself into main memory
    Linker.Link nonexistingfile ~                   # load module Linker into main memory
    Builder.CreateBootTrack nonexistingfile ~       # load module Builder into main memory

------------------------------------------------------

**STEP 5:** Build a new inner core and load it onto the disk's boot area. For details see [**README-building-tools.md**](Documentation/README-building-tools.md). In sum, you need to execute the following commands:

    ORP.Compile Kernel.Mod FileDir.Mod/s ~
    ORP.Compile Files.Mod Modules.Mod/s ~
    Linker.Link Modules ~
    Builder.CreateBootTrack Modules.bin ~

Do not reboot the system just yet!

------------------------------------------------------

**STEP 6:** Recompile the outer core and the remaining modules required to restart the Oberon system (module Oberon and its imports, plus module System and its imports) in the following order, or see [**Sources/System.Tool**](Sources/System.Tool) for the correct compilation order (you can omit the /s after the first compilation):

     ORP.Compile Input.Mod Display.Mod/s ~
     ORP.Compile Cursors.Mod Viewers.Mod/s ~
     ORP.Compile Fonts.Mod Texts.Mod Tasks.Mod/s ~
     ORP.Compile Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod/s ~
     ORP.Compile TextViewers.Mod/s ~             # for this line you'll need the new ORG
     ORP.Compile System.Mod/s ~
     ORP.Compile Edit.Mod/s ~ 
     ORP.Compile Tools.Mod ~

*Note:* It may happen that the compiler runs out of memory, generating a trap (at least that is the observed behavior when Oberon is run under an emulator). In that case, you may insert the following command after each of the above lines which should remedy the situation:

    System.Collect

------------------------------------------------------

**STEP 7:** Now recompile the *entire* Oberon compiler *before (!)* restarting the system (otherwise you won't be able to execute it after restarting the system due to *invalid module keys* errors):

    ORP.Compile ORS.Mod/s ORB.Mod/s ~
    ORP.Compile ORG.Mod/s ORP.Mod/s ~
    ORP.Compile ORTool.Mod/s ~

------------------------------------------------------

**STEP 8:** You can also recompile a few additional modules at this point (not strictly needed, but good to have them around)

     ORP.Compile PCLink1.Mod RS232.Mod Clipboard.Mod ~
     ORP.Compile Linker.Mod/s Builder.Mod BootLoad.Mod BootLoadDisk.Mod ~

     ORP.Compile Graphics.Mod/s ~
     ORP.Compile GraphicViewers.Mod/s ~
     ORP.Compile GraphTool.Mod Draw.Mod ~

------------------------------------------------------

**STEP 9:** Restart the Oberon system

------------------------------------------------------

**STEP 10**: Enjoy Experimental Oberon. See the document [**DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf**](Documentation/DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf) for a description of the changes relative to Original Oberon.

------------------------------------------------------

# Note regarding backward compatibility of Experimental Oberon with Original Oberon

Experimental Oberon is **not** backward compatible with Original Oberon, as it modifies the inner core, the outer core, the module structure, the module interfaces and the boot process. To download a **backward compatible version** of Experimental Oberon, please refer to the following repository:

**http://www.github.com/andreaspirklbauer/Oberon-multiple-logical-displays-variable-linespace**

This repository contains the code for *fractional line scrolling*, *multiple logical displays* and the Oberon *building tools* **without** sacrificing backward compatibility to Original Oberon. But it does not contain the code for *streamlined viewer message type hierarchy*, *unified viewer concept*, *refined module structure*, *simplified boot process* and the *tools to modify the boot loader and the inner core*.

If you want to test certain **individual features** of Experimental Oberon without sacrificing backward compatibility to Original Oberon, please refer one of the following repositories:

**http://www.github.com/andreaspirklbauer/Oberon-building-tools**
**http://www.github.com/andreaspirklbauer/Oberon-fractional-scroll-fixed-linespace**
**http://www.github.com/andreaspirklbauer/Oberon-fractional-scroll-variable-linespace**
**http://www.github.com/andreaspirklbauer/Oberon-multiple-logical-displays-fixed-linespace**
**http://www.github.com/andreaspirklbauer/Oberon-multiple-logical-displays-variable-linespace**   *(contains the others)*

where the last two repositories also contain the code for fractional line scrolling and the Oberon building tools.

**Note:** To allow the code of the above repositories to coexist in the *same* directory as the files of Original Oberon, rename the downloaded *new* source files to something else (e.g., *Display1.Mod*, *Oberon1.Mod*) and recompile the version that you want before rebooting the system. The compiler will generate the binaries under their *original* names (e.g., *Display.rsc*, *Oberon.rsc*). See the file *System.Tool* of the respective repositories for the correct compilation order (just add an identical section with the new file names).




     


