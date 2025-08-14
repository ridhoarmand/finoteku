FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG FLUTTER_CHANNEL=stable
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/usr/local/flutter \
    PUB_CACHE=/home/vscode/.pub-cache \
    PATH=/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip xz-utils zip libglu1-mesa ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/flutter/flutter.git -b ${FLUTTER_CHANNEL} --depth 1 ${FLUTTER_HOME} \
    && git config --system --add safe.directory ${FLUTTER_HOME} \
    && flutter --version \
    && flutter precache --no-web \
    && yes | flutter doctor --android-licenses || true \
    && mkdir -p /home/vscode/.pub-cache \
    && chown -R vscode:vscode ${FLUTTER_HOME} /home/vscode/.pub-cache

RUN echo 'export PATH=/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH' >> /etc/profile.d/flutter.sh

RUN flutter doctor -v

USER vscode
WORKDIR /workspaces/finoteku
# Verifikasi akses tulis oleh user biasa (akan cache ke ~/.pub-cache)
RUN flutter doctor -v && dart --version