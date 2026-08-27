#!/usr/bin/env python3
"""Build a NoCloud seed ISO (volid 'cidata') using pycdlib.

Fallback used when cloud-localds/genisoimage/mkisofs are unavailable.

Usage:
  build_seed_iso.py OUTPUT USER_DATA META_DATA [NETWORK_CONFIG]
"""
import sys

import pycdlib


def main() -> int:
    output, user_data, meta_data = sys.argv[1], sys.argv[2], sys.argv[3]
    network_config = sys.argv[4] if len(sys.argv) > 4 else None

    iso = pycdlib.PyCdlib()
    iso.new(joliet=3, rock_ridge="1.09", vol_ident="cidata")

    def add(src: str, name: str) -> None:
        # ISO9660 level-1 names are capped at 8+3 chars, so we map to short
        # internal names; the Rock Ridge / Joliet names are what linux mounts
        # actually read (cloud-init needs exact lowercase names).
        short = {'user-data': 'USERDAT', 'meta-data': 'METADAT', 'network-config': 'NETCONF'}[name]
        iso.add_file(src, iso_path="/%s.;1" % short,
                     rr_name=name, joliet_path="/" + name)

    add(user_data, "user-data")
    add(meta_data, "meta-data")
    if network_config:
        add(network_config, "network-config")

    iso.write(output)
    iso.close()
    print(f"seed ISO written: {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
