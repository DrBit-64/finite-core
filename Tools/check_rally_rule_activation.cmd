@echo off
if not exist "%~dp0..\debug_exports\logs" mkdir "%~dp0..\debug_exports\logs"
"D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path "%~dp0.." --log-file "%~dp0..\debug_exports\logs\rally_rule_activation.log" --quit-after 180 res://Tests/scenes/rally_rule_activation_check.tscn
