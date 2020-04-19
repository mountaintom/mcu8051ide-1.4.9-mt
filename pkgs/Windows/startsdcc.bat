@echo off

rem DESCRIPTION:
rem Run SDCC compiler from the IDE silently, i.e. without showing any additional windows.

SETLOCAL ENABLEEXTENSIONS
cd %1
SHIFT

:Loop
IF "%1"=="" GOTO Continue
SET args=%args% %1
SHIFT
GOTO Loop
:Continue

sdcc -mmcs51 %args%
