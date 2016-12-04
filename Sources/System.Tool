System.Open ^ System.Recall System.Flush System.Watch System.Collect
Edit.Open ^  Edit.Recall
Edit.ChangeFont Oberon8.Scn.Fnt           System.ShowDisplays
Edit.ChangeFont Oberon10i.Scn.Fnt        System.OpenDisplay name
Edit.ChangeFont Oberon16.Scn.Fnt         System.SetDisplayName 1 new
Edit.ChangeFont Times24.Scn.Fnt            System.CloseDisplay 1

System.Directory ^
  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^/s ORP.Compile ~
System.Free ~
System.Open Draw.Tool
System.CopyFiles ~
System.RenameFiles ~
System.DeleteFiles ~

System.ShowModules  System.ShowCommands ^  Modules.Collect

PCLink1.Run
Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open

Tools.Inspect 0
Tools.Sector 1
Tools.ShowFile 
Tools.Recall  Tools.Clear

# ------------ rebuilding the system ----------------

ORP.Compile Linker.Mod/s Builder.Mod/s ~
ORP.Compile Kernel.Mod/s FileDir.Mod/s Files.Mod Modules.Mod/s ~
Linker.Link Modules ~                             System.RunInit System ~
Builder.CreateBootTrack  Modules.bin ~    System.Open Draw.Tool ~

ORP.Compile Input.Mod Raster.Mod/s Viewers.Mod/s ~
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
ORP.Compile SCC.Mod/s Net.Mod/s ~

ORP.Compile Graphics.Mod/s ~  ORP.Compile GraphicFrames.Mod/s ~
ORP.Compile GraphTool.Mod Draw.Mod ~

ORP.Compile Curves.Mod/s ~                  ORP.Compile Sierpinski.Mod ~
ORP.Compile Hilbert.Mod Stars.Mod ~   ORP.Compile Blink.Mod ~
ORP.Compile Rectangles.Mod/s Checkers.Mod ~
