#!/bin/bash
use_sudo() {
  local cmd="echo ${sudo_pwd} | sudo -S "
  for param in "$@"; do cmd+="${param} "; done
  eval "${cmd}"
}

echo "Please enter your sudo password:"
read -s sudo_pwd

set -e

start_time=$(date +%s) # be careful +%s should separate with data

OPENCV_VER=4.7.0 # modifiable variable
GPU_ARCH_BIN=5.3

echo "Installing OpenCV ${OPENCV_VER} on your Jetson Nano"

# reveal the CUDA location
cd ~
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

# remove old versions or previous builds
cd ~
use_sudo rm -rf opencv*
# download the latest version
wget -O opencv.zip "https://github.com/opencv/opencv/archive/${OPENCV_VER}.zip"
wget -O opencv_contrib.zip "https://github.com/opencv/opencv_contrib/archive/${OPENCV_VER}.zip"
# unpack
unzip opencv.zip
unzip opencv_contrib.zip
# some administration to make live easier later on
mv opencv-${OPENCV_VER} opencv
mv opencv_contrib-${OPENCV_VER} opencv_contrib
# clean up the zip files
rm opencv.zip
rm opencv_contrib.zip

# set install dir
cd ~/opencv
mkdir build
cd build

# run cmake
cmake -D CMAKE_BUILD_TYPE=RELEASE \
  -D ENABLE_NEON=ON \
  -D OPENCV_ENABLE_NONFREE=ON \
  -D OPENCV_GENERATE_PKGCONFIG=ON \
  -D OPENCV_DNN_CUDA=ON \
  -D WITH_CUBLAS=ON \
  -D WITH_CUDA=ON \
  -D WITH_CUDNN=ON \
  -D WITH_EIGEN=ON \
  -D WITH_FFMPEG=ON \
  -D WITH_GSTREAMER=ON \
  -D WITH_LIBV4L=ON \
  -D WITH_OPENCL=OFF \
  -D WITH_OPENMP=ON \
  -D WITH_QT=OFF \
  -D WITH_TBB=ON \
  -D WITH_V4L=ON \
  -D BUILD_TESTS=OFF \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TBB=ON \
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
# Use "-j 4" only swap space is larger than 5.5GB
if [[ "FREE_MEM" -gt "5500" ]]; then
  NO_JOB=4
else
  echo "Due to limited swap, make only uses 1 core"
  NO_JOB=1
fi
make -j ${NO_JOB}

use_sudo rm -r /usr/include/opencv4/opencv2
use_sudo make install
use_sudo ldconfig

# cleaning (frees 320 MB)
make clean
use_sudo apt-get update

end_time=$(date +%s)
diff_time=$((end_time - start_time))
hours=$((diff_time / 3600))
minutes=$(((diff_time % 3600) / 60))
seconds=$((diff_time % 60))
printf "Build time: %02d:%02d:%02d\n" $hours $minutes $seconds

echo "Congratulations!"
echo "You've successfully installed OpenCV ${OPENCV_VER} on your Jetson Nano"
