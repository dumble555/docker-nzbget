# Buildstage
FROM ubuntu:20:04 as buildstage

RUN \
  echo "**** install build packages ****" && \
  apt update && apt install -y \
    curl \
    g++ \
    gcc \
    git \
    libxml2-dev \
    libxslt-dev \
    make \
    ncurses-dev \
    openssl-dev && \
  echo "**** build nzbget ****" && \
  if [ -z ${NZBGET_RELEASE+x} ]; then \
    NZBGET_RELEASE=$(curl -sX GET "https://api.github.com/repos/nzbget/nzbget/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  mkdir -p /app/nzbget && \
  git clone https://github.com/nzbget/nzbget.git nzbget && \
  cd nzbget/ && \
  git checkout ${NZBGET_RELEASE} && \
  git cherry-pick -n fa57474d && \
  ./configure \
    bindir='${exec_prefix}' && \
  make && \
  make prefix=/app/nzbget install && \
  sed -i \
    -e "s#^MainDir=.*#MainDir=/downloads#g" \
    -e "s#^ScriptDir=.*#ScriptDir=$\{MainDir\}/scripts#g" \
    -e "s#^WebDir=.*#WebDir=$\{AppDir\}/webui#g" \
    -e "s#^ConfigTemplate=.*#ConfigTemplate=$\{AppDir\}/webui/nzbget.conf.template#g" \
    -e "s#^UnrarCmd=.*#UnrarCmd=$\{AppDir\}/unrar#g" \
    -e "s#^SevenZipCmd=.*#SevenZipCmd=$\{AppDir\}/7za#g" \
    -e "s#^CertStore=.*#CertStore=$\{AppDir\}/cacert.pem#g" \
    -e "s#^CertCheck=.*#CertCheck=yes#g" \
    -e "s#^DestDir=.*#DestDir=$\{MainDir\}/completed#g" \
    -e "s#^InterDir=.*#InterDir=$\{MainDir\}/intermediate#g" \
    -e "s#^LogFile=.*#LogFile=$\{MainDir\}/nzbget.log#g" \
    -e "s#^AuthorizedIP=.*#AuthorizedIP=127.0.0.1#g" \
  /app/nzbget/share/nzbget/nzbget.conf && \
  mv /app/nzbget/share/nzbget/webui /app/nzbget/ && \
  cp /app/nzbget/share/nzbget/nzbget.conf /app/nzbget/webui/nzbget.conf.template && \
  ln -s /usr/bin/7za /app/nzbget/7za && \
  ln -s /usr/bin/unrar /app/nzbget/unrar && \
  cp /nzbget/pubkey.pem /app/nzbget/pubkey.pem && \
  curl -o \
    /app/nzbget/cacert.pem -L \
    "https://curl.haxx.se/ca/cacert.pem"

# Runtime Stage
FROM ubuntu:20.04

# set version label


RUN \
  echo "**** install build packages ****" && \
  apt update && apt install -y \
    cargo \
    g++ \
    libc-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    openssl-dev \
    python3-dev && \
  echo "**** install packages ****" && \
  apt install -y \
    curl \
    libxml2 \
    libxslt \
    openssl \
    p7zip \
    py3-pip \
    python3 \
    unrar \
    wget && \
  echo "**** install python packages ****" && \
  pip3 install --no-cache-dir -U \
    pip && \
  pip install --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine/ \
    apprise \
    chardet \
    lxml \
    pynzbget \
    rarfile && \
  ln -s /usr/bin/python3 /usr/bin/python && \
# add local files and files from buildstage
COPY --from=buildstage /app/nzbget /app/nzbget
COPY root/ /

# ports and volumes
VOLUME /config
EXPOSE 6789
