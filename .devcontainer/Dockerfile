ARG VARIANT="26.04"
FROM ubuntu:${VARIANT}

ARG TAMINARU_USER="taminaru"
ARG TAMINARU_UID=1000

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends ca-certificates curl git sudo \
    && rm -rf /var/lib/apt/lists/*

# Non-root user (matches devcontainer.json "remoteUser") with passwordless
# sudo, provisioned by the same script the bootstrap uses.
COPY scripts/bootstrap/provision-user.sh /tmp/provision-user.sh
RUN TAMINARU_USER="$TAMINARU_USER" TAMINARU_UID="$TAMINARU_UID" bash /tmp/provision-user.sh \
    && rm -f /tmp/provision-user.sh

USER ${TAMINARU_USER}
WORKDIR /home/${TAMINARU_USER}
