#!/usr/bin/env python3
"""Templating for the cloud-init user-data file.

Replaces scalar placeholders and inlines guest/container source files as
6-space-indented YAML literal blocks (replacing a lone token line).

Usage:
  template_userdata.py TMPDIR REPO ADMIN_KEY_PATH ADMIN_USER HOSTNAME CONTAINER_IMAGE
"""
import pathlib
import sys


def main() -> int:
    tmpdir, repo, admin_key_path, admin_user, hostname, container_image = sys.argv[1:7]

    sources = {
        "__SANDBOX_SHELL_CONTENT__": f"{repo}/vm/guest/bin/sandbox-shell",
        "__SANDBOX_USER_CONTENT__": f"{repo}/vm/guest/bin/sandbox-user",
        "__SANDBOX_FIREWALL_CONTENT__": f"{repo}/vm/guest/bin/sandbox-firewall",
        "__SANDBOX_POLICY_CONTENT__": f"{repo}/vm/guest/bin/sandbox-policy",
        "__POLICY_BALANCED_CONTENT__": f"{repo}/vm/guest/policy-presets/balanced.txt",
        "__POLICY_OPEN_CONTENT__": f"{repo}/vm/guest/policy-presets/open.txt",
        "__POLICY_LOCKED_CONTENT__": f"{repo}/vm/guest/policy-presets/locked.txt",
        "__BUILD_CONTAINER_CONTENT__": f"{repo}/vm/guest/lib/build-container.sh",
        "__CONTAINERFILE_CONTENT__": f"{repo}/container/Containerfile",
        "__ENTRYPOINT_CONTENT__": f"{repo}/container/entrypoint.sh",
        "__MISE_TOML_CONTENT__": f"{repo}/container/files/mise.toml",
        "__BASHRC_CONTENT__": f"{repo}/container/files/dotfiles/bashrc",
        "__PROFILE_PS1_CONTENT__": f"{repo}/container/files/dotfiles/profile.ps1",
        "__GITCONFIG_CONTENT__": f"{repo}/container/files/dotfiles/gitconfig",
        "__GITIGNORE_GLOBAL_CONTENT__": f"{repo}/container/files/dotfiles/gitignore_global",
        "__INPUTRC_CONTENT__": f"{repo}/container/files/dotfiles/inputrc",
        "__EDITORCONFIG_CONTENT__": f"{repo}/container/files/dotfiles/editorconfig",
        "__START_PWSH_CONTENT__": f"{repo}/container/files/start-pwsh.sh",
        "__FENRIR_CONTENT__": f"{repo}/container/files/fenrir",
        "__GLEIPHNIR_CONTENT__": f"{repo}/vm/files/gleiphnir",
        "__FENRIR_SPEC_CONTENT__": f"{repo}/container/files/carapace/specs/fenrir.yaml",
        "__GLEIPHNIR_SPEC_CONTENT__": f"{repo}/vm/files/carapace/specs/gleiphnir.yaml",
        "__SESSION_LOGGER_CONTENT__": f"{repo}/vm/guest/bin/sandbox-session-logger",
        "__SANDBOX_PROXY_CONTENT__": f"{repo}/vm/guest/bin/sandbox-proxy",
        "__SANDBOX_SECRETS_CONTENT__": f"{repo}/vm/guest/bin/sandbox-secrets",
        "__SANDBOX_JOURNAL_CONTENT__": f"{repo}/vm/guest/bin/sandbox-journal",
        "__SANDBOX_SBOM_CONTENT__": f"{repo}/vm/guest/bin/sandbox-sbom",
        "__SANDBOX_TOOLS_CONTENT__": f"{repo}/vm/guest/bin/sandbox-tools",
    }

    p = pathlib.Path(tmpdir) / "user-data"
    text = p.read_text()

    pub = pathlib.Path(admin_key_path).read_text().strip()
    text = text.replace("__ADMIN_SSH_PUB__", pub)
    text = text.replace("__ADMIN_USER__", admin_user)
    text = text.replace("__VM_HOSTNAME__", hostname)
    text = text.replace("__CONTAINER_IMAGE__", container_image)

    for token, src_path in sources.items():
        src = pathlib.Path(src_path)
        if not src.exists():
            print(f"WARNING: source not found for {token}: {src_path}")
            content_indented = "      # (missing source: " + src_path + ")\n"
        else:
            lines = src.read_text().splitlines()
            content_indented = "\n".join("      " + line for line in lines) + "\n"
        if token in text:
            text = text.replace(token, content_indented.rstrip("\n"))
        else:
            print(f"WARNING: token {token} not found in template")

    p.write_text(text)
    print("user-data templated with inlined guest/container sources")
    return 0


if __name__ == "__main__":
    sys.exit(main())
