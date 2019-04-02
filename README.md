# The Experimental Oberon Operating System
Experimental Oberon is a revision of the FPGA Oberon operating system and its compiler (www.projectoberon.com), containing a number of enhancements, including

* Smooth line scrolling with variable line spaces
* Multiple logical displays ("virtual displays")
* Safe module unloading
* System building and maintenance tools
* A compiler for the Revised Oberon-2 programming language (implementing a strict superset of the Oberon-07 language) with various features, including
  * Type-bound procedures
  * Dynamic heap allocation procedure for fixed-length and open arrays
  * Numeric case statement
  * Exporting and importing of string constants
  * Forward references and forward declarations of procedures
  * No access to intermediate objects within nested scopes
  * Module contexts

**DOCUMENTATION**:

| Topic  | Documentation |
| :------------- | :------------- |
| Operating system  | [**The-Experimental-Oberon-System.pdf**](Documentation/The-Experimental-Oberon-System.pdf)  |
| Programming language  | [**The-Revised-Oberon2-Programming-Language.pdf**](Documentation/The-Revised-Oberon2-Programming-Language.pdf)  |
| System building tools  | [**The-Oberon-system-building-tools.pdf**](Documentation/The-Oberon-system-building-tools.pdf)  |
| Safe module unloading  | [**Safe-module-unloading-in-Oberon.pdf**](Documentation/Safe-module-unloading-in-Oberon.pdf) |
| Historical notes on module unloading  | [**Historical-notes-on-module-unloading-in-Oberon.pdf**](Documentation/Historical-notes-on-module-unloading-in-Oberon.pdf)  |
| Symbol files  | [**Streamlining-symbol-files-in-FPGA-Oberon.pdf**](Documentation/Streamlining-symbol-files-in-FPGA-Oberon.pdf)  |

Additional background material can be found in the [**Documentation**](Documentation) directory.

**PREREQUISITES**: A current version of FPGA Oberon 2013 (see http://www.projectoberon.com).

*Note:* The latest version of Experimental Oberon is always at http://github.com/andreaspirklbauer/Oberon-experimental. All other repositories at http://github.com/andreaspirklbauer are just a series of small experiments that people are free to use, but without ANY guarantee that they will be kept current or in sync with Experimental Oberon.

------------------------------------------------------

# Instructions for converting an existing FPGA Oberon system to Experimental Oberon

**NOTE**: If you run Oberon in an emulator (e.g., https://github.com/pdewacht/oberon-risc-emu), you can simply backup your existing S3RISCinstall directory, download the compressed archive [**S3RISCinstall.tar.gz**](Documentation/S3RISCinstall.tar.gz) from this repository (containing Experimental Oberon) to your emulator directory, run the command *tar xvzf S3RISCinstall.tar.gz* in that directory and then restart the emulator, instead of going through the instructions outlined below.

------------------------------------------------------

**STEP 1**: Build a slightly modified Oberon compiler on your FPGA Oberon system

Edit the file *ORG.Mod* on your Original system and set the following constants to the indicated new values:

     CONST ...
       maxCode = 8800; maxStrx = 3200; ...

Then recompile your FPGA Oberon compiler (and unload the old one):

     ORP.Compile ORS.Mod/s ORB.Mod/s ~
     ORP.Compile ORG.Mod/s ORP.Mod/s ~
     System.Free ORP ORG ORB ORS ~

This step is (unfortunately) necessary since the original Oberon-07 compiler has a tick too restrictive constants. To compile Experimental Oberon, one needs slightly more space (in the compiler) for both *code* and *string constants*.

------------------------------------------------------

**STEP 2**: Download and import the Experimental Oberon files to your FPGA Oberon system

Download all files from the [**Sources**](Sources/) directory of this repository. Convert the *source* files to Oberon format (Oberon uses CR as line endings) using the command [**dos2oberon**](dos2oberon), also available in this repository (example shown for Linux or MacOS):

     for x in *.Mod *.Tool ; do ./dos2oberon $x $x ; done

Import the files to your Oberon system. If you use an emulator, click on the *PCLink1.Run* link in the *System.Tool* viewer, copy the files to the emulator directory, and execute the following command on the command shell of your host system:

     cd oberon-risc-emu
     for x in *.Mod *.Tool *.Scn.Fnt ; do ./pcreceive.sh $x ; sleep 0.5 ; done

Open the Experimental Oberon version of the [**System.Tool**](Sources/System.Tool) viewer in the system track of your FPGA Oberon system, so that you can directly activate the compilations needed to build Experimental Oberon:

     System.Open System.Tool

If you just follow the compilation sequence shown in *System.Tool*, you should be done with the remaining steps 3-5 in a few seconds!

------------------------------------------------------

**STEP 3:** Build a cross-development toolchain by compiling the "new" compiler and boot linker/loader on the "old" system

     ORP.Compile ORS.Mod/s ORB.Mod/s ~
     ORP.Compile ORG.Mod/s ORP.Mod/s ~
     ORP.Compile Boot.Mod/s ~
     System.Free ORP ORG ORB ORS Boot ~

------------------------------------------------------

**STEP 4:** Use the cross-development toolchain on your FPGA Oberon system to build Experimental Oberon

Compile the *inner core* of Experimental Oberon and load it onto the boot area of the local disk:

     ORP.Compile Kernel.Mod FileDir.Mod Files.Mod Modules.Mod ~    # modules for the "regular" boot file for Experimental Oberon
     Boot.Link Modules ~                                           # generate a pre-linked binary file of the "regular" boot file (Modules.bin)
     Boot.Load Modules.bin ~                                       # load the "regular" boot file onto the boot area of the local disk

This step is possible, because module *Boot* is written such that it can be executed on both the FPGA Oberon 2013 and the Experimental Oberon system. It produces output using the Experimental Oberon module and object file format.

Compile the remaining modules of Experimental Oberon:

     ORP.Compile Input.Mod Display.Mod/s Viewers.Mod/s ~
     ORP.Compile Fonts.Mod/s Texts.Mod/s Oberon.Mod/s ~
     ORP.Compile MenuViewers.Mod/s TextFrames.Mod/s ~
     ORP.Compile System.Mod/s Edit.Mod/s Tools.Mod/s ~

Re-compile the Oberon compiler itself before (!) restarting the system:

    ORP.Compile ORS.Mod/s ORB.Mod/s ORG.Mod/s ORP.Mod/s ORTool.Mod/s Boot.Mod/s ~

The last step is necessary because Experimental Oberon uses a different Oberon object file format (the currently loaded Experimental Oberon compiler runs under FPGA Oberon, but wouldn't be able to execute under Experimental Oberon).

------------------------------------------------------

**STEP 5:** Restart the Oberon system

You are now running Experimental Oberon. Re-compile any other modules that you may have on your system.
