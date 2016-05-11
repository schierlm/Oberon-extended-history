MODULE Blink;   (*NW 30.5.13 / AP 12.12.15*)
  IMPORT SYSTEM, Tasks;
  VAR z: INTEGER;
    T: Tasks.Task;
  
  PROCEDURE Run*;
  BEGIN Tasks.Install(T)
  END Run;

  PROCEDURE Stop*;
  BEGIN Tasks.Remove(T)
  END Stop;

  PROCEDURE Tick;
  BEGIN z := 1-z; LED(z)
  END Tick;

BEGIN z := 0; T := Tasks.NewTask(Tick, 500)
END Blink.

