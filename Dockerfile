FROM ubuntu:22.04 as installer
ARG TARGETARCH
RUN set -eux; apt-get update ; apt-get install -y curl

FROM installer as kubectl
RUN set -eux ; \
  curl -LfO "https://dl.k8s.io/release/v1.28.3/bin/linux/${TARGETARCH}/kubectl" ; \
  chmod +x ./kubectl

FROM ubuntu:22.04

COPY --from=installer /kubectl /usr/local/bin

WORKDIR /app
COPY app .
ENTRYPOINT [ "/app/entrypoint.sh" ]
