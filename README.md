![Freya Banner](https://raw.githubusercontent.com/Freya-Vivariums/.github/refs/heads/main/brand/Freya_banner.png)

The **Freya Vivarium Control System** project is mainly an installer for installing the other Freya components.

## Installation
Download and execute the installation script:
```
wget -O install.sh https://github.com/Freya-Vivariums/Freya-Vivarium-Control-System/releases/latest/download/install.sh;
chmod +x ./install.sh;
sudo ./install.sh;
```
> [!NOTE]
> This installation script will automatically install the system sensors and actuators drivers, too. No manual installation is required.
## The `edgeberry.json` manifest
Freya runs on an [Edgeberry](https://github.com/Edgeberry) device as *the* application on it, and `edgeberry.json` is how it describes itself to the device software. The installation script registers it once:
```
sudo edgeberry --register-application /opt/Freya
```
Only the path is stored. The manifest stays inside the application directory and is re-read on every start, so shipping a new release updates what the device knows about Freya without re-registering. Registration refuses everything and exits non-zero if any part of the file is invalid, so a packaging mistake surfaces at install time rather than months later.

| Field | What it does |
|---|---|
| `name` | Identifies the application. Slugified, it also names the nginx config Edgeberry generates for it (`freya.conf`) |
| `version`, `description` | Descriptive metadata about the installed application |
| `ui.port` | The port Node-RED listens on. Everything under `/application/` is proxied here with the prefix stripped, so `http://<device>/application/editor` reaches the Node-RED editor |
| `branding` | Brands the **Edgeberry device interface**: `logo` replaces the Edgeberry logo in its navigation bar, `mark` becomes the browser tab icon, and `colors` (`fg`, `bg`, `primary`) restyle it in Freya's colours. Paths are relative to the application directory and may not point outside it |
| `service` | The systemd unit Edgeberry may act on, and which lifecycle actions it may perform. Freya allows `restart`, `stop` and `start`, which is what the Device Hub's buttons drive |

> [!NOTE]
> `branding` styles the Edgeberry device interface around Freya, not the Node-RED editor itself — the editor's own look is the theme in [`nodered/theme`](nodered/theme).

Because nginx strips the `/application` prefix, an **absolute** URL in served markup escapes it and lands on the device's catch-all. Relative URLs resolve against whatever prefix they are served under and need no changes; anything that must be absolute should read the `X-Forwarded-Prefix: /application` header.

## License & Collaboration
**Copyright© 2026 Sanne 'SpuQ' Santens**. The Freya Vivarium Control System project is licensed under the **[MIT License](LICENSE.txt)**. The [Rules & Guidelines](https://github.com/Freya-Vivariums/.github/blob/main/brand/Freya_Trademark_Rules_and_Guidelines.md) apply to the usage of the Freya Vivariums™ brand.

### Collaboration

If you'd like to contribute to this project, please follow these guidelines:
1. Fork the repository and create your branch from `main`.
2. Make your changes and ensure they adhere to the project's coding style and conventions.
3. Test your changes thoroughly.
4. Ensure your commits are descriptive and well-documented.
5. Open a pull request, describing the changes you've made and the problem or feature they address.