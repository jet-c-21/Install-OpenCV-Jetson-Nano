#!/bin/bash
# ref: https://i7y.org/en/yolov8-on-jetson-nano/
# works for Python 3.8
set -e

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> color print >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Define the colors
declare -A COLORS=(
  ["red"]='\e[1;31m'
  ["green"]='\e[1;32m'
  ["blue"]='\e[1;34m'
  ["yellow"]='\e[1;33m'
  ["magenta"]='\e[1;35m'
  ["cyan"]='\e[1;36m'
  ["pink"]='\e[1;38;5;206m'
  ["white"]='\e[1;37m'
)
COLOR_RESET='\e[0m'

# Define the print function
cl_print() {
  local text=$1
  local color=$2

  # If the second argument is "dflt", print the text without color
  if [ "$color" == "dflt" ]; then
    echo -e "$text"
    return
  fi

  # If only one argument is provided, print in pink color
  if [ $# -eq 1 ]; then
    color="pink"
  fi

  # If the color is not defined, default to pink
  if [ -z "${COLORS[$color]}" ]; then
    color="pink"
  fi

  echo -e "${COLORS[$color]}${text}${COLOR_RESET}"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< color print <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ask sudo passwd and use_sudo >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Ask for the user's sudo password
echo "Please enter your sudo password:"
read -s password
#password=1130

verify_password() {
  # Function to verify the sudo password
  local password=$1
  echo $password | sudo -S true 2>/dev/null
  return $?
}

# Verify the password and assign it to the global variable SUDO_PWD
if verify_password "$password"; then
  SUDO_PWD=$password
  # echo "Password is correct. Assigned to SUDO_PWD variable."
else
  echo "Error: Incorrect password." >&2
  exit 1
fi

use_sudo() {
  : <<COMMENT
straight way:
  echo "$SUDO_PWD" | sudo -S your command
example:
  echo "$SUDO_PWD" | sudo -S apt-get update
COMMENT

  local cmd="echo ${SUDO_PWD} | sudo -S "
  for param in "$@"; do
    cmd+="${param} "
  done
  eval "${cmd}"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ask sudo passwd and use_sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

CURR_FILE_PATH="$(realpath "$0")"
CURR_DIR="$(dirname "$CURR_FILE_PATH")"
PROJECT_DIR="$(dirname "$CURR_DIR")"
PROJECT_PARENT_DIR="$(dirname "$PROJECT_DIR")"
PROJECT_DIR_NAME="$(basename "$PROJECT_DIR")"
ICHASE_USER_HOME_DIR="/home/ichase"
OPENCV_BUILD_WORK_DIR=${ICHASE_USER_HOME_DIR}/aibr_opencv_build

print_curr_python3() {
  python3_path=$(which python3)
  if [ -z "$python3_path" ]; then
    cl_print "*** Python3 not found in the PATH. *** \n"
  else
    python3_version=$(python3 --version 2>&1 | awk '{print $2}')
    cl_print "*** Current Python3 -> Python3 $python3_version : $python3_path *** \n"
  fi

  #  local python_site_pakages_dir=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
  #  local cv2_install_dir=$python_site_pakages_dir/cv2
  #  cl_print $cv2_install_dir

}

remove_old_opencv() {
  sudo apt purge -y libopencv-dev libopencv-python libopencv-samples libopencv*
  sudo sudo apt-get purge -y *libopencv*
  sudo find / -name " *opencv* " -exec rm -i {} \; || true
  sudo rm -rf "/usr/lib/python3.6/dist-packages/cv2"
  cl_print "rm all related files with *opencv*"

  python3 -m pip uninstall -y opencv-python || true
  python3 -m pip uninstall -y cv2 || true

  cl_print "rm all python cv2 related packages"

  # Check if OpenCV still exists in pkg-config
  if pkg-config --modversion opencv >/dev/null 2>&1; then
    cl_print "OpenCV still exists!"
  else
    cl_print "OpenCV removed from pkg-config."
  fi

  local cv2_import_res=$(
    python3 - <<EOF
import sys
try:
  import cv2;
  print("true")
except:
  print("false")
EOF
  )

  if [ $cv2_import_res == "true" ]; then
    cl_print "OpenCV can still be imported in Python3!"
  else
    cl_print "Removed old OpenCV successfully."
  fi
}

remove_old_gstreamer() {
  dpkg --get-selections | grep gstreamer || true
  sudo apt purge -y *gstreamer*
  sudo apt-get -y autoremove

  sudo rm -rf ~/.gstreamer-1.0/
  sudo rm -rf /usr/local/lib/gstreamer-1.0/
  sudo rm -rf /usr/lib/gstreamer-1.0/

  cl_print "remove all gstreamer related files"

  cl_print "current gstreamer packages on host:"
  dpkg --get-selections | grep gstreamer || true
  which gst-inspect-1.0 || true
  which gst-launch-1.0 || true
  gst-inspect-1.0 --version || true
  gst-launch-1.0 --gst-version || true
}

build_gstreamer_on_jetson_nano() {
  cd ~
  local gs_ver="1.16.2"
  local install_path="/home/ichase/gst-${gs_ver}"

  # Check if install_path directory does not exist
  if [ ! -d "$install_path" ]; then
    sudo apt install -y libssl-dev
    $CURR_DIR/gst-install.sh --prefix=$install_path --version=${gs_ver}
  else
    cl_print "${install_path} already exist, no build new files"
  fi

  local ld_path_to_be_added="${install_path}/lib/aarch64-linux-gnu"
  local ld_path_line='export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:'"${ld_path_to_be_added}"
  #  echo $ld_path_line

  local path_to_be_added="${install_path}/bin"
  local path_line='export PATH=${PATH}:'"${path_to_be_added}"
  #  echo $path_line

  if ! grep -qF "$ld_path_line" ~/.bashrc && ! grep -qF "$ld_path_line" ~/.bashrc; then
    echo "
# >>> gstreamer settings >>>
$ld_path_line
$path_line
# <<< gstreamer settings <<<
" >>~/.bashrc
    cl_print "added GStreamer path to PATH and LD_LIBRARY_PATH in .bashrc"
  fi

  source ~/.bashrc

  if ! grep -qF "$ld_path_line" ~/.zshrc && ! grep -qF "$ld_path_line" ~/.zshrc; then
    echo "
# >>> gstreamer settings >>>
$ld_path_line
$path_line
# <<< gstreamer settings <<<
" >>~/.zshrc
    cl_print "added GStreamer path to PATH and LD_LIBRARY_PATH in .zshrc"
  fi

  eval "$ld_path_line"
  eval "$path_line"

  sudo apt -y clean
  sudo apt -y autoremove

  gst-inspect-1.0 --version || true
  gst-launch-1.0 --gst-version || true

  sudo chmod 777 -R $install_path

  if [ -z "$PKG_CONFIG_PATH" ]; then
    export PKG_CONFIG_PATH="/home/ichase/gst-$gs_ver/lib/aarch64-linux-gnu/pkgconfig"
  else
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/home/ichase/gst-$gs_ver/lib/aarch64-linux-gnu/pkgconfig"
  fi

  cl_print "add gstreamer ${gs_ver} to PKG_CONFIG_PATH for opencv building later, PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"

  cl_print "finish building gstreamer $gs_ver"
}

build_opencv_on_jetson_nano() {
  local OPENCV_VER=4.1.1 # modifiable variable
  local GPU_ARCH_BIN=5.3

  cl_print "Installing OpenCV ${OPENCV_VER} on your Jetson Nano"

  cl_print "$PKG_CONFIG_PATH"

  start_time=$(date +%s)

  rm -rf $OPENCV_BUILD_WORK_DIR
  mkdir -p $OPENCV_BUILD_WORK_DIR
  cd $OPENCV_BUILD_WORK_DIR

  use_sudo sh -c "echo '/usr/local/cuda/lib64' >> /etc/ld.so.conf.d/nvidia-tegra.conf"
  use_sudo ldconfig

  # install the dependencies
  use_sudo apt-get install -y build-essential cmake git unzip pkg-config zlib1g-dev
  use_sudo apt-get install -y libjpeg-dev libjpeg8-dev libjpeg-turbo8-dev libpng-dev libtiff-dev
  use_sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libglew-dev
  use_sudo apt-get install -y libgtk2.0-dev libgtk-3-dev libcanberra-gtk*
  use_sudo apt-get install -y python-dev python-numpy python-pip
  use_sudo apt-get install -y python3-dev python3-numpy python3-pip
  use_sudo apt-get install -y libxvidcore-dev libx264-dev libgtk-3-dev
  use_sudo apt-get install -y libtbb2 libtbb-dev libdc1394-22-dev libxine2-dev
  use_sudo apt-get install -y gstreamer1.0-tools libv4l-dev v4l-utils qv4l2
  use_sudo apt-get install -y libgstreamer-plugins-base1.0-dev libgstreamer-plugins-good1.0-dev
  use_sudo apt-get install -y libavresample-dev libvorbis-dev libxine2-dev libtesseract-dev
  use_sudo apt-get install -y libfaac-dev libmp3lame-dev libtheora-dev libpostproc-dev
  use_sudo apt-get install -y libopencore-amrnb-dev libopencore-amrwb-dev
  use_sudo apt-get install -y libopenblas-dev libatlas-base-dev libblas-dev
  use_sudo apt-get install -y liblapack-dev liblapacke-dev libeigen3-dev gfortran
  use_sudo apt-get install -y libhdf5-dev protobuf-compiler
  use_sudo apt-get install -y libprotobuf-dev libgoogle-glog-dev libgflags-dev

  # download src files
  wget -O opencv.zip "https://github.com/opencv/opencv/archive/${OPENCV_VER}.zip"
  wget -O opencv_contrib.zip "https://github.com/opencv/opencv_contrib/archive/${OPENCV_VER}.zip"

  # unpack
  unzip opencv.zip
  unzip opencv_contrib.zip

  # some administration to make life easier later on
  mv opencv-${OPENCV_VER} opencv
  mv opencv_contrib-${OPENCV_VER} opencv_contrib

  # clean up the zip files
  rm opencv.zip
  rm opencv_contrib.zip

  cd $OPENCV_BUILD_WORK_DIR/opencv
  mkdir build
  cd build

  # run cmake
  cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CUDA_ARCH_BIN=${GPU_ARCH_BIN} \
    -D CUDA_ARCH_PTX="" \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D OPENCV_EXTRA_MODULES_PATH=$OPENCV_BUILD_WORK_DIR/opencv_contrib/modules \
    -D PYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
    -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
    -D ENABLE_NEON=ON \
    -D CUDA_FAST_MATH=ON \
    -D ENABLE_FAST_MATH=ON \
    -D OPENCV_DNN_CUDA=ON \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D OPENCV_GENERATE_PKGCONFIG=ON \
    -D WITH_CUDA=ON \
    -D WITH_CUDNN=ON \
    -D WITH_CUBLAS=ON \
    -D WITH_OPENCL=OFF \
    -D WITH_QT=ON \
    -D WITH_OPENMP=ON \
    -D WITH_FFMPEG=ON \
    -D WITH_GSTREAMER=ON \
    -D WITH_TBB=ON \
    -D WITH_EIGEN=ON \
    -D WITH_V4L=ON \
    -D WITH_LIBV4L=ON \
    -D INSTALL_C_EXAMPLES=OFF \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D BUILD_TIFF=ON \
    -D BUILD_TESTS=OFF \
    -D BUILD_TBB=ON \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_opencv_text=OFF \
    -D BUILD_opencv_python2=OFF \
    -D BUILD_opencv_cudaoptflow=ON \
    -D BUILD_opencv_cudacodec=ON \
    -D BUILD_opencv_cudev=ON \
    -D BUILD_opencv_cudaarithm=ON \
    -D BUILD_opencv_cudafeatures2d=ON \
    -D BUILD_opencv_cudafilters=ON \
    -D BUILD_opencv_cudaimgproc=ON \
    -D BUILD_opencv_cudaobjdetect=ON \
    -D BUILD_opencv_cudastereo=ON \
    -D BUILD_opencv_cudawarping=ON \
    -D BUILD_opencv_cudacnn=ON \
    -D BUILD_opencv_cudabgsegm=ON \
    -D BUILD_opencv_cudastitching=ON \
    ..

  # run make
  FREE_MEM="$(free -m | awk '/^Swap/ {print $2}')"
  #  # Use "-j 4" only swap space is larger than 5.5GB
  #  if [[ "FREE_MEM" -gt "5500" ]]; then
  #    NO_JOB=4
  #  else
  #    echo "Due to limited swap, make only uses 1 core"
  #    NO_JOB=1
  #  fi
  #  make -j ${NO_JOB}

  make -j 4

  use_sudo rm -r /usr/include/opencv4/opencv2
  use_sudo make install
  use_sudo ldconfig

  # cleaning (frees 320 MB)
  make clean
  use_sudo apt-get update

  cl_print "finish building tasks"

  end_time=$(date +%s)
  diff_time=$((end_time - start_time))
  hours=$((diff_time / 3600))
  minutes=$(((diff_time % 3600) / 60))
  seconds=$((diff_time % 60))
  printf "Build time: %02d:%02d:%02d\n" $hours $minutes $seconds

  cl_print "Congratulations!"
  cl_print "You've successfully installed OpenCV ${OPENCV_VER} on your Jetson Nano"

  chmod 777 -R $aibr_opencv_build
}

main() {
  print_curr_python3
  remove_old_opencv
  remove_old_gstreamer
  build_gstreamer_on_jetson_nano
  build_opencv_on_jetson_nano

}

main
