System.Open ^  System.Recall  System.Watch  System.Collect
Edit.Open ^  Edit.Recall Edit.Locate ^ Edit.Search ^ Test.Init
Edit.ChangeFont Oberon8.Scn.Fnt  System.RunInit Test

Edit.ChangeFont Oberon10i.Scn.Fnt
Edit.ChangeFont Oberon16.Scn.Fnt
Edit.ChangeFont Times24.Scn.Fnt

System.Directory ^ *.Mod *.Bak *.Tool *.Text *.Scn.Fnt *.smb *.txt *.bin

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^ ORP.Compile ^/s
System.Open Draw.Tool ~            System.ThisDisplay
System.Free ~                                System.ShowDisplays
System.CopyFiles ~                        System.NewDisplay Andreas ~
System.RenameFiles ~                  System.CloseDisplay 0 ~
System.DeleteFiles ~                     System.SetDisplay 1 ~
System.ShowModules                   System.SetDisplayName 0 New ~
System.ShowCommands System ~ 

Tools.Inspect 0     Tools.Sector 1     Tools.Recall      Tools.Clear
Tools.ShowFiles    Tools.GCoff         Tools.Read        Tools.Write

PCLink1.Run Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open

# ------------ rebuilding the system ----------------

ORP.Compile Linker.Mod/s Builder.Mod/s ~
ORP.Compile Kernel.Mod FileDir.Mod/s Files.Mod Modules.Mod/s ~ 
Linker.Link Modules ~                             System.RunInit System ~
Builder.CreateBootTrack  Modules.bin ~    System.Open Draw.Tool ~

ORP.Compile Input.Mod Display.Mod/s ~
ORP.Compile Cursors.Mod Viewers.Mod/s ~
ORP.Compile Fonts.Mod Texts.Mod Tasks.Mod/s ~
ORP.Compile Oberon.Mod/s ~             Edit.Open TextViewers.Mod
ORP.Compile MenuViewers.Mod/s ~   ORP.Compile TextViewers.Mod/s ~
ORP.Compile System.Mod/s ~   ORP.Compile Edit.Mod/s ~ 

ORP.Compile ORS.Mod/s ORB.Mod/s ~  ORP.Compile Tools.Mod ~
ORP.Compile ORG.Mod/s ORP.Mod/s ~  ORP.Compile ORTool.Mod ~

ORP.Compile PCLink1.Mod RS232.Mod Clipboard.Mod ~
ORP.Compile Linker.Mod/s Builder.Mod BootLoad.Mod BootLoadDisk.Mod ~

ORP.Compile Graphics.Mod/s ~  ORP.Compile GraphicViewers.Mod/s ~
ORP.Compile GraphTool.Mod Draw.Mod ~

ORP.Compile Curves.Mod/s ~                  ORP.Compile Sierpinski.Mod ~
ORP.Compile Hilbert.Mod Stars.Mod ~   ORP.Compile Blink.Mod ~
ORP.Compile Rectangles.Mod Checkers.Mod ~