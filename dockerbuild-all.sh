#!/bin/bash

# Remove generated config file (if this exists, it will contain a Windows configuration,
# and we don't want to pass that into the linux docker containers)
rm -f libssh2/src/libssh2_config.h

dos2unix build.libgit2.sh

for RID in "linux-x64" "linux-musl-x64" "linux-arm64" "linux-arm" "linux-musl-arm64"; do

    if [[ $RID =~ arm64 ]]; then
        arch="arm64"
    elif [[ $RID =~ arm ]]; then
        arch="armhf"
    else
        arch="amd64"
    fi

    if [[ $RID == linux-musl* ]]; then
        dockerfile="Dockerfile.linux-musl"
    else
        dockerfile="Dockerfile.linux"
        if [[ $RID =~ arm64 ]]; then
            arch="arm64v8"
        elif [[ $RID =~ arm ]]; then
            arch="arm32v7"
        else
            arch="amd64"
    fi
    fi

    docker build -t $RID -f $dockerfile --build-arg ARCH=$arch .

    docker run -t -e RID=$RID --name=$RID $RID

    docker cp $RID:/nativebinaries/nuget.package/runtimes nuget.package

    docker rm $RID

    # docker build -t $RID -f Dockerfile.$RID .
    # winpty docker run -it -e RID=$RID --name=$RID $RID
    # docker cp $RID:/nativebinaries/nuget.package/runtimes nuget.package
    # docker rm $RID
done
