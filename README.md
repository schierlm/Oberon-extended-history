# The Experimental Oberon operating system
Experimental Oberon is a revision of the Original Oberon operating system (www.projectoberon.com), containing:

* continuous fractional line scrolling with variable line spaces
* multiple logical displays ("virtual displays")
* safe module unloading
* system building tools

*Note:* The latest version of Experimental Oberon is always at http://github.com/andreaspirklbauer/Oberon-experimental. All other repositories at http://github.com/andreaspirklbauer are just a series of small experiments that people are free to use, but without ANY guarantee that they will be kept current or in sync with Experimental Oberon.

------------------------------------------------------

# Instructions for converting an existing Original Oberon system to Experimental Oberon

**NOTE**: If you run Oberon in an emulator (e.g., https://github.com/pdewacht/oberon-risc-emu), you can simply backup your existing S3RISCinstall directory, download the compressed archive [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz) from this repository (containing Experimental Oberon) to your emulator directory, run the command *tar xvzf S3RISCinstall.tar.gz* in that directory and then restart the emulator, instead of going through the instructions outlined below.

------------------------------------------------------

**PREREQUISITES**: A working Original Oberon 2013 operating system and compiler, current as of November 11, 2017 or later (see www.inf.ethz.ch/personal/wirth/news.txt for the change log of the Original Oberon 2013 operating system and the Oberon compiler). If you run an older version of Original Oberon 2013, please upgrade to the latest version first.

------------------------------------------------------

**STEP 1**: Download and import the Experimental Oberon files to your Original Oberon system

Download all files from the [**Sources**](Sources/) directory of this repository. Convert the *source* files to Oberon format (Oberon uses CR as line endings) using the command [**dos2oberon**](dos2oberon), also available in this repository (example shown for Linux or MacOS):

     for x in *.Mod *.Tool ; do ./dos2oberon $x $x ; done

Import the files to your Oberon system. If you use an emulator, click on the *PCLink1.Run* link in the *System.Tool* viewer, copy the files to the emulator directory, and execute the following command on the command shell of your host system:

     cd oberon-risc-emu
     for x in *.Mod *.Tool *.Scn.Fnt ; do ./pcreceive.sh $x ; sleep 1 ; done

Open the Experimental Oberon version of the [**System.Tool**](Sources/System.Tool) viewer in the system track of your Original Oberon system, so that you can directly activate the compilations needed to build Experimental Oberon:

     System.Open System.Tool

------------------------------------------------------

**STEP 2:** Build a cross-development toolchain by compiling the "new" compiler and boot linker/loader on the "old" system

     ORP.Compile ORS.Mod/s ORB.Mod/s ~
     ORP.Compile ORG.Mod/s ORP.Mod/s ~
     ORP.Compile Boot.Mod/s ~
     System.Free ORP ORG ORB ORS Boot ~

------------------------------------------------------

**STEP 3:** Use the cross-development toolchain on your Original Oberon system to build Experimental Oberon

Compile the *inner core* of Experimental Oberon and load it onto the boot area of the local disk:

     ORP.Compile Kernel.Mod FileDir.Mod Files.Mod Modules.Mod ~    # modules for the "regular" boot file for Experimental Oberon
     Boot.Link Modules ~                                           # generate a pre-linked binary file of the "regular" boot file (Modules.bin)
     Boot.Load Modules.bin ~                                       # load the "regular" boot file onto the boot area of the local disk

This step is possible, because module *Boot* is written such that it can be executed on both the Original Oberon 2013 and the Experimental Oberon system. It produces output using the Experimental Oberon module and object file format.

Compile the remaining modules of Experimental Oberon:

     ORP.Compile Input.Mod Display.Mod/s Viewers.Mod/s ~
     ORP.Compile Fonts.Mod/s Texts.Mod/s Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod/s TextFrames.Mod/s ~
     ORP.Compile System.Mod/s Edit.Mod/s Tools.Mod/s ~

Re-compile the Oberon compiler itself before (!) restarting the system:

    ORP.Compile ORS.Mod/s ORB.Mod/s ORG.Mod/s ORP.Mod/s ORTool.Mod/s Boot.Mod/s ~

The last step is necessary because Experimental Oberon uses a different Oberon object file format (the currently loaded Experimental Oberon compiler runs under Original Oberon, but wouldn't be able to execute under Experimental Oberon).

------------------------------------------------------

**STEP 4:** Restart the Oberon system

You are now running Experimental Oberon. Re-compile any other modules that you may have on your system.
