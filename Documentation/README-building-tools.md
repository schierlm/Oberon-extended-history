#Building tools for Oberon 2013
Rudimentary version of the "building tools" for Oberon 2013 (http://www.projectoberon.com), as described in the book "Project Oberon".

    BootLoad.Mod         ... a boot loader that reads a "boot file" from a valid boot source into main memory
    Linker.Mod           ... a linker that generates a prelinked binary file containing a valid "boot file"
    Builder.Mod          ... a tool to establish the preconditions for the regular boot process on a bare machine

------------------------------------------------------

1. Generating and installing the Oberon "boot loader" in the permanent read-only memory of the system
-----------------------------------------------------------------------------------------------------

**Background**

When the power to a computer is turned on or the reset button is pressed, the computer's "boot firmware" is activated. The boot firmware is a small program stored in permanent, nonvolatile memory such as a standard read-only memory (ROM) or a field-programmable read-only memory (PROM), which is part of the computer's hardware. The boot firmware is therefore permanently present even when the computer is turned off. In computer jargon, the permanent, nonvolatile memory that holds the boot firmware is sometimes called the "platform flash".

Upon starting or resetting the computer, the boot firmware is usually first copied from the permanent, nonvolatile memory into main memory, typically a random-access memory (RAM) in the case of a regular computer or a block random-access memory (BRAM) in the case of an field programmable gate array (FPGA) development board, before it is executed there as the very first program to run on the bare metal.

In many computer systems, the boot firmware often loads another, separate program called the "boot loader" which then loads the operating system. However, in Oberon the boot firmware and the boot loader are one and the same program, and therefore the boot firmware stored in permanent, nonvolatile memory is itself called the "boot loader".

In principle, a boot loader can be any program that initiates the booting process of a computer. The *Oberon* boot loader, as usually implemented, has two primary responsibilities: It loads a file called the "boot file" from a valid boot source into main memory and it then jumps to a specific memory location. Then its job is done until the next time the computer is restarted or the reset button is pressed. The location it jumps to is either hardcoded as part of a branch instruction at the very end of the boot loader's program code or is transmitted as part of the boot file itself, depending on the boot source used and the specific implementation. In Oberon, there are currently two valid boot sources: a local disk (realized using an SD card in Oberon 2013) and a communication channel (a RS-232 serial line in Oberon 2013). The default boot source is the local disk. It is used by the regular Oberon startup process each time the computer is powered on or the reset button is pressed.

The standard Oberon boot loader merely *transfers* the data from the selected boot source into main memory, but does not interpret the boot file data in any way during the boot load phase. In particular, it does *not* initiate the execution of any module initialization bodies of the modules that are typically part of the boot file (as the regular Oberon loader would do). However, the memory location to which the boot loader jumps at the *end* of the boot load phase will typically transfer control to the top module of the module hierarchy contained in the boot file, thereby making it the *only* module in the boot file whose module initialization body is actually executed.

*Format of the Oberon "boot loader" on file and in main memory*

The Oberon boot loader is an example of a "standalone program" that is executed *without* the Oberon core present. Immediately after a system restart or a reset, it is the *only* program present in main memory. In Oberon, such standalone programs have different starting and ending sequences than regular modules. In particular, the *first* location (i.e. at relative address 0 of the program) contains an implicit branch instruction to the program's initialization code which can be anywhere within the program's code block. Thus, such programs can be started by simply branching to the first address of the program once it has been loaded into main memory. The *last* instruction in the program is a branch instruction to (absolute) memory location 0. To generate these modified starting and ending sequences with the Oberon compiler, the program's source code must be marked with an asterisk immediately after the symbol MODULE at the beginning of the program text.

You can also create other small programs using the modified starting sequence. Such programs are able to run on the bare metal where no other software (and therefore also no module loader) is present. They must not import other modules.

**Instructions**

*a. Generating the Oberon "boot loader"*

To generate an Oberon object file containing the Oberon boot loader, first mark the source code of the boot loader with an asterisk immediately after the symbol MODULE at the beginning of the program text:

     MODULE* BootLoad;   (*asterisk indicates that the compiler will generate modified starting and ending sequences*)
       ...
     BEGIN
       ...
     END BootLoad.

Then compile it with the regular Oberon compiler:

     ORP.Compile BootLoad.Mod      ... generates an Oberon object file of the boot loader (BootLoad.rsc)

To convert the Oberon object file generated above into an actual PROM image of the Oberon boot loader that is compatible with the specific hardware being used (a Xilinx *.mem file in the case of Oberon 2013):

     Builder.WriteFile BootLoad.rsc 512 prom.mem      ... generates a PROM image of the boot loader (prom.mem)

The first parameter is the name of the object file of the boot loader, as generated by the compiler. The second parameter is the size of the PROM in words (thus the size of the PROM memory in bytes in the above example is 512 x 4 bytes = 2 KB). The last parameter is the name of the PROM image to be generated.

The command essentially extracts the code block from the input file containing the boot loader and copies it to the PROM image being generated. Depending on the hardware being used, it may also add additional information as required by the hardware manufacturer, but in essence the command simply transfers code from the object file to the PROM image.

*b. Downloading the PROM image of the Oberon "boot loader" into the permanent, read-only memory of the computer*

Downloading the PROM image of the Oberon boot loader into the permanent, read-only memory of the system typically requires the use of proprietary tools from the hardware manufacturer. Oberon 2013 is implemented on a Spartan 3 field programmable gate array (FPGA) development board from Xilinx, Inc. (www.xilinx.com). Therefore, the Xilinx proprietary tools can be used to download the boot loader into the platform flash (PROM) of the FPGA development board. They are not described here further. The reader is referred to the documentation on www.xilinx.com and www.projectoberon.com.

------------------------------------------------------

2. Generating and installing the Oberon "boot file" in a valid boot source location
-----------------------------------------------------------------------------------

**Background**

In general, a "boot file" is any file that can be loaded by the boot loader from a valid boot source into main memory when the power to the system is turned on or when the reset button is pressed.

In Oberon, there are two valid types of boot files. The "regular boot" file is a sequence of bytes read from the boot area of the local disk (sectors 2-63). The "build-up boot" file is a sequence of blocks fetched over a serial link. The default boot source is the local disk. The user can select the alternative boot source (serial link) by setting a hardware switch on the computer before starting the system. The file formats for these two types of boot files are as follows:

*Regular boot file format (used for starting the system from the local disk):*

    BootFile = {byte}

The number of bytes to be read from the boot area of the disk (sectors 2-63) is extracted from a fixed location within the boot area itself (location 16 in the case of Oberon 2013). The destination address is usually a fixed main memory location (typically location 0) which contains a branch instruction to the initialization body of the top module that was loaded as part of the boot file. A typical boot file simply overwrites the main memory area reserved for the operating system.

The prelinked binary file for the "regular" boot file (*Modules.bin*) contains modules *Kernel*, *FileDir*, *Files*, and *Modules*. These four modules are said to constitute the *inner core* of the Oberon system. The top module in this module hierarchy is module *Modules*, and the first instruction in the prelinked binary file is a branch instruction to the initialization code of that module. The prelinked binary file needs to be loaded as a sequence of bytes onto the system disk's boot area once, using the command *Builder.CreateBootTrack* (see below). From there, it will be loaded into main memory to destination location 0 by the boot loader, when the Oberon system is started from the local disk. This is the regular Oberon startup process. After having loaded the regular boot file into main memory, the boot loader terminates with a branch to memory location 0, which transfers control to the just loaded module *Modules*, the regular loader *(the branch instruction from the end of the boot loader - being a standalone program marked with an asterisk in its source code - to memory location 0 is generated by the Oberon compiler; the branch instruction stored at memory location 0 itself is placed there during the boot load phase by whatever is stored in position 0 of the prelinked binary file that constitutes the boot file; the branch instruction at memory location 0 will later again be replaced by yet another branch instruction which will be installed by module System, after it has been loaded by the regular loader later in the Oberon multi-stage booting process).*

*Build-up boot file format (used for starting the system over a serial link):*

    BootFile = {Block}
    Block = size address {byte}

Each block in the boot file is preceded by its size and its destination address in main memory. By convention, the last block is distinguished by *size* = 0. The *address* of the last block is understood to be the memory location that the boot loader will jump to once the boot file has finished loading (in a specific implementation, it can also be hardcoded to a fixed memory location, in which case the last block of the boot file is simply ignored).

The prelinked binary file for the "build-up" boot file (*Oberon0.bin*) contains modules *Kernel*, *FileDir*, *Files*, *Modules*, *RS232*, a special version (depending only on the inner core and producing no textual output) of *PCLink1* and *Oberon0*. These seven modules constitute the inner core *plus* additional facilities for communication. The top module in this module hierarchy is module *Oberon0*, and the first instruction in the prelinked binary file is a branch instruction to the initialization code of that module. The prelinked binary file needs to be made available as a sequence of blocks in the stream format described above on a "host" computer connected to the Oberon system via a data link. From there, it will be fetched by the boot loader over the serial link, when the Oberon system is started over this alternative boot source. This is the "system build" process, where typically the prerequisites for the regular Oberon startup process are initially established. It can also be used for diagnostic or maintenance purposes. The boot loader terminates with a branch to memory location 0, which transfers control to the just loaded module *Oberon0*, a simple command interpreter. Note that this implies that the module initialization bodies of all other modules in the build-up boot file - in particular module *Modules* - are never executed. This is the intended effect, as module *Modules* depends on a working file system - a condition that is typically not yet satisfied when the build-up boot file is loaded over the data link for the very first time.

Once the Oberon boot loader has finished loading the build-up boot file into main memory and has initiated its execution, the now running top module *Oberon0* - a simple command interpreter accepting commands over a communication link (here a RS-232 serial line) - is ready to communicate with a suitable partner program running on the "host" computer. The partner program, for example ORC (for Oberon to RISC Connection), can send commands over the serial link to *Oberon0* running on the Oberon system, which will then execute them there on behalf of the partner program. The *Oberon0* command interpreter provides a wide range of possible commands. For example, there are commands for establishing the prerequisites for the regular Oberon startup process (e.g., creating a file system on the local disk or transferring the modules of the inner and outer core and other needed files from the host system to the local disk of the Oberon system) and further commands for file system, memory and disk inspection. A list of all available *Oberon0* commands is provided in chapter 14 of the book 'Project Oberon', available on on www.projectoberon.com.

*Format of the (prelinked) regular Oberon "boot file" on file and in main memory*

Similar to "standalone" programs (whose source code is marked with an asterisk, see above), prelinked Oberon binary files have different starting and ending sequences than regular (individual) Oberon modules. In particular, the *first* location (i.e. at relative address 0 of the binary file) contains an implicit branch instruction to the module initialization code of the *top* module which can be anywhere within the binary image. Thus, such prelinked binary images can be started by simply branching to the first address of the binary image once it has been loaded into main memory. The *last* instruction in the module exit code of the *top* module is a branch instruction to (absolute) memory location 0. These modified starting and ending sequences are automatically generated by the Oberon linker.

In addition, the format of a prelinked binary - as generated by the command *Linker.Link* - is *defined* to be such that it *exactly* mirrors the standard Oberon main memory layout, starting at memory location 0 (see chapter 8 of the book *Project Oberon* for a detailed description of Oberon's main memory layout). This makes it possible to simply transfer the prelinked boot file byte for byte from a valid boot source into main memory, and then pass control to its top module by branching to main memory location 0 - this is in fact exactly what the Oberon *boot loader* is doing.

**Instructions**

*a. Generating the Oberon "boot file"*

To generate a valid Oberon boot file, first compile the modules that should become part of the new boot file:

    ORP.Compile Kernel.Mod FileDir.Mod Files.Mod Modules.Mod                                     ... modules of "regular" boot file
    ORP.Compile Kernel.Mod FileDir.Mod Files.Mod Modules.Mod RS232.Mod PCLink1.Mod Oberon0.Mod   ... modules of "build-up" boot file

Then link the generated object files together into a single prelinked "binary file" using the Oberon linker:

     Linker.Link Modules      ... generates the prelinked binary file for the "regular" boot file (Modules.bin)
     Linker.Link Oberon0      ... generates the prelinked binary file for the "build-up" boot file (Oberon0.bin)

The name of the *top* module is supplied as a parameter to the *Link* command (either *Modules* or *Oberon0*). The linker will automatically include all modules that are directly or indirectly imported by the top module. It will also place the address of the *end* of the module space that will be used by the linked modules (=the last byte to be read by a loader) in a fixed location within the generated binary file (location 16). In the case of the "regular" boot file - which is loaded onto the local disk's boot area using the command *Builder.CreateBootTrack* (see below) - this information will be used by the boot loader at boot time to determine the number of bytes to be transferred from the boot area into main memory.

*b. Loading the "regular boot file" onto the disk's boot area (sectors 2-63)*

To load a valid regular boot file onto the boot area of the local disk (if you already have a running Oberon system):

     Builder.CreateBootTrack Modules.bin      ... transfers the binary data for the "regular" boot file (Modules.bin) to the disk's boot area

Warning: This command will overwrite the boot area (sectors 2-63) of your *running* Oberon system, so you should create a disk backup before running it. If you use the Oberon emulator on a host computer (e.g., Windows, Mac or Linux), you can create a backup by making a copy of the directory containing the boot image (S3RISCinstall).

*c. Preparing the "build-up boot file" for loading over a serial link*

As mentioned earlier, the build up boot file (*Oberon0.bin*) must be stored in the "stream format" described above (a sequence of blocks, each containing a size and an address, followed by the block itself), and then stored on a "host" system, from where the boot loader can fetch it over a serial link, if the user selected the alternative boot source. This is not described here further.

------------------------------------------------------

3. Changing the module interface of the Oberon *inner core* and preparing the system for a successful restart
-------------------------------------------------------------------------------------------------------------

Special care needs to be taken when the module interface of the *inner core* itself is changed (this should be rare, but may happen nevertheless). In this case, the modules of the inner core *and* all client modules required for a successful restart of the system must be recompiled *before* the system is restarted again.

**STEP 1**: Load the Oberon compiler and modules *Linker* and *Builder* into main memory by starting them (being resident in main memory means that they can be executed at any time later, even after one or more of their imports are recompiled):

     ORP.Compile nonexistingfile                ... loads module ORP and its imports (ORS, ORB, ORG) into main memory
     Linker.Link nonexistingfile                ... loads module Linker into main memory
     Builder.CreateBootTrack nonexistingfile    ... loads module Builder into main memory

**STEP 2**: Change the module interface of any module of the *inner core*. For example, you may change the name of an exported variable or type, or add a new exported procedure to a module of the *inner core*, e.g., module *Files*.

**STEP 3**: Recompile the modules of the *inner core* as needed, taking into account module dependencies. In this example, only modules *Files* and *Modules* need to be recompiled (add the /s compiler option for those modules whose interfaces have changed, to enable the compiler to overwrite an existing symbol file, thereby invalidating clients):

     ORP.Compile Files.Mod/s
     ORP.Compile Modules.Mod

**STEP 4**: Recompile all client modules that have been invalidated by the recompilation of (some or all modules of) the *inner core* and that are required for a successful restart of the system. These are the following modules:

* the *outer core*'s top module (module *Oberon*) and its imports that depend on the *inner core* (modules *Fonts* and *Texts*),
* the tool module *System* and its imports that depend on the *inner core* (modules *MenuViewers* and *TextFrames*), and
* the two additional tool modules *Edit* and *Tools*.

Note that even though some modules imported by the compiler were modified (here *Files*), we can continue to invoke it, since the "old" version of the compiler is still loaded in main memory as a result of step 1 or the compilations of step 3:

     ORP.Compile Texts.Mod/s       ... recompile the modules of the "outer core" that depend on the inner core
     ORP.Compile Fonts.Mod
     ORP.Compile Tasks.Mod
     ORP.Compile Oberon.Mod/s

     ORP.Compile Menuviewers.Mod   ... recompile the tool module System and its imports
     ORP.Compile TextFrames.Mod/s
     ORP.Compile System.Mod

     ORP.Compile Edit.Mod          ... recompile modules Edit and Tools
     ORP.Compile Tools.Mod

**STEP 5**: Recompile the compiler itself. This must be done *before* restarting the computer (attempting to load the compiler *after* the restart without prior recompilation would lead to an error message stating that the compiler depends on imported modules with bad module keys - at which point we would have no way of recompiling the compiler, since the compiler itself is no longer executable). Here, we can still compile the modules of the compiler using the "old" version of the compiler which is still loaded in main memory as a result of step 1 or the compilations of step 3:

     ORP.Compile ORS.Mod/s         ... recompile the modules of the Oberon compiler
     ORP.Compile ORB.Mod/s
     ORP.Compile ORG.Mod/s
     ORP.Compile ORP.Mod
     ORP.Compile ORTool.Mod

**STEP 6**: Create a new regular boot file from the compiled object files of the *inner core*. Note that even though some modules imported by the linker were modified (here *Files*), we can continue to use it, since the "old" version of module *Linker* is still loaded in main memory as a result of step 1:

     Linker.Link Modules                      ... generates the new "regular" boot file containing modules Kernel, FileDir, Files and Modules

**STEP 7**: Load the new regular boot file onto the disk's boot area (sectors 2-63). Note that even though some modules imported by module *Builder* were modified (here *Files*), we can continue to use it, since the "old" version of module *Builder* is still loaded in main memory as a result of step 1:

     Builder.CreateBootTrack Modules.bin   ... writes the new boot file (Modules.bin) to the disk's boot area (sectors 2-63)

**STEP 8**: Restart or reset the computer. This will cause the boot loader to load the newly installed boot file from the disk's boot area into main memory, after which the new *inner core* (with the new module interfaces) will be operational.

**STEP 9**: Recompile any other client modules of the inner core or outer core that you may have on your Oberon system, e.g. *Draw.Mod*. This can be done either before or after the restart, as these modules are not required for a restart to succeed.

