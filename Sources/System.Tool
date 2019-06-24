System.Open ^ System.Recall System.Flush System.Watch System.Collect
Edit.Open ^  Edit.Recall                            System.ShowDisplays
Edit.ChangeFont Oberon8.Scn.Fnt            System.OpenDisplay name
Edit.ChangeFont Oberon10i.Scn.Fnt         System.SetDisplayName 1 new
Edit.ChangeFont Oberon10b.Scn.Fnt        System.SetDisplay 1
Edit.ChangeFont Oberon12.Scn.Fnt          System.CloseDisplay 1
Edit.ChangeFont Oberon16.Scn.Fnt          System.NextDisplay
Edit.ChangeFont Times24.Scn.Fnt             System.PrevDisplay

System.Directory ^
  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc  *.bin  *.mem

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^/s ORP.Compile ~
System.Free ~  # free modules as a group, /f hides modules if refs exist
System.Open Draw.Tool
System.CopyFiles ~
System.RenameFiles ~         Stars.Open Stars.Run System.Free Stars~
System.DeleteFiles ~           "13.ShowModules"  "*tars.Stop"

System.ShowModules  System.ShowCommands ^  Modules.Collect
System.ShowImports ORP~     System.ShowRefs Hilbert Sierpinski ~
System.ShowClients Oberon~  System.ShowGroupRefs Hilbert Viewers ~
                                
PCLink1.Run  PCLink1.Stop    Oberon0Tool.Run  Oberon0Tool.Stop  # run only of of these 2
Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open
Tools.Inspect 0  Tools.Sector 1  Tools.ShowFile
Tools.Recall  Tools.Clear

# ------------ building the system ----------------

ORP.Compile ORS.Mod/s ORB.Mod/s ~         Edit.Open Build.Tool ~
ORP.Compile ORG.Mod/s ORP.Mod/s ~
ORP.Compile Boot.Mod/s ORTool.Mod/s ~
System.Free ORTool Boot ORP ORG ORB ORS ~

ORP.Compile Kernel.Mod/s FileDir.Mod/s Files.Mod/s Modules.Mod/s ~
Boot.Link Modules ~            # generate a regular boot file
Boot.Load Modules.bin ~     # load the boot file onto the boot area

ORP.Compile Input.Mod Display.Mod/s Viewers.Mod/s ~
ORP.Compile Fonts.Mod/s Texts.Mod/s ~
ORP.Compile Oberon.Mod/s ~                      Edit.Open Oberon.Mod
ORP.Compile MenuViewers.Mod/s ~             Edit.Open MenuViewers.Mod
ORP.Compile TextFrames.Mod/s ~                Edit.Open TextFrames.Mod
ORP.Compile System.Mod/s ~                       Edit.Open System.Mod
ORP.Compile Edit.Mod/s Tools.Mod/s ~        Edit.Open Edit.Mod

ORP.Compile PCLink1.Mod/s Clipboard.Mod Out.Mod ~
ORP.Compile RS232.Mod/s SCC.Mod/s Net.Mod/s ~

ORP.Compile Graphics.Mod/s GraphicFrames.Mod/s ~
ORP.Compile GraphTool.Mod MacroTool.Mod/s Draw.Mod ~

ORP.Compile Curves.Mod/s Sierpinski.Mod ~
ORP.Compile Hilbert.Mod Stars.Mod ~
ORP.Compile Rectangles.Mod/s Checkers.Mod ~
ORP.Compile Math.Mod/s PIO.Mod/s Blink.Mod/s ~
