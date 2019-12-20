# botan_build_scripts
The "botan" (https://github.com/randombit/botan.git) library politics do not support back compatibilities and remove old algorithms from the library. Sometimes there is a need to have old algorithms with new algorithms, but it's not a possibility due to compilation and link problems. This build scripts intended to solve that problem by rename all cross names so that for the compiler it looks like a set of separates libraries.

# How to use

		./botan_build.sh <any_var_file>.var

# Example
		
		./botan_build.sh clang_botan_x64.var
		
# How to build with MSVC compilers?

- First you should to run command prompt tool. (For example: x64 Native Tools Command Prompt for VS 2017)
- Then you sgould to run bash file interpreter. (For example C:\Program Files\Git\bin\bash.exe)
- Then ./botan_build.sh msvc_botan_x64.var

# The following tools need to be present in you path env. variable:

python, make (depends from compiler (see: content of *.var file)), git, sed, tr