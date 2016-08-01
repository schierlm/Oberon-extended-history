System.Open ^  System.Recall  System.Watch  System.Collect
Edit.Open ^  Edit.Recall
Edit.ChangeFont Oberon8.Scn.Fnt
Edit.ChangeFont Oberon10i.Scn.Fnt
Edit.ChangeFont Oberon16.Scn.Fnt
Edit.ChangeFont Times24.Scn.Fnt

System.Directory ^
  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc

ORP.Compile @  ORP.Compile @/s  ORP.Compile name~
System.Free ~
System.Open Draw.Tool
System.CopyFiles ~
System.RenameFiles ~
System.DeleteFiles ~

System.ShowModules  System.ShowCommands ^ 

PCLink1.Run
Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open

Tools.Inspect 0
Tools.Sector 1
Tools.ShowFile 
Tools.Recall  Tools.Clear

# ------------ rebuilding the system ----------------

ORP.Compile Linker.Mod/s Builder.Mod/s ~
ORP.Compile Kernel.Mod FileDir.Mod/s Files.Mod Modules.Mod/s ~ 
Linker.Link Modules ~                             System.RunInit System ~
Builder.CreateBootTrack  Modules.bin ~    System.Open Draw.Tool ~

ORP.Compile Viewers.Mod/s Input.Mod Display.Mod/s ~
ORP.Compile Fonts.Mod Texts.Mod ~
ORP.Compile Oberon.Mod/s ~                      Edit.Open Oberon.Mod
ORP.Compile MenuViewers.Mod/s ~             Edit.Open MenuViewers.Mod
ORP.Compile TextFrames.Mod/s ~                Edit.Open TextFrames.Mod
ORP.Compile System.Mod/s ~                       Edit.Open System.Mod
ORP.Compile Edit.Mod/s ~                            Edit.Open Edit.Mod

ORP.Compile ORS.Mod/s ORB.Mod/s ~  ORP.Compile Tools.Mod ~
ORP.Compile ORG.Mod/s ORP.Mod/s ~  ORP.Compile ORTool.Mod ~

ORP.Compile PCLink1.Mod RS232.Mod Clipboard.Mod ~
ORP.Compile Linker.Mod/s Builder.Mod BootLoad.Mod ~

ORP.Compile Graphics.Mod/s ~  ORP.Compile GraphicFrames.Mod/s ~
ORP.Compile GraphTool.Mod Draw.Mod ~

ORP.Compile Curves.Mod/s ~                  ORP.Compile Sierpinski.Mod ~
ORP.Compile Hilbert.Mod Stars.Mod ~   ORP.Compile Blink.Mod ~
ORP.Compile Rectangles.Mod Checkers.Mod ~
