ARG ALPINE_TAG=3.21.3
ARG user=dst
ARG group=dst
ARG uid=1000
ARG gid=1000
ARG AGENT_WORKDIR=/home/"${user}"/agent
ARG JAVA_VERSION=17

#manage cli
FROM alpine:"${ALPINE_TAG}" AS manage
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories \
	&& apk update \
	&& apk add --no-cache \
	curl \
	bash \
	git \
	git-lfs \
	musl-locales \
	openssh-client \
	openssl \
	procps \
	tzdata \
	tzdata-utils \
	libstdc++ \
	&& rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*
COPY component/install-jdk.sh /usr/bin/local/install-jdk.sh
RUN chmod 777 /usr/bin/local/install-jdk.sh
ARG JAVA_VERSION
RUN /usr/bin/local/install-jdk.sh "${JAVA_VERSION}" alpine 
ADD "https://mirrors.sustech.edu.cn/apache/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz" "/tmp/file.tar.gz"
COPY component/install-tool.sh /usr/bin/local/install-tool.sh
WORKDIR /app
RUN chmod 777 /usr/bin/local/install-tool.sh \
	&& /usr/bin/local/install-tool.sh maven \
	&& git clone https://gitee.com/admiralitycode/dstmanage.git
ENV JAVA_HOME=/opt/jdk-${JAVA_VERSION} MAVEN_HOME=/opt/maven CLASSPATH=/opt/jdk-${JAVA_VERSION}/lib/dt.jar:/opt/jdk-${JAVA_VERSION}/lib/tools.jar
ENV PATH="${MAVEN_HOME}/bin:${JAVA_HOME}/bin:${PATH}"
COPY component/maven-settings.xml /app/settings.xml
WORKDIR /app/dstmanage
RUN mvn -DskipTests=true clean package -s /app/settings.xml -f /app/dstmanage/pom.xml -P prod \
	&& mkdir /app/jar
RUN mv /app/dstmanage/target/*.jar /app/jar/

#java runtime
FROM alpine:"${ALPINE_TAG}" AS jre
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories \
	&& apk update \
	&& apk add --no-cache \
	curl \
	ca-certificates
COPY component/install-jre.sh /usr/bin/local/install-jre.sh
ARG JAVA_VERSION
ENV PATH="/opt/jdk-${JAVA_VERSION}/bin:${PATH}"
RUN chmod 777 /usr/bin/local/install-jre.sh
RUN /usr/bin/local/install-jre.sh "${JAVA_VERSION}" alpine 

#dst server
FROM alpine:"${ALPINE_TAG}" AS dst


# agent 
FROM alpine:"${ALPINE_TAG}" AS agent
ARG user
ARG group
ARG uid
ARG gid
ARG AGENT_WORKDIR
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV PATH="${PATH}"
# add user and group
RUN addgroup -g "${gid}" "${group}" \
	&& adduser -h /home/"${user}" -u "${uid}" -G "${group}" -D "${user}" || echo "user ${user} already exists." \
	&& sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories \
	&& apk update
USER ${uid}:${group}
RUN mkdir -p /home/${user}/.config && mkdir -p "${AGENT_WORKDIR}"
COPY --from=jre /opt/jre-17 "/opt/jre17"
ENV USER=${user}
WORKDIR /home/"${user}"
COPY --from=manage --chown=${uid}:${group} /app/jar /home/"${user}"/jar 

# image server
FROM agent AS inbound-agent
ENV JAVA_HOME=/opt/jre17
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ARG user
USER root
COPY ./script/ /app/bin/
RUN chmod +x /app/bin/startServer.sh /app/bin/start.sh 
EXPOSE 8080
USER ${user}
CMD [ "/app/bin/startServer.sh" ]
ENTRYPOINT [ "sh" ]