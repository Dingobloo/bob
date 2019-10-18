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
:;# Shell sees the CMD function call as a line-broken herestring up to the &&
:;# CMD sees the Shell code as an end of line comment
:;# Both are able to share the :END label to end the C code block.

:<<<\
call :heredoc bobc %tmp_c% && goto END &:; bob_c=$(cat <<':END'
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

#line 1 "xcode.c"

#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h> 

typedef struct{
    uint32_t components[4];
} FNVHash128;

typedef struct{
    uint32_t components[3];
}FNVHash96;

//128 bits is 16 bytes (128/8)
const size_t FNV128Bytes = 16;

/* 0x00000000 01000000 00000000 0000013B */
#define FNV128primeX 0x013B
#define FNV128shift 24
/* 0x6C62272E 07BB0142 62B82175 6295C58D */
#define FNV128basis0 0x6C62272E
#define FNV128basis1 0x07BB0142
#define FNV128basis2 0x62B82175
#define FNV128basis3 0x6295C58D

FNVHash128 fnv1a_hash128(const char* cp)
{
    uint64_t   temp[4];
    uint64_t   temp2[2];
    
    FNVHash128 hash;
    hash.components[0] = FNV128basis3;
    hash.components[1] = FNV128basis2;
    hash.components[2] = FNV128basis1;
    hash.components[3] = FNV128basis0;
    
    for ( int i=0; i<FNV128Bytes/4; ++i )
        temp[i] = hash.components[i];
    
    uint8_t ch;
    
	//Despite being writtern in go this was the most helpful piece
	//because it did the 128bit arithmetic in a straightforward manner
	//Reference code from the FNV proposal for 128bit seems faulty.
	//https://github.com/lucas-clemente/fnv128a/blob/master/fnv128a.go
    while ( (ch= (uint8_t)*cp++) )
    {
        temp[0] = temp[0] ^ ch;
        
        temp2[0] = temp[0] << FNV128shift;
        temp2[1] = temp[1] << FNV128shift;

        temp[0] = temp[0] * FNV128primeX;
		temp[1] = temp[1] * FNV128primeX;

        temp[2] = temp[2] * FNV128primeX + temp2[0];
        temp[3] = temp[3] * FNV128primeX + temp2[1];

		// propagate carries
		temp[1] += (temp[0] >> 32);
		temp[2] += (temp[1] >> 32);
		temp[3] += (temp[2] >> 32);

		temp[0] = temp[0] & 0xffffffff;
		temp[1] = temp[1] & 0xffffffff;
		temp[2] = temp[2] & 0xffffffff;
		// temp[3] = temp[3] & 0xffffffff;
        // Doing a temp[3] &= 0xffffffff is not really needed since it simply
        // removes multiples of 2^128.  We can discard these excess bits
        // outside of the loop when writing the hash in Little Endian.
	}
    
    for ( int i=0; i<FNV128Bytes/4; ++i )
        hash.components[i] = temp[i];
    
    return hash;
}
//Xor fold the unused bits to the lower bits as per
//http://www.isthe.com/chongo/tech/comp/fnv/#xor-fold
FNVHash96 XorFold(FNVHash128 hash){
    FNVHash96 rethash = {0};
    for(int i=0;i<3;i++){
        rethash.components[i]=hash.components[i];
    }
    rethash.components[0] = rethash.components[0] ^ hash.components[3];
    
    return rethash;
}

FNVHash96 fnv1a_hash96(const char* data){
    FNVHash128 temphash = fnv1a_hash128(data);
    FNVHash96 rethash = XorFold(temphash);
    return rethash;
}

void WriteProj(FILE* projFile, project_t* bobProject);

void OutputXcodeProj(project_t* bobProject){
    
    if (bobProject->type == NONE) error("Trying to build project '%s' with no type selected.", bobProject->name);
    msg("[PROJECT]", "%s", bobProject->name);
    
    if (bobProject->type == C_EXECUTABLE) {
        info("Exporting Xcode project '%s'", bobProject->name);
        if (bobProject->sources.num_files == 0) error("No source files specified.");

    
        //TODO: free this
        const char *projName = strf("%s%s",bobProject->name,".xcodeproj");
        
        //TODO: fixed size, unacceptable.
        char commandCall[256];
        strcpy(commandCall,"mkdir ");
        strcat(commandCall,projName);
        
        //printf("%s\n",commandCall);
        
        int result = system(commandCall);
        if(result){
            printf("Error creating project file\n");
            return;
        }
        
        strcpy(commandCall,projName);
        strcat(commandCall,"/project.pbxproj");
        
        FILE* ourFile = fopen(commandCall, "w");

        WriteProj(ourFile,bobProject);
        
        fclose(ourFile);
    }
    
}

int indentDepth = 1;
FILE* currentFile = 0;
bool inList = false;
#define XCEL "\n" //just in case

void XCOutputHash96(FNVHash96 out){
    fprintf(currentFile,"%8.8" PRIX32, out.components[2]);
    fprintf(currentFile,"%8.8" PRIX32, out.components[1]);
    fprintf(currentFile,"%8.8" PRIX32, out.components[0]);
}

void XCSetCurrentFile(FILE* file) {
	currentFile = file;
}

void XCTabs() {
	for (int i = 0; i < indentDepth; i++) {
		fprintf(currentFile, "    ");
	}
}

void XCProperty(const char*name, const char* value) {
	XCTabs();
	fprintf(currentFile, "%s = %s;" XCEL,name,value);
}

void XCPropertyHash(const char* name, FNVHash96 value){
    XCTabs();
    fprintf(currentFile,"%s = ", name);
    XCOutputHash96(value);
    fprintf(currentFile, ";" XCEL);
}

void XCStartList(const char* name) {
	XCTabs();
	fprintf(currentFile, "%s = (" XCEL,name);
	indentDepth += 1;
    inList = true;

}

void XCListItem(const char* value) {
	XCTabs();
	fprintf(currentFile, "%s" XCEL, value);
}

void XCEndList() {
    indentDepth-=1;
    XCTabs();
    fprintf(currentFile, ");" XCEL);
    inList = false;
}

void XCStartMap(const char* name){
    XCTabs();
    fprintf(currentFile, "%s = {" XCEL,name);
    indentDepth += 1;
    inList = true;
}

void XCMapItem(const char* name, const char* value){
    XCProperty(name,value);
}
               
void XCMapItemHash(FNVHash96 key, const char* value){
    XCTabs();
    XCOutputHash96(key);
    fprintf(currentFile," = %s;" XCEL,value);
}
               
void XCMapObjectHashStart(FNVHash96 key, const char* comment){
    XCTabs();
    XCOutputHash96(key);
    fprintf(currentFile," /* %s */ = {" XCEL,comment);
    indentDepth+=1;
}

FNVHash96 XCMapObjectStart(const char* name,const char* type){
    const char* refName = strf("%s%s",name,type);
    FNVHash96 refHash = fnv1a_hash96(refName);
    free((void*)refName);
    
    XCMapObjectHashStart(refHash,name);
    //XCProperty("isa", type); //might save time later
    
    return refHash;
}
               
void XCMapObjectEnd(){
    indentDepth-=1;
    XCTabs();
    fprintf(currentFile, "};" XCEL);
    inList = false;
}

void XCEndMap(){
    XCMapObjectEnd();
}

//these are just comments.
void XCSectionStart(const char* sectionName){
    fprintf(currentFile, XCEL);
    fprintf(currentFile,"/* Begin %s section */" XCEL,sectionName);
}

void XCSectionEnd(const char* sectionName){
    fprintf(currentFile,"/* End %s section */" XCEL,sectionName);
}

FNVHash96 WriteFileReference(const char* name, const char* type, const char* path, const char* group){
    const char* hashName = strf("%s%s",name,"PBXFileReference");
    FNVHash96 hash = fnv1a_hash96(hashName);
    free((void*)hashName);
    
    XCMapObjectHashStart(hash,name);
        XCProperty("isa","PBXFileReference");
        XCProperty("explicitFileType",type);
        XCProperty("path",path);
        XCProperty("sourceTree",group);
    XCMapObjectEnd();
    
    return hash;
}

//Calculates the file reference hash based on known string concatonation, might change later.
FNVHash96 WriteBuildFile(const char* fileName){
    const char* fileRefName = strf("%s%s",fileName,"PBXFileReference");
    FNVHash96 fileRefHash = fnv1a_hash96(fileRefName);
    free((void*)fileRefName);
    
    const char* buildFileName = strf("%s%s",fileName,"PBXBuildFile");
    FNVHash96 buildFileHash = fnv1a_hash96(buildFileName);
    free((void*)buildFileName);
    
    XCMapObjectHashStart(buildFileHash,fileName);
        XCProperty("isa","PBXBuildFile");
        XCPropertyHash("fileRef",fileRefHash);
    XCMapObjectEnd();
    
    return buildFileHash;
}

FNVHash96 WriteGroupStart(const char* name){
    const char* groupHashName = strf("%s%s",name,"PBXGroup");
    FNVHash96 groupHash = fnv1a_hash96(groupHashName);
    free((void*)groupHashName);
    
    XCMapObjectHashStart(groupHash,name);
    XCProperty("isa", "PBXGroup");
    XCStartList("children");
    
    return groupHash;
}

void XCListItemHash(FNVHash96 hash, const char* comment){
    XCTabs();
    XCOutputHash96(hash);
    fprintf(currentFile," /* %s */,"XCEL,comment);
}

void XCListItemHashFromFile(const char* name){
    const char* fileRefName = strf("%s%s",name,"PBXFileReference");
    FNVHash96 fileRefHash = fnv1a_hash96(fileRefName);
    free((void*)fileRefName);
    
    XCListItemHash(fileRefHash, name);
}

void WriteGroupEnd(const char* name){
    XCEndList();
    XCProperty("name",name);
    XCProperty("sourceTree","\"<group>\"");
    XCMapObjectEnd();
}

FNVHash96 WriteSourcePhaseStart(const char* name, const char* buildActionMask){
    const char* phaseRefname = strf("%s%s",name,"PBXSourcesBuildPhase");
    FNVHash96 phaseRefHash = fnv1a_hash96(phaseRefname);
    free((void*)phaseRefname);
    
    XCMapObjectHashStart(phaseRefHash,name);
    XCProperty("isa","PBXSourcesBuildPhase");
    XCProperty("buildActionMask",buildActionMask);
    XCStartList("files");
    
    return phaseRefHash;
}

void WriteSourcePhaseEnd(){
    XCEndList();
    XCProperty("runOnlyForDeploymentPostprocessing","0");
    XCMapObjectEnd();
}

FNVHash96 WriteBuildConfiguration(const char* name){
    FNVHash96 result = XCMapObjectStart(name, "XCBuildConfiguration");
        XCProperty("isa","XCBuildConfiguration");
        XCStartMap("buildSettings");
            XCMapItem("CODE_SIGN_STYLE","Automatic");
            XCMapItem("CONFIGURATION_BUILD_DIR","\"$(PROJECT_DIR)\"");
            XCMapItem("PRODUCT_NAME","\"$(TARGET_NAME)\"");
        XCEndMap();
        XCProperty("name",name);
    XCMapObjectEnd();
    
    return result;
}

//Very temporary, we want these configuration lists to likely store
//arbitrary lists, but a pairing is common and is useful for testing.
FNVHash96 WriteConfigListPair(const char* name,
                              FNVHash96 config1, FNVHash96 config2,
                              const char* defaultConfigName)
{
    FNVHash96 result = XCMapObjectStart(name,"XCConfigurationList");
        XCProperty("isa","XCConfigurationList");
        XCStartList("buildConfigurations");
            XCListItemHash(config1, "Configuration 1");
            XCListItemHash(config2, "Configuration 2");
        XCEndList();
        XCProperty("defaultConfigurationIsVisible","0");
        XCProperty("defaultConfigurationName",defaultConfigName);
    XCMapObjectEnd();
    
    return result;
}

FNVHash96 WriteNativeTarget(const char* name, FNVHash96 buildConfigurationList, FNVHash96 productRef, const char* productName, FNVHash96 sourcePhase){
    FNVHash96 result = XCMapObjectStart(name, "PBXNativeTarget");
        XCProperty("isa", "PBXNativeTarget");
        XCPropertyHash("buildConfigurationList",buildConfigurationList);
        XCStartList("buildPhases");
            XCListItemHash(sourcePhase,"Source Phase");
        XCEndList();
    
        XCStartList("buildRules");
        XCEndList();
    
        XCStartList("dependencies");
        XCEndList();
        XCProperty("name", name);
        XCProperty("productName", productName);
        XCPropertyHash("productReference", productRef);
        //hardcoded garbage
        XCProperty("productType","com.apple.product-type.tool");
    XCMapObjectEnd();
    
    return result;
}

//Writes the PBXProject object to the current project file. 
FNVHash96 WriteProject(const char* name,
                       FNVHash96 productRef,
                       FNVHash96 buildConfiguration,
                       FNVHash96 mainGroup, FNVHash96 productGroup)
{
    FNVHash96 projectHash = XCMapObjectStart(name,"PBXProject");
        XCProperty("isa","PBXProject");
    
        XCStartMap("attributes");
            XCMapItem("LastUpgradeCheck","0920");//this sure could break.
            XCMapItem("ORGANIZATIONNAME","\"Placeholder Inc.\"");
    
            XCStartMap("TargetAttributes");
                XCMapObjectHashStart(productRef,"\"Product file ref\"");
                    XCProperty("CreatedOnToolsVersion","9.2");
                    XCProperty("ProvisioningStyle","Automatic");
                XCMapObjectEnd();
            XCEndMap();//TargetAttributes
    
        XCEndMap();//attributes
    
        XCPropertyHash("buildConfigurationList",buildConfiguration);
        XCProperty("compatibilityVersion","\"Xcode 8.0\"");//hardcoded trash
        XCProperty("developmentRegion","en");
        XCProperty("hasScannedForEncodings","0");
        XCStartList("knownRegions");
            XCListItem("en");
        XCEndList();//knownRegions
        XCPropertyHash("mainGroup",mainGroup);
        XCPropertyHash("productRefGroup",productGroup);
        XCProperty("projectDirPath","\"\"");
        XCProperty("projectRoot","\"\"");
        XCStartList("targets");
            XCListItemHash(productRef,"foo Product");
        XCEndList();//targets
    XCMapObjectEnd();//PBXProject
    
    return projectHash;
}

void WriteProj(FILE* projFile, project_t *bobProject) {
    FNVHash96 groups[2];
    FNVHash96 mainGroup;
    int numBuildFiles = 0;
    FNVHash96* buildFileFoo;
    FNVHash96 DebugConfig,ReleaseConfig;
    FNVHash96 ConfigList; FNVHash96 ProjectConfig;
    FNVHash96 productFileRef;
    FNVHash96 sourceBuildPhaseRef;
    FNVHash96 nativeTargetRef;
    FNVHash96 projectRef;
    
	XCSetCurrentFile(projFile);
	fprintf(currentFile, "// !$*UTF8*$!" XCEL "{" XCEL);

		XCProperty("archiveVersion", "1");
		XCStartList("classes");
		XCEndList();
    
		XCProperty("objectVersion", "48");
        XCStartMap("objects");
            XCSectionStart("PBXFileReference");
                for (size_t i = 0; i < bobProject->sources.num_files; i++)
                    WriteFileReference(bobProject->sources.files[i],"sourcecode.c.c",bobProject->sources.files[i],"\"<group>\"");
    
                productFileRef = WriteFileReference(bobProject->name,"\"compiled.mach-o.executable\"","foo","BUILT_PRODUCTS_DIR");
            XCSectionEnd("PBXFileReference");
    
            numBuildFiles = bobProject->sources.num_files;
            buildFileFoo = (FNVHash96*)malloc(sizeof(FNVHash96)*bobProject->sources.num_files);
            //write build file section
                //references filereferences to build
                //per-file compiler options (currently nothing)
            XCSectionStart("PBXBuildFile");
                for (size_t i = 0; i < bobProject->sources.num_files; i++)
                    buildFileFoo[i] = WriteBuildFile(bobProject->sources.files[i]);
            XCSectionEnd("PBXBuildFile");
    
            //groups
                //references other groups
                //references source & products
            XCSectionStart("PBXGroup");
                groups[0] = WriteGroupStart("Products");
                    XCListItemHashFromFile(bobProject->name);
                WriteGroupEnd("Products");
    
                groups[1] = WriteGroupStart("Sources");
    
                    for (size_t i = 0; i < bobProject->sources.num_files; i++)
                        XCListItemHashFromFile(bobProject->sources.files[i]);
    
                WriteGroupEnd("Sources");
    
                mainGroup = WriteGroupStart("ProjectGroup");
                    XCListItemHash(groups[1],"Sources");
                    XCListItemHash(groups[0],"Products");
                WriteGroupEnd("ProjectGroup");
            XCSectionEnd("PBXGroup");
    
            //SourceBuildPhase
                //references build files
                //action mask is not figured out
            XCSectionStart("PBXSourcesBuildPhase");
                sourceBuildPhaseRef = WriteSourcePhaseStart("Sources", "2147483647");
    
                    for (size_t i = 0; i < numBuildFiles; i++)
                        XCListItemHash(buildFileFoo[i],bobProject->sources.files[i]);
    
                WriteSourcePhaseEnd();
            XCSectionEnd("PBXSourcesBuildPhase");
    
            //BuildConfiguration
                //no references just a big bunch of settings
                //MOST LIKELY TO BREAK AT THE MOMENT, TESTING INDICATES THIS IS MINIMUM
                //BUT XCODE HAS A BIG LIST OF DEFAULT BUILD SETTINGS.
            XCSectionStart("XCBuildConfiguration");
                DebugConfig = WriteBuildConfiguration("Debug");
                ReleaseConfig = WriteBuildConfiguration("Release");
            XCSectionEnd("XCBuildConfiguration");
    
            //BuildConfigurationList
                //references multiple build configurations
            XCSectionStart("XCBuildConfigurationList");
                ConfigList = WriteConfigListPair("DefaultList",DebugConfig, ReleaseConfig, "Release");
                ProjectConfig = WriteConfigListPair("ProjectList",DebugConfig,ReleaseConfig,"Release");
            XCSectionEnd("XCBuildConfigurationList");
    
            //NativeTarget
                //references a BuildConfigurationList
                //references a build phase (source, frameworks, copy)
                //references a file reference for the product to build
            XCSectionStart("PBXNativeTarget");
                nativeTargetRef = WriteNativeTarget(bobProject->name, ConfigList, productFileRef,"foo",sourceBuildPhaseRef);
            XCSectionEnd("PBXNativeTarget");
    
    
            //Project
                //references a target for additional attributes (map)
                //references its own build configuration list (sort of, for inhereting)
                //references a main (parent?) group
                //references a product group for output
                //references a target
            XCSectionStart("PBXProject");
                projectRef = WriteProject("mainProject",
                                          nativeTargetRef,
                                          ProjectConfig,
                                          mainGroup,groups[0]);
            XCSectionEnd("PBXProject");
    
    
        XCEndMap();//Objects
        XCPropertyHash("rootObject",projectRef);

	fprintf(currentFile,"}");
}

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
    //OutputXcodeProj(&default_project);
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

trap cleanup EXIT

#OSX mktemp (At least as of 10.10.5 Yosemite) fails to substitute if the file template also has an extension
#also has no --suffix option, Randomising the extension and telling gcc it's a c file was simplest work around.
tmp_c=$(mktemp /tmp/bob-c.XXXXX)

#Due to the above suffix issues with OSX mktemp we can't base the exe name on the c file
tmp_exe=$(mktemp /tmp/bob-exe.XXXXX)

echo "$bob_c" >&$tmp_c
echo "#line 0 \"$1.bob\"" >>$tmp_c
cat $1.bob >>$tmp_c

gcc -std=c99 -o $tmp_exe -x c $tmp_c

eval $tmp_exe ${@}

exit 0

:: #########################################
:: ## Command Prompt Script               ##
:: #########################################

:CMDSCRIPT

echo #line 0 "%1.bob" >>%tmp_c%
type %1.bob >>%tmp_c%

set tmp_exe=%TEMP%\bob-exe.%random%.exe

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
::Work around the fact that VC 2017 vcvarsall is an alias for the Dev command prompt and messes with working directory
pushd %CD%
    call "%vcpath%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1

    if %errorlevel% NEQ 0 echo Problem configuring VC environment
popd

cl /Tc %tmp_c% /Fe%tmp_exe% /nologo

%tmp_exe%

del %tmp_c%
del %tmp_exe%

endlocal

:: End of main script
goto :EOF

:: ########################################
:: ## Heredoc processing code ##
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
