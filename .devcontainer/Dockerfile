ARG VARIANT="26.04"
FROM ubuntu:${VARIANT}

ARG TAMINARU_USER="taminaru"
ARG TAMINARU_UID=1000

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends ca-certificates curl git sudo \
    && if getent passwd ${TAMINARU_UID} >/dev/null; then \
        useradd --create-home --shell /bin/bash ${TAMINARU_USER}; \
    else \
        useradd --uid ${TAMINARU_UID} --create-home --shell /bin/bash ${TAMINARU_USER}; \
    fi \
    && echo "${TAMINARU_USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${TAMINARU_USER} \
    && chmod 0440 /etc/sudoers.d/${TAMINARU_USER} \
    && rm -rf /var/lib/apt/lists/*

# Ensure mise activation is in .bashrc (idempotent, fixes legacy ~/.local/bin path, guarded)
RUN bash -c ' \
        sed -i "s|~/.local/bin/mise|mise|g" /home/${TAMINARU_USER}/.bashrc || true; \
        if grep -q "mise activate bash" /home/${TAMINARU_USER}/.bashrc; then \
            sed -i "s|.*mise activate bash.*|command -v mise >/dev/null 2>\&1 \&\& eval \"\$(mise activate bash)\"|" /home/${TAMINARU_USER}/.bashrc; \
        else \
            echo "command -v mise >/dev/null 2>&1 && eval \"\$(mise activate bash)\"" >> /home/${TAMINARU_USER}/.bashrc; \
        fi; \
        chown ${TAMINARU_USER}:${TAMINARU_USER} /home/${TAMINARU_USER}/.bashrc \
    '

USER ${TAMINARU_USER}
WORKDIR /home/${TAMINARU_USER}
