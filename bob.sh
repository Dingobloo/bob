#!/bin/bash
#
# This is a sketch of an experimental design for a build system where project definitions are written in C.
# The build system is packaged as a single shell script which contains the C library code as a heredoc string.
# The shell script creates a concatenation from the library code and the file specified as the first command line argument.
# Then that is compiled with the system's C compiler and the result is run, which takes any required build-related actions.
# For this toy implementation, that means running gcc directly, but it could also just generate makefiles like premake.
#
# Note that using some tricks you can write a single file that is both a valid Unix shell script and Windows batch file,
# which combined with cross-platform code for the C library would allow a portable single-file build system solution.
#
# Example usage:
#
# Suppose you have a C project with source files bar.c and baz.c and you want to build an executable called foo.
#
# Create foo.bob:
#
# void setup() {
#     c_executable("foo");
#     source("bar.c");
#     source("baz.c");
# }
#
# Command line transcript:
# 
# $ ./bob.sh foo
# PROJECT: foo
# INFO:    Compiling C executable 'foo'
# COMMAND: gcc -o foo bar.c baz.c
#
# $ ./foo
# STUFF

set -e

tmp_c=$(mktemp /tmp/bob-XXXXX.c)
tmp_exe=${tmp_c%.c}

exec 3>$tmp_c
rm $tmp_c

bob_c=$(cat <<END
#line 42 "bob.sh"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *strf(char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    size_t size = vsnprintf(NULL, 0, fmt, args) + 1;
    char *str = malloc(size);
    vsnprintf(str, size, fmt, args);
    va_end(args);
    return str;
}

void vmsg(char *kind, char *fmt, va_list args) {
    printf("%s: %*s", kind, strlen(kind) <= 7 ? 7 - strlen(kind) : 0, "");
    vprintf(fmt, args);
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
    vmsg("ERROR", fmt, args);
    va_end(args);
    exit(1);
}

void info(char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vmsg("INFO", fmt, args);
    va_end(args);
}

int run(char *str) {
    msg("COMMAND", "%s", str);
    return system(str);
}

typedef struct {
    void *data;
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

void compile_c_executable(char *target, file_list_t *sources) {
    char *cmd = strf("gcc -o %s", target);
    for (size_t i = 0; i < sources->num_files; i++)
        cmd = strf("%s %s", cmd, sources->files[i]);
    if (run(cmd) != 0) error("Compilation failed.");
}

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
    msg("PROJECT", "%s", project->name);
    if (project->type == C_EXECUTABLE) {
        info("Compiling C executable '%s'", project->name);
        if (project->sources.num_files == 0) error("No source files specified.");
        compile_c_executable(project->name, &project->sources);
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

void setup();

int main(int argc, char **argv) {
    project_t default_project;
    project_init(&default_project);
    this_project = &default_project;
    setup();
    project_build(this_project);
    return 0;
}

END
)

echo "$bob_c" >&$tmp_c
echo "#line 0 \"$1.bob\"" >>$tmp_c
cat $1.bob >>$tmp_c

gcc -o $tmp_exe $tmp_c

eval $tmp_exe

rm $tmp_exe
