:;#!/bin/bash
:;#
:;# This is a sketch of an experimental design for a build system where project definitions are written in C.
:;# The build system is packaged as a single shell script which contains the C library code as a heredoc string.
:;# The shell script creates a concatenation from the library code and the file specified as the first command line argument.
:;# Then that is compiled and the result is run, which takes any required build-related actions; for this toy implementation,
:;# the only build action is running the C compiler directly, but it could also generate makefiles or VS solutions like premake.
:;#
:;# Note that using some tricks you can write a single file that is both a valid Unix shell script and Windows batch file,
:;# which combined with cross-platform code for the C library would allow a portable single-file build system solution.
:;#
:;# Example usage:
:;#
:;# Suppose you have a C project with source files bar.c and baz.c and you want to build an executable called foo.
:;#
:;# Create foo.bob:
:;#
:;# void setup() {
:;#     c_executable("foo");
:;#     sources("bar.c", "baz.c");
:;# }
:;#
:;# Command line transcript:
:;# 
:;# $ ./bob.cmd foo
:;# [PROJECT] foo
:;#           Compiling C executable 'foo'
:;# [COMMAND] gcc -o foo bar.c baz.c
:;#
:;# $ ./foo
:;# STUFF

:<<"::CMDLITERAL"
@echo off

setlocal

set tmp_c=%TEMP%\bob-c.%random%

::CMDLITERAL

:;# Implement goto as a no-op in Shell because it simplifies some escaping.
:;function goto(){
    :;
:;}

:;# What follows has to be on the same line because anything aftwards gets put in the C code
:;# Shell sees the CMD function call as comment up to the end quote
:;# CMD sees the Shell code as an end of line comment
:;# Both are able to share the :END label to end the C code block.

: '
call :heredoc bobc %tmp_c% && goto END &:'; bob_c=$(cat <<:END
#line 1 "bob.c"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iso646.h>
char *strf(char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    size_t size = vsnprintf(NULL, 0, fmt, args) + 1;
    va_end(args);
    char *str = malloc(size);
    va_start(args, fmt);
    vsnprintf(str, size, fmt, args);
    va_end(args);
    return str;
}
void vmsg(char *kind, char *fmt, va_list args) {
    printf("%s%*s", kind, (int)(strlen(kind) <= 10 ? 10 - strlen(kind) : 1), "");
    vprintf(fmt, args);
    //This newline character causes compile errors on a shell with stricter posix compliance
    //ie. calling the script with sh (bash doesnt complain)
    printf("\n");
}
void msg(char *kind, char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vmsg(kind, fmt, args);
    va_end(args);
}
void error(char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vmsg("[ERROR]", fmt, args);
    va_end(args);
    exit(1);
}
void info(char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vmsg("", fmt, args);
    va_end(args);
}
int run(char *str) {
    msg("[COMMAND]", "%s", str);
    return system(str);
}
typedef struct {
    char *data;
    size_t num_items;
    size_t max_items;
} array_t;
void array_init(array_t *array, size_t item_size) {
    array->num_items = 0;
    array->max_items = 16;
    array->data = malloc(array->max_items * item_size);
}
void array_add(array_t *array, void *item_ptr, size_t item_size) {
    if (array->num_items == array->max_items) {
        array->max_items *= 2;
        array->data = realloc(array->data, array->max_items * item_size);
    }
    memcpy(array->data + array->num_items*item_size, item_ptr, item_size);
    array->num_items++;
}
typedef struct {
    union {
        struct {
            char **files;
            size_t num_files;
        };
        array_t files_array;
    };
} file_list_t;
void file_list_init(file_list_t *file_list) {
    array_init(&file_list->files_array, sizeof(char *));
}
void file_list_add(file_list_t *file_list, char *filename) {
    array_add(&file_list->files_array, &filename, sizeof(char *));
}
enum {
    NONE,
    C_EXECUTABLE
};
typedef struct {
    int type;
    char *name;
    file_list_t sources;
} project_t;
void project_init(project_t *project) {
    project->type = NONE;
    project->name = "<unnamed>";
    file_list_init(&project->sources);
}
void project_build(project_t *project) {
    if (project->type == NONE) error("Trying to build project '%s' with no type selected.", project->name);
    msg("[PROJECT]", "%s", project->name);
    if (project->type == C_EXECUTABLE) {
        info("Compiling C executable '%s'", project->name);
        if (project->sources.num_files == 0) error("No source files specified.");
        char *cmd = strf("gcc -o %s", project->name);
        for (size_t i = 0; i < project->sources.num_files; i++)
            cmd = strf("%s %s", cmd, project->sources.files[i]);
        // Uses iso646.h to avoid the not equal operator which interferes with CMD delayed expansion
        if (run(cmd) not_eq 0) error("Compilation failed.");
    }
}
project_t *this_project;
void c_executable(char *name) {
    this_project->type = C_EXECUTABLE;
    this_project->name = name;
}
void source(char *file) {
    file_list_add(&this_project->sources, file);
}
void sources_func(char *file, ...) {
    va_list args;
    va_start(args, file);
    while (file) {
        source(file);
        file = va_arg(args, char *);
    }
    va_end(args);
}
#define sources(...) sources_func(__VA_ARGS__, NULL)
void setup();

int main(int argc, char **argv) {
    //printf("Parameters: ");
    //for(int i=0;i<argc;i++){
        //printf("%s ",argv[i]);
    //}
    //printf("\n");
    project_t default_project;
    project_init(&default_project);
    this_project = &default_project;
    setup();
    project_build(this_project);
	return 0;
}
:END
)

:;# CMD skips to it's own processing from here and Shell ignores it
goto CMDSCRIPT

   #########################################
   ## Shell Script                        ##
   #########################################

set -e

function cleanup {
  rm -f $tmp_c $tmp_exe
}

function findCCompiler() {
    if type gcc > /dev/null ; then
        echo "gcc"
    elif type clang > /dev/null ; then
        echo "clang"
    else
        printf >&2 "[ERROR]   Unable to locate suitable bootstrapping compiler.\n Are gcc or clang in PATH?\n";
        exit 1;
    fi
}

trap cleanup EXIT

#OSX mktemp (At least as of 10.10.5 Yosemite) fails to substitute if the file template also has an extension
#also has no --suffix option, Randomising the extension and telling gcc it's a c file was simplest work around.
#Debian mktemp expects at least 6 X's 
tmp_c=$(mktemp bob-c.XXXXXX)

#Due to the above suffix issues with OSX mktemp we can't base the exe name on the c file
tmp_exe=$(mktemp bob-exe.XXXXXX)

echo "$bob_c" >&$tmp_c
echo "#line 0 \"$1.bob\"" >>$tmp_c
cat $1.bob >>$tmp_c

compiler=$(findCCompiler) 

cat $tmp_c>>"bob.log"

echo "Building with: "$compiler

eval "$compiler -std=c99 -o $tmp_exe -x c $tmp_c"

if [ $? -ne 0 ]; then
    echo "[ERROR]   Bootstrap Compilation failed!"
    exit 1
fi
eval $tmp_exe ${@}

exit 0

:: #########################################
:: ## Command Prompt Script               ##
:: #########################################

:CMDSCRIPT

echo #line 0 "%1.bob" >>%tmp_c%
type %1.bob >>%tmp_c%

set tmp_exe=%TEMP%\bob-exe.%random%.exe

WHERE /q gcc
IF %ERRORLEVEL% EQU 0 ECHO gcc was found 

WHERE /q clang-cl
IF %ERRORLEVEL% EQU 0 ( 
    ECHO clang-cl was found 
    set compiler=clang-cl
    GOTO COMPILE
)

::Use vswhere to get latest installed visual studio directory

    set vswhere_path=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\
    set PATH=%PATH%;%vswhere_path%
    set choco_path=%ProgramData%\chocolatey\bin\
    set PATH=%PATH%;%choco_path%

pushd %CD%
    ::cd /d %vswhere_path%
    for /f "usebackq delims=" %%i in (`vswhere.exe -products * -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set vcpath=%%i
    )
popd

echo Found VC: %vcpath%
set compiler=cl
::Work around the fact that VC 2017 vcvarsall is an alias for the Dev command prompt and messes with working directory
pushd %CD%
    call "%vcpath%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1

    if %errorlevel% NEQ 0 echo [ERROR]   Problem configuring VC environment, unable to successfully run vcvarsall
popd

    :COMPILE

    %compiler% /Tc %tmp_c% /Fe%tmp_exe% /nologo

    if %errorlevel% NEQ 0 (
        echo [ERROR]   Bootstrap Compilation failed!
        exit /b 1   
    )

    %tmp_exe%

    del %tmp_c%
    del %tmp_exe%

    ::Is this one necessary? 
    endlocal

endlocal

:: End of main CMD script
goto :EOF

:: ########################################
:: ## Batch File Heredoc processing code 
:: ## Searches the batch file for the unique ID
:: ## Everything from that ID to end label is echoed into file
:: ########################################
:invokedoc <uniqueIDX>
setlocal enabledelayedexpansion
set go=
for /f "delims=" %%A in ('findstr /n "^" "%~f0"') do (
    set "line=%%A" && set "line=!line:*:=!"
    if defined go (if #!line:~1!==#!go::=! (goto :EOF) else echo(!line!)
    if "!line:~0,13!"=="call :heredoc" (
        for /f "tokens=3 delims=>^ " %%i in ("!line!") do (
            if #%%i==#%1 (
                for /f "tokens=2 delims=&" %%I in ("!line!") do (
                    for /f "tokens=2" %%x in ("%%I") do set "go=%%x"
                )
            )
        )
    )
)
exit /B

::A wrapping function so we do not expose Shell to IO redirection on the single line
:heredoc <iniqueIDX> <filename>
  setlocal  
  call :invokedoc %1 > %~2
  endlocal
exit /B
