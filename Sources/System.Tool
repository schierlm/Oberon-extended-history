System.Open ^ System.Recall System.Flush System.Watch System.Collect
Edit.Open ^  Edit.Recall                           System.ShowDisplays
Edit.ChangeFont Oberon8.Scn.Fnt           System.OpenDisplay name
Edit.ChangeFont Oberon10i.Scn.Fnt        System.SetDisplayName 1 new
Edit.ChangeFont Oberon16.Scn.Fnt         System.SetDisplay 1
Edit.ChangeFont Times24.Scn.Fnt            System.CloseDisplay 1

System.Directory ^
  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc  *.Boot *.Boot0

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^/s ORP.Compile ~
System.Free ~  # free modules as a group, /f hides modules if refs exist
System.Open Draw.Tool
System.CopyFiles ~                System.RunInit System ~
System.RenameFiles ~         Stars.Open Stars.Run System.Free Stars~
System.DeleteFiles ~           "13.ShowModules"  "*tars.Stop"

System.ShowModules  System.ShowCommands ^  Modules.Collect
System.ShowImports ORP~ System.ShowRemovableImports ORP~
System.ShowClients Oberon~ System.ShowRemovableClients Oberon~

PCLink1.Run
Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open
Tools.Inspect 0  Tools.Sector 1  Tools.ShowFile
Tools.Recall  Tools.Clear

# ------------ rebuilding the system ----------------

ORP.Compile ORS.Mod/s ORB.Mod/s ~
ORP.Compile ORG.Mod/s ORP.Mod/s ~
ORP.Compile Boot.Mod/s ~                               Edit.Open Boot.Tool ~
System.Free ORP ORG ORB ORS Boot ~

ORP.Compile Kernel.Mod/s FileDir.Mod/s Files.Mod/s Modules.Mod/s ~
Boot.Link  Modules  RISC2013.Boot ~
Boot.Load  RISC2013.Boot ~                    

ORP.Compile Input.Mod Display.Mod/s Viewers.Mod/s ~
ORP.Compile Fonts.Mod/s Texts.Mod/s ~
ORP.Compile Oberon.Mod/s ~                      Edit.Open Oberon.Mod
ORP.Compile MenuViewers.Mod/s ~             Edit.Open MenuViewers.Mod
ORP.Compile TextFrames.Mod/s ~                Edit.Open TextFrames.Mod
ORP.Compile System.Mod/s ~                       Edit.Open System.Mod
ORP.Compile Edit.Mod/s Tools.Mod/s ~        Edit.Open Edit.Mod

ORP.Compile ORS.Mod/s ORB.Mod/s ORG.Mod/s ORP.Mod/s ORTool.Mod/s ~

ORP.Compile Boot.Mod/s BootLoad.Mod BootLoadDisk.Mod ~
ORP.Compile PCLink1.Mod RS232.Mod Clipboard.Mod ~
ORP.Compile SCC.Mod/s Net.Mod/s ~

ORP.Compile Graphics.Mod/s ~  ORP.Compile GraphicFrames.Mod/s ~
ORP.Compile GraphTool.Mod Draw.Mod ~

ORP.Compile Curves.Mod/s ~                  ORP.Compile Sierpinski.Mod ~
ORP.Compile Hilbert.Mod Stars.Mod ~   ORP.Compile Blink.Mod ~
ORP.Compile Rectangles.Mod/s Checkers.Mod ~
