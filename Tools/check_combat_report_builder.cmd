@echo off
if not exist "%~dp0..\debug_exports\logs" mkdir "%~dp0..\debug_exports\logs"
"D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path "%~dp0.." --log-file "%~dp0..\debug_exports\logs\combat_report_builder.log" --quit-after 30 res://Tests/scenes/combat_report_builder_check.tscn
