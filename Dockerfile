ARG ALPINE_TAG=3.21.3
ARG user=dst
ARG group=dst
ARG uid=1000
ARG gid=1000
ARG AGENT_WORKDIR=/home/"${user}"/agent

#java runtime



# agent 
FROM alpine:"${ALPINE_TAG}" as agent
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
USER "${user}"
RUN mkdir -p /home/${user}/.config && mkdir -p "${AGENT_WORKDIR}"
WORKDIR /home/"${user}"


# image server
FROM agent AS inbound-agent
ARG user
USER root
COPY ./script/ /app/bin/
RUN chmod +x /app/bin/startServer.sh /app/bin/start.sh 

USER ${user}
CMD [ "/app/bin/startServer.sh" ]
ENTRYPOINT [ "sh" ]