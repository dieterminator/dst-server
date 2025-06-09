ARG ALPINE_TAG=3.21.3
ARG UBUNTU_TAG=24.04
ARG user=dst
ARG group=dst
ARG uid=1000
ARG gid=1000
ARG USER_HOME=/home/"${user}"
ARG AGENT_WORKDIR="${USER_HOME}/agent"
ARG JAVA_VERSION=17

# build base image
FROM ubuntu:${UBUNTU_TAG} AS base
ARG user
ARG group
ARG uid
ARG gid
ARG AGENT_WORKDIR
ARG USER_HOME
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV PATH="${PATH}"
ENV USER=${user} USER_HOME=${USER_HOME}
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
# add user and group
USER root

RUN echo \
    "Dir::Cache "";\
    Dir::Cache::archives "";" | sed 's/   */\n/g' > "/etc/apt/apt.conf.d/02nocache"

RUN if id ${uid} &>/dev/null; then \
    d_user=$(getent passwd ${uid} | cut -d: -f1); \
    userdel -r $d_user; \
    groupdel $d_user 2>/dev/null || true; \
    fi
RUN groupadd --gid ${gid} ${group}
RUN useradd --uid ${uid} --gid ${gid} --create-home --shell /bin/bash -d ${USER_HOME} ${user} && chown ${uid}:${gid} -R ${USER_HOME}
RUN sed -e "s|http://security.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g" \
    -e "s|http://archive.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g" \
    -i.bak \
    /etc/apt/sources.list.d/ubuntu.sources \
    && apt update \
    && apt install -y ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/ubuntu.sources \
    && apt update \
    && apt clean 



#manage cli
# FROM alpine:"${ALPINE_TAG}" AS manage
# SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories \
# 	&& apk update \
# 	&& apk add --no-cache \
# 	curl \
# 	bash \
# 	git \
# 	git-lfs \
# 	musl-locales \
# 	openssh-client \
# 	openssl \
# 	procps \
# 	tzdata \
# 	tzdata-utils \
# 	libstdc++ \
# 	&& rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*
# COPY component/install-jdk.sh /usr/bin/local/install-jdk.sh
# RUN chmod 777 /usr/bin/local/install-jdk.sh
# ARG JAVA_VERSION
# RUN /usr/bin/local/install-jdk.sh "${JAVA_VERSION}" alpine 
# ADD "https://mirrors.sustech.edu.cn/apache/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz" "/tmp/file.tar.gz"
# COPY component/install-tool.sh /usr/bin/local/install-tool.sh
# WORKDIR /app
# RUN chmod 777 /usr/bin/local/install-tool.sh \
# 	&& /usr/bin/local/install-tool.sh maven \
# 	&& git clone https://gitee.com/admiralitycode/dstmanage.git
# ENV JAVA_HOME=/opt/jdk-${JAVA_VERSION} MAVEN_HOME=/opt/maven CLASSPATH=/opt/jdk-${JAVA_VERSION}/lib/dt.jar:/opt/jdk-${JAVA_VERSION}/lib/tools.jar
# ENV PATH="${MAVEN_HOME}/bin:${JAVA_HOME}/bin:${PATH}"
# COPY component/maven-settings.xml /app/settings.xml
# WORKDIR /app/dstmanage
# RUN mvn -DskipTests=true clean package -s /app/settings.xml -f /app/dstmanage/pom.xml -P prod \
# 	&& mkdir /app/jar
# RUN mv /app/dstmanage/target/*.jar /app/jar/

#java runtime
# FROM base AS jre
# SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
# RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories \
# 	&& apk update \
# 	&& apk add --no-cache \
# 	curl \
# 	ca-certificates
# COPY component/install-jre.sh /usr/bin/local/install-jre.sh
# ARG JAVA_VERSION
# ENV PATH="/opt/jdk-${JAVA_VERSION}/bin:${PATH}"
# RUN chmod 777 /usr/bin/local/install-jre.sh
# RUN /usr/bin/local/install-jre.sh "${JAVA_VERSION}" alpine 

#dst server
FROM base AS dst
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
ARG user
ARG group
ARG USER_HOME
RUN apt-get install -y --no-install-recommends --no-install-suggests curl lib32gcc-s1 lib32stdc++6
USER ${user}
WORKDIR "${USER_HOME}"
RUN mkdir ~/steamcmd && cd ~/steamcmd \
    && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - \
    # && bash ./steamcmd.sh +force_install_dir "${USER_HOME}/dstserver" +login anonymous +app_update 343050 validate +quit \
    && echo 1


# agent 
FROM base AS agent
ARG user
ARG group
ARG uid
ARG gid
ARG AGENT_WORKDIR
ARG USER_HOME
RUN apt-get install -y --no-install-recommends --no-install-suggests libgcc1 lib32gcc-s1 lib32stdc++6 libcurl4-gnutls-dev
USER ${uid}:${group}
WORKDIR ${USER_HOME}
RUN mkdir -p ${USER_HOME}/.config && mkdir -p ${USER_HOME}/dstsaves
# COPY --from=jre /opt/jre-17 "/opt/jre17"
# COPY --from=manage --chown=${uid}:${group} /app/jar /home/"${user}"/jar 
COPY --from=dst --chown=${uid}:${group} ${USER_HOME}/steamcmd ${USER_HOME}/steamcmd
# COPY --from=dst --chown=${uid}:${group} ${USER_HOME}/dstserver ${USER_HOME}/server 

# image server
FROM agent AS inbound-agent
ENV JAVA_HOME=/opt/jre17
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ARG user
USER root
COPY ./script/ /app/bin/
RUN chmod +x /app/bin/startServer.sh /app/bin/start.sh 
EXPOSE 8080-8090/tcp 
USER ${user}
#CMD [ "/app/bin/startServer.sh" ]
ENTRYPOINT [ "/bin/bash" ]