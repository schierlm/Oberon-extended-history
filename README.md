# Experimental Oberon (full version)

**Documentation:** [**The-Experimental-Oberon-System.pdf**](Documentation/The-Experimental-Oberon-System.pdf)

**Demo video 1:** 
download: [**DemoMultipleVirtualDisplays.mov**](Documentation/DemoMultipleVirtualDisplays.mov)
Youtube: **https://youtu.be/eLsHM4QncbY**

**Demo video 2:** 
download: [**DemoFractionalLineScrollVariableLineSpace.mov**](Documentation/DemoFractionalLineScrollVariableLineSpace.mov)
Youtube: **https://youtu.be/mXWHtTZL4R0**

**Demo video 3:**
download: [**DemoCloningViewersIntoNewVirtualDisplays.mov**](Documentation/DemoCloningViewersIntoNewVirtualDisplays.mov)
Youtube: **https://youtu.be/t8n_nkuKn3o**

**Compressed archive** of Experimental Oberon (S3RISCinstall directory) for the Oberon emulator: [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz)

*(if you see an error message "Sorry about that, but we can’t show files that are this big right now" or similar, click on the "Raw" button on the page showing the error message to download the file to your computer)*

------------------------------------------------------

# Instructions for converting an existing Original Oberon system to Experimental Oberon (full)

**NOTE**: If you run Oberon in an emulator (e.g., https://github.com/pdewacht/oberon-risc-emu), you can simply backup your existing S3RISCinstall directory, download the compressed archive [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz) from this repository (containing Experimental Oberon) to your emulator directory, run the command *tar xvzf S3RISCinstall.tar.gz* in that directory and then start the emulator, instead of going through the instructions outlined below.

------------------------------------------------------

**PREREQUISITES**: A working Original Oberon 2013 operating system and compiler, current as of September 23, 2017 or later (see www.inf.ethz.ch/personal/wirth/news.txt for the change log of the Oberon system and the compiler). If you run an older version of Original Oberon, please upgrade to the latest version first.

------------------------------------------------------

**STEP 1**: Download the following files from the Original Oberon 2013 repository (available online at http://www.projectoberon.com) to your Oberon system, if you don't have them on your Oberon system yet:

     Kernel.Mod
     FileDir.Mod
     Files.Mod
     Modules.Mod
     Input.Mod
     Display.Mod
     Viewers.Mod
     Fonts.Mod
     Texts.Mod
     Oberon.Mod
     MenuViewers.Mod
     TextFrames.Mod
     System.Mod
     Edit.Mod
     Tools.Mod
     ORS.Mod
     ORB.Mod
     ORG.Mod
     ORP.Mod
     ORTool.Mod
     PCLink1.Mod          (optional, but needed if you use an Oberon emulator on a host system)
     Graphics.Mod         (optional)
     GraphicFrames.Mod    (optional)
     GraphTool.Mod        (optional)
     Draw.Mod             (optional)

**Note**: If you run Oberon in an emulator on a host system (e.g., using **https://github.com/pdewacht/oberon-risc-emu**), first download the files listed above to your host system (into directory *oberon-risc-emu*), start the Oberon emulator on your host system, click on the *PCLink1.Run* link in the *System.Tool* viewer within Oberon, and execute the following command on the command shell of your host system (example shown for Linux or MacOS):

     cd oberon-risc-emu
     for x in *.Mod ; do ./pcreceive.sh $x ; sleep 1 ; done

------------------------------------------------------

**STEP 2**: Download (only) the following files from the [**Sources**](Sources/) directory of this repository to your Oberon system:

     Modules0.Mod        # the "old" module Modules, which just has the new module interface
     Linker0.Mod         # the "old" linker, which uses the "new" module interface of Modules, but outputs binaries in "old" object file format
     Builder.Mod         # system building tools (same in "old" and "new" version)

The files *Modules0.Mod* and *Linker0.Mod* are only used for bootstrapping purposes.

**Note**: Convert these files (except the font file) to Oberon format first (Oberon uses only CR as line endings) using the command **dos2oberon** (also available in the Experimental Oberon repository), before importing the files into Oberon.

     ./dos2oberon Modules0.Mod Modules0.Mod
     ./dos2oberon Linker0.Mod Linker0.Mod
     ./dos2oberon Builder.Mod Builder.Mod

**Note**: If you run Oberon in an emulator on a host system (e.g., using **https://github.com/pdewacht/oberon-risc-emu**), first download the files listed above to your host system (into directory *oberon-risc-emu*), convert them to to Oberon format using the command **dos2oberon** as shown above, start the Oberon emulator on your host system, click on the *PCLink1.Run* link in the *System.Tool* viewer within Oberon, and execute the following command on the command shell of your host system (example shown for Linux or MacOS):

     ./pcreceive.sh Modules0.Mod
     ./pcreceive.sh Linker0.Mod
     ./pcreceive.sh Builder.Mod

------------------------------------------------------

**STEP 3**: Build the linker and builder used for bootstrapping the modified version of the Original Oberon system (using the "old" compiler)

     ORP.Compile Linker0.Mod ~   # generates Linker.smb and Linker.rsc (and NOT Linker0.smb and Linker0.rsc)
     ORP.Compile Builder.Mod

Do NOT compile the file *Modules0.Mod* at this stage!

Note: Even though the source file for the linker is called *Linker0.Mod*, the generated symbol file and executable file are called *Linker* (the module name as specified in the first line of the source file is *Linker*).

------------------------------------------------------

**STEP 4**: The "old" compiler is already loaded (due to the compilations of the previous step). Now load the linker and builder compiled above into main memory as well (being resident in memory on the "old" system means that they can be executed at any time later, even after one or more of their imports are recompiled - as will be the case below):

     Linker.Link nonexistingfile     ... load module Linker (compiled from Linker0.Mod!) into main memory
     Builder.Load nonexistingfile    ... load module Builder into main memory

Do NOT reboot the system just yet!

------------------------------------------------------

**STEP 5**: Prepare a modified version of Original Oberon incorporating the new module interface of module *Modules*

This step merely prepares another version of the Original ("old") Oberon system which incorporates (part of) the "new" module interface of module *Modules*, but still uses the "old" object file format. This is achieved by replacing the source file *Modules.Mod* with the modified file *Modules0.Mod* (used only for this one bootstrapping step) in the compilation and linking sequence below. No other changes are made to the system at this point. In particular, it still runs the Original ("old") Oberon code and uses the Original Oberon ("old") object file format.

Note that only the source file name has changed from *Modules.Mod* to *Modules0.Mod*. The *module name* specified inside the source file has not changed. Thus, compiling *Modules0.Mod* will produce a symbol and object file for *Modules*.

This step is necessary so that we can compile the Experimental Oberon ("new") development tool chain (compiler, linker, builder) - which depend on the "new" module interface of module *Modules* - on the "old" system in subsequent steps.


**Step 5a:** Prepare a modified version of the Oberon *inner core* (old code, old object file format, new interface of *Modules*)

     ORP.Compile Kernel.Mod FileDir.Mod Files.Mod ~ 
     ORP.Compile Modules0.Mod ~   # the Original ("old") Oberon version of module Modules with just the "new" module interface

Do NOT recompile the Original Oberon file *Modules.Mod* at this stage!

**Step 5b:** Link and load the modified version of the Oberon *inner core* onto the boot area of your local disk (using the linker and builder that are still loaded in main memory):

     Linker.Link Modules ~        # create an "old" inner core (Modules.bin) with the new module interface (using the linker that was created from Linker0.Mod))
     Builder.Load Modules.bin ~   # load the inner core onto the boot area of the local disk (module Builder is already loaded)

Do NOT reboot the system just yet!

Note: The command *Linker.Link* used in the above step was generated from the source file *Linker0.Mod*. As its parameter, specify the *module* name "Modules" (without the '0' at the end, *Modules0.Mod* was just the file name).

You have now loaded a modified version of Original Oberon (with the new module interface of module *Modules*) onto the boot area of your system. Rebooting your system at this stage would fail, as all modules that depend on the inner core still import module *Modules* with an old module key. To be able to reboot the modified version of the Original Oberon system, we simply need to compile the remaining modules of the system. This will make them import the modified version of module *Modules* (built from *Modules0.Mod*), allowing them to be loaded on a system running the modified *inner core*.

**Step 5c**: Recompile the remaining modules of the Oberon system:

     ORP.Compile Input.Mod Display.Mod Viewers.Mod ~
     ORP.Compile Fonts.Mod Texts.Mod ~
     ORP.Compile Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod ~
     ORP.Compile TextFrames.Mod ~
     ORP.Compile System.Mod ~
     ORP.Compile Edit.Mod ~
     ORP.Compile PCLink1.Mod Clipboard.Mod ~

Be sure to compile *all* modules of the above list *before* restarting your system! 

**Step 5d**: Recompile the Oberon compiler itself:

     ORP.Compile ORS.Mod ORB.Mod ~  ORP.Compile Tools.Mod ~
     ORP.Compile ORG.Mod ORP.Mod ~  ORP.Compile ORTool.Mod ~

The Oberon compiler itself MUST also be recompiled at this stage (using the original copy that is still loaded in main memory), otherwise you won't be able to load it *after* a system restart.

Optionally, you may also compile any other modules that you may have on your system at this point.

------------------------------------------------------

**STEP 6:** Restart the Oberon system

You are now running a (slightly) modified Original ("old") Oberon 2013 system. The *only* difference to your previous version is that it has the new module interface of module *Modules* (needed for the compilations in subsequent steps). Everything else stays the same. In particular, the Oberon system you are currently running still uses the old Oberon object file format.

Note that the two files *Modules0.Mod* and *Linker0.Mod* are now no longer needed. You can delete them:

     System.DeleteFiles Modules0.Mod Linker0.Mod ~

------------------------------------------------------

**STEP 7**: Download the files of Experimental Oberon

Download the following Experimental Oberon files from the [**Sources**](Sources/) directory of this repository to your Oberon system (these are the files that have been added relative to Original Oberon 2013) - note that this now includes the Experimental ("new") Oberon version of module *Modules* as well:

     Kernel.Mod
     Modules.Mod          (the Experimental ("new") Oberon version of the module loader; uses the new object file format)
     Display.Mod          (the Experimental ("new") Oberon version of module Display; no longer exports a data type 'Frame')
     Viewers.Mod
     Oberon.Mod
     MenuViewers.Mod
     TextFrames.Mod
     System.Mod
     Edit.Mod
     ORG.Mod              (the Experimental ("new") Oberon version of the code generator; generates code in the new object file format)
     Tools.Mod
     GraphicFrames.Mod
     Draw.Mod
     Linker.Mod           (the Experimental ("new") Oberon version of the linker; uses the new object file format)
     Builder.Mod
     BootLoad.Mod
     Clipboard.Mod        (optional)
     System.Tool          (optional, recommended)
     Times24.Scn.Fnt      (optional)
     Curves.Mod           (optional)
     Hilbert.Mod          (optional)
     Stars.Mod            (optional)
     Rectangles.Mod       (optional)
     Checkers.Mod         (optional)
     Sierpinksi.Mod       (optional)

**Note**: Convert these files (except the font file) to Oberon format first (Oberon uses only CR as line endings) using the command **dos2oberon** (also available in the Experimental Oberon repository), before importing the files into Oberon.

     for x in *.Mod ; do ./dos2oberon $x $x ; done
     ./dos2oberon System.Tool System.Tool

**Note**: If you run Oberon in an emulator on a host system (e.g., using **https://github.com/pdewacht/oberon-risc-emu**), first download the files listed above to your host system (into directory *oberon-risc-emu*), convert them to to Oberon format using the command **dos2oberon** as shown above, start the Oberon emulator on your host system, click on the *PCLink1.Run* link in the *System.Tool* viewer within Oberon, and execute the following command on the command shell of your host system (example shown for Linux or MacOS):

     cd oberon-risc-emu
     for x in *.Mod ; do ./pcreceive.sh $x ; sleep 1 ; done
     ./pcreceive.sh System.Tool
     ./pcreceive.sh Times24.Scn.Fnt

Before you continue, open the just downloaded Experimental Oberon version of the **System.Tool** viewer in the system track, using the command

    System.Open System.Tool

so that you can directly access the compilations needed for Experimental Oberon in the right order. You can close the old *System.Tool* viewer.

------------------------------------------------------

**STEP 8:** Recompile the Experimental ("new") Oberon version of the *linker* and *builder* on the "old" system (and still using the "old" compiler) and load them into main memory (of your currently running "old" Original Oberon system).

    ORP.Compile Linker.Mod Builder.Mod ~     # compile the Experimental ("new") Oberon linker (using the "old" compiler)
    System.Free Linker Builder ~             # unload the old linker and builder (just in case they were running for some reason)
    Linker.Link nonexistingfile ~            # load the NEW linker into main memory
    Builder.Load nonexistingfile ~           # load the (recompiled) builder into main memory

You are now running the "new" Oberon linker (which uses in a "new" Oberon object file format) and builder under the "old" Oberon system. It is important that you compile them with the "old" Oberon compiler. Otherwise you couldn't run them here, as we are still running the Original ("old") Oberon system.

Do NOT reboot the system just yet!

------------------------------------------------------

**STEP 9:** Recompile the Experimental ("new") Oberon compiler, unload the old one, and reload the just compiled one

It is *important* that you compile the Experimental ("new") Oberon compiler using the old one, then unload the old compiler and start the new compiler, *before* you compile any other files - as these will *have* to be compiled with the new compiler.

    ORP.Compile ORS.Mod ORB.Mod ~   # generate an Experimental ("new") Oberon compiler that can run on the "old" system
    ORP.Compile ORG.Mod ORP.Mod ~
    System.Free ORP ORG ORB ORS ~   # unload the Original ("old") Oberon compiler that was used to build the new compiler
    ORP.Compile nonexistingfile     # reload the Experimental ("new") Oberon compiler that can run on the "old" system

You are now running the "new" Oberon compiler (which generates output in a "new" Oberon object file format) under the "old" Oberon system. It's a kind of cross-compiler (running itself using the old object file format on the old system, but generating code in the new object file format that is used in Experimental Oberon).

Do NOT recompile the compiler again at this point - it would generate a binary of the same compiler that however uses itself the Experimental ("new") Oberon object file format. It wouldn't be able to be (re-)loaded on your Original ("old") Oberon system that you are still running.

Do NOT reboot the system just yet!

------------------------------------------------------

**STEP 10:** Build the Experimental ("new") Oberon inner core and load it onto the disk's boot area, using the cross-compilation tools that were built and loaded into main memory in steps 8 and 9. For details see [**README-building-tools.md**](Documentation/README-building-tools.md). In sum, you need to execute the following commands:

    ORP.Compile Kernel.Mod/s FileDir.Mod ~
    ORP.Compile Files.Mod Modules.Mod/s ~

In the second *ORP.Compile* command above, be sure to specify "Modules.Mod" (without the '0' at the end)! This will generate a new inner core that is based on the Experimental ("new") Oberon object file format.

    Linker.Link Modules ~
    Builder.Load Modules.bin ~    # load inner core (Modules.bin) onto the boot area of the local disk

You have now loaded an Experimental Oberon *inner core* onto the boot area of your system. Rebooting your system at this stage would fail, as all modules that depend on the inner core are still compiled in the Original Oberon version (and thus import module *Modules* with an old module key). To be able to reboot the Experimental Oberon system, we need to compile the outer core and the remaining modules required to start Experimental Oberon, as shown in the next step.

Do NOT reboot the system just yet!

------------------------------------------------------

**STEP 11:** Recompile the Experimental Oberon version of the outer core and the remaining modules that were downloaded in step 7 and that are required to restart the Experimental Oberon system (module Oberon and its imports, plus module System and its imports) in the following order, or see [**Sources/System.Tool**](Sources/System.Tool) for the correct compilation order (you can omit the /s after the first compilation):

     ORP.Compile Input.Mod Display.Mod/s Viewers.Mod/s ~
     ORP.Compile Fonts.Mod Texts.Mod ~
     ORP.Compile Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod/s ~
     ORP.Compile TextFrames.Mod/s ~
     ORP.Compile System.Mod/s ~
     ORP.Compile Edit.Mod/s ~
     ORP.Compile Tools.Mod ~

*Note:* It may happen that the compiler runs out of memory, generating a trap (at least that is the observed behavior when Oberon is run under an emulator). In that case, you may insert the following command after each of the above lines which should remedy the situation:

    System.Collect

Do NOT reboot the system just yet!

------------------------------------------------------

**STEP 12:** Now recompile the *entire* Oberon compiler **again** *before (!)* restarting the system (otherwise you won't be able to execute it after restarting the system due to *invalid module keys* errors):

    ORP.Compile ORS.Mod/s ORB.Mod/s ~
    ORP.Compile ORG.Mod/s ORP.Mod/s ~
    ORP.Compile ORTool.Mod/s ~

This will generate an Experimental ("new") Oberon compiler which however is now also using the Experimental ("new") Oberon object file format. It can't be executed under the currently running (modified Original Oberon) system, but it will be able to execute once the system is restarted and Experimental Oberon has come up. In the following steps we still use the Experimental compiler that is currently loaded in main memory (so don't unload it!) and which still uses the Original ("old") Oberon object file format.

------------------------------------------------------

**STEP 13:** You can also recompile additional modules at this point (not strictly needed, but good to have them around)

     ORP.Compile PCLink1.Mod RS232.Mod Clipboard.Mod ~
     ORP.Compile Linker.Mod/s Builder.Mod BootLoad.Mod BootLoadDisk.Mod ~

     ORP.Compile Graphics.Mod/s ~
     ORP.Compile GraphicFrames.Mod/s ~
     ORP.Compile GraphTool.Mod Draw.Mod ~

------------------------------------------------------

**STEP 14:** Restart the Oberon system

You are now running Experimental Oberon.

------------------------------------------------------

**STEP 15:** As a test, you can build the entire Oberon system once again, this time already from within Experimental Oberon. If everything goes fine, it should produce the same result as the steps described above.

------------------------------------------------------

**STEP 16**: Enjoy Experimental Oberon (full version).

You can now compile any other modules that you may have on your system, to generate object files that are compatible with Experimental Oberon.

If you haven't done so already, you can now delete the files *Modules0.Mod* and *Linker0.Mod*. These were only needed to bootstrap a slightly modified version of Original Oberon in steps 2-5, starting from an Original Oberon system.
