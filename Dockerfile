FROM registry:2.6.2

MAINTAINER Tang Jiujun <jiujun.tang@gmail.com>

RUN set -ex && { \
        echo 'http://mirrors.aliyun.com/alpine/v3.4/main'; \
        echo 'http://mirrors.aliyun.com/alpine/v3.4/community'; \
    } > /etc/apk/repositories && \
    apk update && apk add findutils curl bash && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
