# Experimental Oberon (full version)
This is the **full** version of Experimental Oberon. It is **not** backward compatible with the Original Oberon operating system (2013 Edition, www.projectoberon.com). *All* changes of the following document are implemented.

**Documentation:** [**DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf**](Documentation/DIFFERENCES-between-Experimental-Oberon-and-Original-Oberon.pdf)

To access the **reduced** version of Experimental Oberon (which **is** backward compatible with Original Oberon), please refer to the following repository: **http://www.github.com/andreaspirklbauer/Oberon-experimental-reduced**

------------------------------------------------------

**DEMO VIDEOS** (if you see an error message "Sorry about that, but we can’t show files that are this big right now" or similar, click on the "Raw" button on the page showing the error message to download the file to your computer)

**Demo video 1:** [**DemoMultipleVirtualDisplays.mov**](Documentation/DemoMultipleVirtualDisplays.mov)

**Demo video 2:** [**DemoFractionalLineScrollVariableLineSpace.mov**](Documentation/DemoFractionalLineScrollVariableLineSpace.mov)

**Demo video 3:** [**DemoCloningViewersIntoNewVirtualDisplays.mov**](Documentation/DemoCloningViewersIntoNewVirtualDisplays.mov)

------------------------------------------------------

**COMPRESSED ARCHIVE** of Experimental Oberon for the Oberon emulator (if you see an error message "Sorry about that, but we can’t show files that are this big right now" or similar, click on the "Raw" button on the page showing the error message to download the file to your computer)

**Compressed archive of the S3RISCinstall directory (for emulator):** [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz)

------------------------------------------------------

# Instructions for converting an existing Original Oberon system to Experimental Oberon (full)

**PREREQUISITES**: A working Original Oberon operating system and compiler, current as of July 5, 2016 or later (see projectoberon.com). If you run an older version of Original Oberon or the compiler, please upgrade to the latest version first.

**STEP 1**: Download the following files from the [**Sources**](Sources/) directory of this repository to your Oberon system (these are the files that have been added or have changed relative to Oberon 2013):


     Display.Mod
     Viewers.Mod
     Oberon.Mod
     MenuViewers.Mod
     TextFrames.Mod
     System.Mod
     Edit.Mod
     ORG.Mod              (!)
     Tools.Mod
     GraphicFrames.Mod
     Draw.Mod
     Linker.Mod
     Builder.Mod
     BootLoad.Mod
     Clipboard.Mod        (optional, from https://github.com/pdewacht/oberon-risc-emu)
     System.Tool          (optional, recommended)
     Times24.Scn.Fnt      (optional)
     Sierpinksi.Mod       (optional)
     Hilbert.Mod          (optional)
     Stars.Mod            (optional)
     Checkers.Mod         (optional)

If you want, you can download additional versions of module *TextFrames* (all compatible with Experimental Oberon):

     TextFramesOrig.Mod              # The Original Oberon version of TextFrames (slightly adapted for Experimental Oberon)
     TextFramesSimple.Mod            # Adds *simple* continuous line scrolling (only full but no fractional lines displayed)
     TextFramesAbsoluteMargins.Mod   # Uses absolute margins and coordinates of visible area (X1, Y1, x, y, w, h, x1, y1)

After completing the steps described below (steps 2 - 10), you can switch between the various versions of *TextFrames* by simply recompiling the version that you want (there is *no* need to edit any files, just run ORP.Compile *filename* and it will create a new object file *TextFrames.rsc* and possibly a new *TextFrames.smb*) and all the client modules that depend on *TextFrames*, e.g. modules *System* and *Edit*. See [**Sources/System.Tool**](Sources/System.Tool) for the correct compilation order.

------------------------------------------------------

**STEP 2**: Download the following files from the [**Sources**](Sources/) directory of this repository or from the Oberon 2013 repository (available online at http://www.projectoberon.com) to your Oberon system, if you don't have them on your Oberon system yet (no changes will be made to these files, they'll just need to be recompiled):

     Kernel.Mod
     FileDir.Mod
     Files.Mod
     Modules.Mod
     Input.Mod
     Fonts.Mod
     Texts.Mod
     ORS.Mod
     ORB.Mod
     ORP.Mod
     ORTool.Mod
     Graphics.Mod
     GraphTool.Mod
     PCLink1.Mod          (optional, needed if you use an Oberon emulator on a host system)

**Note**: If you run Oberon in an emulator on a host system (e.g., using **https://github.com/pdewacht/oberon-risc-emu**), first download the files listed in steps 1 and 2 to your host system (into directory *oberon-risc-emu*), start the Oberon emulator on your host system, click on the *PCLink1.Run* link in the *System.Tool* viewer within Oberon, and execute the following command on the command shell of your host system (example shown for Linux or MacOS):

     cd oberon-risc-emu
     for x in *.Mod ; do ./pcreceive.sh $x ; sleep 1 ; done
     ./pcreceive.sh System.Tool
     ./pcreceive.sh Times24.Scn.Fnt

------------------------------------------------------

**STEP 3:** Recompile module *ORG* of the Oberon compiler (increases the constant maxCode from 8000 to 12000). This is needed in order to be able to compile large modules such as TextFrames. The symbol file of ORG will not change. If necessary, also compile the other modules of the compiler (ORS, ORB and ORP).

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

     ORP.Compile Viewers.Mod/s Input.Mod Display.Mod/s ~
     ORP.Compile Fonts.Mod Texts.Mod ~
     ORP.Compile Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod/s ~
     ORP.Compile TextFrames.Mod/s ~             # for this line you'll need the new ORG
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
     ORP.Compile GraphicFrames.Mod/s ~
     ORP.Compile GraphTool.Mod Draw.Mod ~

------------------------------------------------------

**STEP 9:** Restart the Oberon system

------------------------------------------------------

**STEP 10**: Enjoy Experimental Oberon (full version).

     


