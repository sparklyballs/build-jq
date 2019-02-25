ARG ALPINE_VER="edge" 
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		curl

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch version file
RUN \
	set -ex \
	&& curl -o \
	/tmp/version.txt -L \
	"https://raw.githubusercontent.com/sparklyballs/versioning/master/version.txt"

# fetch source code
# hadolint ignore=SC1091
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/tmp/jq-src \
	&& curl -o \
	/tmp/jq.tar.gz -L \
	"https://github.com/stedolan/jq/archive/jq-${JQ_RELEASE}.tar.gz" \
	&& tar xf \
	/tmp/jq.tar.gz -C \
	/tmp/jq-src --strip-components=1

FROM alpine:${ALPINE_VER} as build-stage

############## build  stage ##############

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		autoconf \
		automake \
		bash \
		bison \
		file \
		flex \
		g++ \
		libtool \
		make \
		oniguruma-dev

# copy artifacts from fetch stage
COPY --from=fetch-stage /tmp/jq-src /tmp/jq-src
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# set workdir 
WORKDIR /tmp/jq-src

# build package
# hadolint ignore=SC1091
RUN \
	source /tmp/version.txt \
	&& set -ex \
	&& autoreconf -fi \
	&& ./configure \
		--disable-docs \
		--localstatedir=/var \
		--mandir=/usr/share/man \
		--prefix=/usr \
		--sysconfdir=/etc \
	&& make LDFLAGS=-all-static \
	&& make DESTDIR=/tmp/build install

FROM alpine:${ALPINE_VER}

############## package stage ##############

# copy fetch and build artifacts
COPY --from=build-stage /tmp/build /tmp/build
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt

# install strip packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		binutils \
		tar

# set workdir
WORKDIR /tmp/build/usr/bin

# strip and archive package
# hadolint ignore=SC1091
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/build \
	&& strip --strip-all jq \
	&& tar -czvf /build/jq-"${JQ_RELEASE}".tar.gz jq \
	&& chown 1000:1000 /build/jq-"${JQ_RELEASE}".tar.gz

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
