#!/bin/sh
set -e

SCRIPT_DIR=$( cd $(dirname $0); pwd -P)
ROOT_DIR="${SCRIPT_DIR}/../.."
VOLUME="${SCRIPT_DIR}/build.linux-x86_64"
mkdir -p ${VOLUME}

REPOSITORY="tinyspline"
TAG="build.linux-x86_64"
IMAGE_NAME="${REPOSITORY}:${TAG}"
STORAGE="/dist"

SETUP_CMDS=$(cat << END
RUN apt-get update && apt-get install -y --no-install-recommends cmake swig
COPY src/. /tinyspline
WORKDIR /tinyspline
END
)

################################# C#, D, Java #################################
BUILD_CSHARP_D_JAVA() {
	docker build -t ${IMAGE_NAME} -f - ${ROOT_DIR} <<-END
		FROM buildpack-deps:stretch
		${SETUP_CMDS}
		RUN apt-get install -y --no-install-recommends 	\
			mono-mcs nuget \
			dub \
			default-jdk maven
		END
	docker run --rm --name ${TAG} --volume "${VOLUME}:${STORAGE}" \
		${IMAGE_NAME} /bin/bash -c "cmake \
			-DCMAKE_BUILD_TYPE=Release \
			-DTINYSPLINE_ENABLE_CSHARP=True \
			-DTINYSPLINE_ENABLE_DLANG=True \
			-DTINYSPLINE_ENABLE_JAVA=True . && \
		cmake --build . --target tinysplinecsharp && nuget pack && \
			mv ./*.nupkg ${STORAGE} && \
		dub build && tar czf ${STORAGE}/tinysplinedlang.tar.gz dub && \
		mvn package && mv ./target/*.jar ${STORAGE}"
	docker rmi ${IMAGE_NAME}
}

BUILD_CSHARP_D_JAVA

##################################### Lua #####################################
BUILD_LUA() {
	docker build -t ${IMAGE_NAME} -f - ${ROOT_DIR} <<-END
		FROM buildpack-deps:stretch
		${SETUP_CMDS}
		RUN apt-get install -y --no-install-recommends \
			luarocks liblua${1}-dev
		END
	docker run --rm --name ${TAG} --volume "${VOLUME}:${STORAGE}" \
		${IMAGE_NAME} /bin/bash -c "cmake \
			-DCMAKE_BUILD_TYPE=Release \
			-DTINYSPLINE_ENABLE_LUA=True . && \
		luarocks make --local && luarocks pack --local tinyspline && \
		mv ./*.rock ${STORAGE}"
	docker rmi ${IMAGE_NAME}
	for file in "${VOLUME}/"*.rock
	do
		if [[ "${file}" != *"lua"* ]];then
			mv $file ${file/.rock/.lua${1}.rock}
		fi
	done
}

BUILD_LUA 5.1
BUILD_LUA 5.2
BUILD_LUA 5.3

################################## Octave, R ##################################
BUILD_OCTAVE_R_UBUNTU() {
	docker build -t ${IMAGE_NAME} -f - ${ROOT_DIR} <<-END
		FROM buildpack-deps:${1}
		RUN echo 'debconf debconf/frontend select Noninteractive' \
			| debconf-set-selections
		${SETUP_CMDS}
		RUN apt-get install -y --no-install-recommends \
			liboctave-dev octave \
			r-base r-cran-rcpp
		END
	docker run --rm --name ${TAG} --volume "${VOLUME}:${STORAGE}" \
		${IMAGE_NAME} /bin/bash -c "cmake \
			-DCMAKE_BUILD_TYPE=Release \
			-DTINYSPLINE_ENABLE_OCTAVE=True \
			-DTINYSPLINE_ENABLE_R=True . && \
		cmake --build . --target tinysplineoctave && \
			find ./lib -name '*.oct' \
			| tar czf ${STORAGE}/tinysplineoctave.utnubu.tar.gz \
			-T - && \
		cmake --build . --target tinyspliner && \
			find ./lib -name 'tinyspliner*' -o -name '*.R' \
			| tar czf ${STORAGE}/tinyspliner.utnubu.tar.gz -T -"
	docker rmi ${IMAGE_NAME}
	for file in "${VOLUME}/"*utnubu.tar.gz
	do
		if [[ "${file}" != *"ubuntu"* ]];then
			mv $file ${file/utnubu/ubuntu-${1}}
		fi
	done
}

BUILD_OCTAVE_R_UBUNTU 16.04
BUILD_OCTAVE_R_UBUNTU 18.04

##################################### PHP #####################################
BUILD_PHP_7() {
	docker build -t ${IMAGE_NAME} -f - ${ROOT_DIR} <<-END
		FROM buildpack-deps:18.04
		RUN echo 'debconf debconf/frontend select Noninteractive' \
			| debconf-set-selections
		${SETUP_CMDS}
		RUN apt-get install -y --no-install-recommends \
			php-dev
		END
	docker run --rm --name ${TAG} --volume "${VOLUME}:${STORAGE}" \
		${IMAGE_NAME} /bin/bash -c "cmake \
			-DCMAKE_BUILD_TYPE=Release \
			-DTINYSPLINE_ENABLE_PHP=True . && \
		cmake --build . --target tinysplinephp && \
		find ./lib -name '*php*' \
		| tar czf ${STORAGE}/tinysplinephp7.tar.gz -T -"
	docker rmi ${IMAGE_NAME}
}

BUILD_PHP_7

################################### Python ####################################
BUILD_PYTHON() {
	docker build -t ${IMAGE_NAME} -f - ${ROOT_DIR} <<-END
		FROM python:${1}-stretch
		${SETUP_CMDS}
		END
	docker run --rm --name ${TAG} --volume "${VOLUME}:${STORAGE}" \
		${IMAGE_NAME} /bin/bash -c "cmake \
			-DCMAKE_BUILD_TYPE=Release \
			-DTINYSPLINE_ENABLE_PYTHON=True . && \
		python setup.py bdist_wheel && mv ./dist/*.whl ${STORAGE}"
	docker rmi ${IMAGE_NAME}
}

BUILD_PYTHON 2.7
BUILD_PYTHON 3.5
BUILD_PYTHON 3.6
BUILD_PYTHON 3.7
