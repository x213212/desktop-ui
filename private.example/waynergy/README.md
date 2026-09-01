# Waynergy private configuration

The optional unit expects the Waynergy binary at
`~/.local/libexec/waynergy/waynergy` and its private configuration directory at
`~/.config/waynergy`. Keep the server address, client identity, TLS certificate
and key out of this repository.

Use the sample shipped by the exact Waynergy build you installed, then verify
it interactively before enabling the unit:

```bash
~/.local/libexec/waynergy/waynergy --help
systemctl --user enable --now waynergy-client.service
journalctl --user -u waynergy-client.service
```

Waynergy and Deskflow are mutually exclusive in the bundled units. Disable one
before enabling the other.
