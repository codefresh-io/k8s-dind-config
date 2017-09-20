FROM alpine:3.6


ENV KUBE_LATEST_VERSION="v1.7.6"

RUN apk add --update ca-certificates curl bash \
 && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && apk del --purge deps \
 && rm /var/cache/apk/*


COPY . /app

WORKDIR /app

CMD ["/bin/bash"]


