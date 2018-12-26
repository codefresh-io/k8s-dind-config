FROM alpine:3.5


ENV KUBECTL_VERSION="v1.13.1"

RUN apk add --update ca-certificates curl openssl bash jq \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

ADD . /app/
WORKDIR app

CMD ["/bin/bash"]
