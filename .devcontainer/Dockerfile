ARG VARIANT="26.04"
FROM ubuntu:${VARIANT}

ARG TAMINARU_USER="taminaru"
ARG TAMINARU_UID=1000

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends ca-certificates curl git sudo \
    && rm -rf /var/lib/apt/lists/*

USER ${TAMINARU_USER}
WORKDIR /home/${TAMINARU_USER}
