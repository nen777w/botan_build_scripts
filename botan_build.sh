#!/bin/bash

#vars
export STRT_DIR=$PWD

RED='\033[0;31m'

#variable for sed rule applayed to macroses
g_sed_rule_macroses=0


#special
back_to_start_dir()
{
  cd $STRT_DIR
}

#using
show_using()
{
  echo "botan_build.sh <path to build variables>"
  back_to_start_dir
  exit -1
}

show_progress()
{
 value=$1
 BAR='####################################################################################################'
 echo -ne "\r[${BAR:0:$value}] $value%"
 if [ $value -eq 100 ]; then
  echo " - DONE"
 fi
}


#---------------------------------------------------------------------

check_parameters()
{
 build_var_file=$1
 if [ -z $build_var_file ] || [ ! -f $build_var_file ] ; then 
  show_using 
 fi 
}


read_build_variables()
{
  build_var_file=$1
  check_parameters $build_var_file
  source $build_var_file   
}

apply_build_variables()
{
  export PATH=$PATH:$BBV_EXTRA_PATH
  #echo $PATH
}


check_utils()
{
 command -v python >/dev/null 2>&1 || { echo "python - not found! Aborting." >&2; exit -1; }  
 command -v $BBV_MAKE >/dev/null 2>&1 || { echo "$BBV_MAKE - not found! Aborting." >&2; exit -1; }
 command -v git >/dev/null 2>&1 || { echo "git - not found! Aborting." >&2; exit -1; }
 command -v sed >/dev/null 2>&1 || { echo "sed - not found! Aborting." >&2; exit -1; }
 command -v tr >/dev/null 2>&1 || { echo "tr - not found! Aborting." >&2; exit -1; }
}

botan_clone()
{
 if [ ! -d $BBV_BOTAN_BUILD_DIRECTORY ]; then
  git clone $BBV_BOTAN_REPO $BBV_BOTAN_BUILD_DIRECTORY
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while git cloning. Aborting."
    exit -1
  fi
 fi
}

botan_configure()
{
  flags=$1
  python configure.py $flags
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while Botan configure. Aborting."
    exit -1
  fi
}

seding_namespace()
{
  file=$1
  ns=$2
  ns_low=$(echo $2 | tr '[:upper:]' '[:lower:]')
  temp_file="temp_file.$BBV_CPU"
  
  sed "s/Botan/$ns/g;s/<botan/<$ns_low/g;s/\([ |(|~|&]\)botan_\([a-z_0-9]*\)/\1botan_\2_$ns_low/g" $file > $temp_file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (1). Aborting."
    exit -1
  fi
  mv $temp_file $file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (2). Aborting."
    exit -1
  fi
}

seding_preprocessor_catch_all_macroses()
{
  in_file=$1
  out_file=$2
  
  sed -n "s/#ifndef\s\([A-Z0-9_]*\).*$/\1/p;s/#define\s\([A-Z0-9_]*\).*$/\1/p" $in_file >> $out_file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (1). Aborting."
    exit -1
  fi
}

seding_preprocessor_prepare_macroses()
{
  file=$1
  ns=$(echo $2 | tr '[:lower:]' '[:upper:]')
  temp_file=$file.temp   
  
  #remove spaces
  sed "s/ //g;/^\s*$/d" $file > $temp_file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (1). Aborting."
    exit -1
  fi
  
  #remove duplicates
  sed -n "$!N; /^\(.*\)\n\1$/!P; D" $temp_file > $file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (1). Aborting."
    exit -1
  fi
  
  rm $temp_file
  
  #read $file and make sed rule
  sed_rule="s/\(";
  separator=""
  while read -r line; do
    sed_rule=$(echo "${sed_rule}${separator}${line}")
    separator="\|"
  done < $file
  sed_rule=$(echo "${sed_rule}\)\(_${ns}\)\?/\1_${ns}/g")
  
  rm $file
  
  echo $sed_rule   
}

seding_preprocessor_replace_macroses()
{
  file=$1
  temp_file="temp_file.$BBV_CPU"
                                             
  sed "$g_sed_rule_macroses" $file > $temp_file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (1). Aborting."
    exit -1
  fi    
  
  mv $temp_file $file
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while sed-ing file $file (2). Aborting."
    exit -1
  fi
}

make_file_seding()
{
  sed "s/-fstack-protector/-fno-stack-protector/g" ./Makefile > ./Makefile_tmp
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while make_file_seding (1). Aborting."
    exit -1
  fi
  
  mv ./Makefile_tmp ./Makefile
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while make_file_seding (2). Aborting."
    exit -1
  fi     
}

botan_seding()
{
  new_ns_name=$1
  
  #count files
  total_files_cpp=0
  for f in $(find ./ -name '*.cpp'); do total_files_cpp=$[$total_files_cpp +1]; done
  total_files_h=0
  for f in $(find ./ -name '*.h'); do total_files_h=$[$total_files_h +1]; done
              
  #total
  total_files=$[2 * $total_files_cpp + 3 * $total_files_h]
        
  #1
  counter=0
  for f in $(find ./ -name '*.cpp' -or -name '*.h'); do
    counter=$[$counter +1]
    let progress=($counter * 100)/$total_files 
    show_progress $progress
    seding_namespace $f $new_ns_name
  done
    
  #2
  if [ -f ./$new_ns_name.all.macroses ]; then rm ./$new_ns_name.all.macroses; fi
  
  for f in $(find ./ -name '*.h'); do
    counter=$[$counter +1]
    let progress=($counter * 100)/$total_files 
    show_progress $progress
    seding_preprocessor_catch_all_macroses $f ./$new_ns_name.all.macroses
  done
    
  #3           
  g_sed_rule_macroses=$(seding_preprocessor_prepare_macroses $new_ns_name.all.macroses $new_ns_name)
  
  #4
  for f in $(find ./ -name '*.cpp' -or -name '*.h'); do
    counter=$[$counter +1]
    let progress=($counter * 100)/$total_files 
    show_progress $progress
    seding_preprocessor_replace_macroses $f
  done
}

botan_deploy()
{
  version=$(echo $1 | tr '[:upper:]' '[:lower:]')
  platform=$2
  include_deploy_folder=$BBV_DEPLOYMENT_FOLDER/include/$platform
  
  echo "... deploy version: $version ..." 
  
  #copy libs
  echo "... copy libs ..."
  mkdir -p $BBV_DEPLOYMENT_FOLDER/lib  
  cp $BBV_BOTAN_BUILD_DIRECTORY/$BBV_DBG_ARTIFACT.dbg $(echo $BBV_DEPLOYMENT_FOLDER/lib/$version-$BBV_TARGET_EXTRA_NAME-d.$BBV_TARGET_EXT | tr '[:upper:]' '[:lower:]')
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error copy file $BBV_BOTAN_BUILD_DIRECTORY/$BBV_DBG_ARTIFACT.dbg. Aborting."
    exit -1
  fi  
  cp $BBV_BOTAN_BUILD_DIRECTORY/$BBV_REL_ARTIFACT.rel $(echo $BBV_DEPLOYMENT_FOLDER/lib/$version-$BBV_TARGET_EXTRA_NAME.$BBV_TARGET_EXT | tr '[:upper:]' '[:lower:]')
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error copy file $BBV_BOTAN_BUILD_DIRECTORY/$BBV_DBG_ARTIFACT.rel. Aborting."
    exit -1
  fi  
  
  #copy headers
  echo "... copy headers ..."
  mkdir -p $include_deploy_folder/$version
  cp -r $BBV_BOTAN_BUILD_DIRECTORY/build/include/$version/* $include_deploy_folder/$version/
  
  #copy configs
  echo "... copy cmake configs ..."
  cp -r ./cmake_configs/* $BBV_DEPLOYMENT_FOLDER/   
}

#---------------------------------------------------------------------

build_botan()
{
  new_ns_name=$1
  upper_new_ns_name=$(echo $new_ns_name | tr '[:lower:]' '[:upper:]')
  lower_new_ns_name=$(echo $new_ns_name | tr '[:upper:]' '[:lower:]')
  git_hash=$2
  
  cd $BBV_BOTAN_BUILD_DIRECTORY
  
  echo "... checkout $new_ns_name ..."
  
  git reset --hard
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while git reset. Aborting."
    exit -1
  fi
  
  git checkout $git_hash
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while git checkout. Aborting."
    exit -1
  fi

  #-----------------------------------------------------------------------------  
  pycfg=BBV_BOTAN_PLATFORM_CONFIGURE_FLAGS_$upper_new_ns_name
  #-----------------------------------------------------------------------------

  # --- BUILD RELEASE ---
  echo "build $new_ns_name RELEASE"
  
  echo "... configure RELEASE ... "
  botan_configure "${!pycfg} --disable-shared"
  $BBV_MAKE clean
  # rename includ directory for success build utils (not obligatory)
  mv ./build/include/botan ./build/include/$lower_new_ns_name 
  
  echo "... sed-ing ..."
  if [ "$BBV_CC" == "mingw" ]; then
    make_file_seding
  fi
  botan_seding $new_ns_name
  
  echo "... BUILD ..."
  $BBV_MAKE
  
  if [ ! -f ./$BBV_REL_ARTIFACT ]; then
    echo -en "${RED} File ./$BBV_REL_ARTIFACT not exist. Aborting."
    exit -1
  else
    mv ./$BBV_REL_ARTIFACT ./$BBV_REL_ARTIFACT.rel
  fi

  
  # --- BUILD DEBUG ---
  echo "build $new_ns_name BEBUG"
  
  git reset --hard
  if [ $? -ne 0 ]; then
    echo -en "${RED}Error while git reset. Aborting."
    exit -1
  fi
    
  echo "... configure DEBUG ... "
  botan_configure "${!pycfg} --disable-shared --with-debug-inf"
  $BBV_MAKE clean
  # rename includ directory for success build utils (not obligatory)
  mv ./build/include/botan ./build/include/$lower_new_ns_name
  
  
  echo "... sed-ing ..."
  if [ "$BBV_CC" == "mingw" ]; then
    make_file_seding
  fi
  botan_seding $new_ns_name
  
  echo "... BUILD ..."
  $BBV_MAKE
  
  if [ ! -f ./$BBV_DBG_ARTIFACT ]; then
    echo -en "${RED} File ./$BBV_DBG_ARTIFACT not exist. Aborting."
    exit -1
  else
    mv ./$BBV_DBG_ARTIFACT ./$BBV_DBG_ARTIFACT.dbg
  fi
  
  cd $STRT_DIR
                         
  # --- DEPLOY ---
  echo "... DEPLOY ..."
  botan_deploy $new_ns_name $BBV_CPU

  # --- REMOVE ARTIFACTS ---
  cd $BBV_BOTAN_BUILD_DIRECTORY
  rm ./$BBV_DBG_ARTIFACT.dbg
  rm ./$BBV_REL_ARTIFACT.rel
  cd $STRT_DIR
}

#---------------------------------------------------------------------

echo "Read build variables"
read_build_variables $1
echo "Apply build variables"
apply_build_variables
echo "Check utilites"
check_utils
echo "Clone Botan if need"
botan_clone

#---------------------------------------------------------------------

echo "----------"
echo " GO GO GO "
echo "----------"

build_botan "Botan_1_11_31" "5e946f93e8e751d2104f58583d4f209ca631aff1"
build_botan "Botan_1_11_34" "b816a3652c1359028f59d64a2f742564547ab782"
#build_botan "Botan_2_2_0_x" "7e5deeafdc7370e9368da84ea839c985ed2d8367"

#---------------------------------------------------------------------

cd $STRT_DIR


