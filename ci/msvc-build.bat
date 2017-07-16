@rem Licensed to the Apache Software Foundation (ASF) under one
@rem or more contributor license agreements.  See the NOTICE file
@rem distributed with this work for additional information
@rem regarding copyright ownership.  The ASF licenses this file
@rem to you under the Apache License, Version 2.0 (the
@rem "License"); you may not use this file except in compliance
@rem with the License.  You may obtain a copy of the License at
@rem
@rem   http://www.apache.org/licenses/LICENSE-2.0
@rem
@rem Unless required by applicable law or agreed to in writing,
@rem software distributed under the License is distributed on an
@rem "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
@rem KIND, either express or implied.  See the License for the
@rem specific language governing permissions and limitations
@rem under the License.

@echo on

if "%JOB%" == "Cmake_Script_Tests" (
  conda update --yes --quiet conda
  conda create -n arrow-cmake-script-tests -q -y
  conda install -n arrow-cmake-script-tests -q -y -c conda-forge ^
      cmake git boost-cpp
  call activate arrow-cmake-script-tests

  mkdir cpp\build-cmake-test
  pushd cpp\build-cmake-test

  echo "Test cmake script errors out on flatbuffers missed"
  set FLATBUFFERS_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"Could not find the Flatbuffers library" error.txt || exit /B
  set FLATBUFFERS_HOME=

  echo "Test cmake script errors out on gflags missed"
  set GFLAGS_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"No static or shared library provided for gflags" error.txt || exit /B
  set GFLAGS_HOME=

  echo "Test cmake script errors out on snappy missed"
  set SNAPPY_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"Could not find the Snappy library" error.txt || exit /B
  set SNAPPY_HOME=

  echo "Test cmake script errors out on zlib missed"
  set ZLIB_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"Could not find the ZLIB library" error.txt || exit /B
  set ZLIB_HOME=

  echo "Test cmake script errors out on brotli missed"
  set BROTLI_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"Could not find the Brotli library" error.txt || exit /B
  set BROTLI_HOME=

  echo "Test cmake script errors out on lz4 missed"
  set LZ4_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"No static or shared library provided for lz4_static" error.txt || exit /B
  set LZ4_HOME=

  echo "Test cmake script errors out on zstd missed"
  set ZSTD_HOME=WrongPath

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
        -DARROW_CXXFLAGS="/MP" ^
        .. >nul 2>error.txt

  FINDSTR /M /C:"Could NOT find ZSTD" error.txt || exit /B
  set ZSTD_HOME=

  popd

  @rem Finish build job successfully
  exit /B 0
)

if "%CONFIGURATION%" == "Debug" (
  mkdir cpp\build-debug
  pushd cpp\build-debug

  cmake -G "%GENERATOR%" ^
        -DARROW_BOOST_USE_SHARED=OFF ^
        -DCMAKE_BUILD_TYPE=Debug ^
        -DARROW_CXXFLAGS="/MP" ^
        ..  || exit /B

  cmake --build . --config Debug || exit /B
  popd

  @rem Finish Debug build successfully
  exit /B 0
)

conda update --yes --quiet conda

conda create -n arrow -q -y python=%PYTHON% ^
      six pytest setuptools numpy pandas cython

if "%CONFIGURATION%" == "Toolchain" (
  conda install -n arrow -q -y -c conda-forge ^
      flatbuffers rapidjson cmake git boost-cpp ^
      thrift-cpp snappy zlib brotli gflags lz4-c zstd
)

call activate arrow

if "%CONFIGURATION%" == "Toolchain" (
  set ARROW_BUILD_TOOLCHAIN=%CONDA_PREFIX%\Library
)

set ARROW_HOME=%CONDA_PREFIX%\Library

@rem Build and test Arrow C++ libraries

mkdir cpp\build
pushd cpp\build

cmake -G "%GENERATOR%" ^
      -DCMAKE_INSTALL_PREFIX=%CONDA_PREFIX%\Library ^
      -DARROW_BOOST_USE_SHARED=OFF ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DARROW_CXXFLAGS="/WX /MP" ^
      -DARROW_PYTHON=ON ^
      ..  || exit /B
cmake --build . --target INSTALL --config Release  || exit /B

@rem Needed so python-test.exe works
set PYTHONPATH=%CONDA_PREFIX%\Lib;%CONDA_PREFIX%\Lib\site-packages;%CONDA_PREFIX%\python35.zip;%CONDA_PREFIX%\DLLs;%CONDA_PREFIX%;%PYTHONPATH%

ctest -VV  || exit /B
popd

@rem Build parquet-cpp

git clone https://github.com/apache/parquet-cpp.git || exit /B
mkdir parquet-cpp\build
pushd parquet-cpp\build

set PARQUET_BUILD_TOOLCHAIN=%CONDA_PREFIX%\Library
set PARQUET_HOME=%CONDA_PREFIX%\Library
cmake -G "%GENERATOR%" ^
     -DCMAKE_INSTALL_PREFIX=%PARQUET_HOME% ^
     -DCMAKE_BUILD_TYPE=Release ^
     -DPARQUET_BOOST_USE_SHARED=OFF ^
     -DPARQUET_ZLIB_VENDORED=off ^
     -DPARQUET_BUILD_TESTS=off .. || exit /B
cmake --build . --target INSTALL --config Release || exit /B
popd

@rem Build and import pyarrow
@rem parquet-cpp has some additional runtime dependencies that we need to figure out
@rem see PARQUET-1018

pushd python
python setup.py build_ext --inplace --with-parquet --bundle-arrow-cpp bdist_wheel  || exit /B
py.test pyarrow -v -s --parquet || exit /B
popd
