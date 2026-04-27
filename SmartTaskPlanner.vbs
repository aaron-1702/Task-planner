Dim fso, scriptDir, ps1Path, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\SmartTaskPlanner_Launcher.ps1"
cmd = "powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File """ & ps1Path & """"
CreateObject("WScript.Shell").Run cmd, 0, False
