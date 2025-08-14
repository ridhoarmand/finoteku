FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG FLUTTER_CHANNEL=stable
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/usr/local/flutter \
    PATH=/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip xz-utils zip libglu1-mesa ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/flutter/flutter.git -b ${FLUTTER_CHANNEL} --depth 1 ${FLUTTER_HOME} \
    && flutter --version \
    && flutter precache --no-web \
    && yes | flutter doctor --android-licenses || true

RUN echo 'export PATH=/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH' >> /etc/profile.d/flutter.sh

RUN flutter doctor -v

USER vscode
WORKDIR /workspaces/finoteku
