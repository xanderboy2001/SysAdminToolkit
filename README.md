
# SysAdmin Toolkit

[![GitHub issues](https://img.shields.io/github/issues/xanderboy2001/SysAdminToolkit?style=for-the-badge)](https://github.com/xanderboy2001/SysAdminToolkit/issues)
[![GitHub stars](https://img.shields.io/github/stars/xanderboy2001/SysAdminToolkit?style=for-the-badge)](https://github.com/xanderboy2001/SysAdminToolkit/stargazers)
[![GitHub license](https://img.shields.io/github/license/xanderboy2001/SysAdminToolkit?style=for-the-badge)](https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE)

---

## Table of Contents

1. [About the Project](#about-the-project)
2. [Built With](#built-with)
3. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Installation](#installation)
4. [Usage](#usage)
5. [Roadmap](#roadmap)
6. [Contributing](#contributing)
7. [License](#license)
8. [Contact](#contact)
9. [Acknowledgments](#acknowledgments)

---

## About The Project

The **SysAdmin Toolkit** is a PowerShell-based module meant to streamline administrative tasks by offering a menu-driven interface. It contains utilities for both *server* and *client* operations, with menus for Active Directory, Microsoft Graph, and future extensions. The goal is to provide a clean, navigable toolkit for sysadmins to run scripts without memorizing commands.

---

## Built With

- PowerShell (works on Windows PowerShell and PowerShell 7+)
- Modular design: split into `.psm1`, `.psd1`, and `.ps1` files
- Readable menus and prompts via ANSI colors

---

## Getting Started

### Prerequisites

Make sure you have:

- [PowerShell](https://github.com/powershell/powershell) installed (5.1 or later recommended)
- Git (if you want to clone the repo)

---

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/xanderboy2001/SysAdminToolkit.git
   ```
2. Ensure the folder structure remains:
   ```
   SysAdminToolkit/
      SysAdminToolkit.psd1
      SysAdminToolkit.psm1
      Public/
         ... (menu and command scripts)
      Private/
         ... (helper scripts, utils)
   ```
3. (Recommended) Copy the folder into your personal PowerShell modules directory:
   ```powershell
   $dest = Join-Path $HOME 'Documents/PowerShell/Modules/SysAdminToolkit'
   Copy-Item -Recurse -Path 'C:/path/to/downloaded/SysAdminToolkit' -Destination $dest
   ```
4. Import the module in PowerShell:
   ```powershell
   Import-Module SysAdminToolkit -Force
   ```

   Or if not in a standard module path (you didn't follow step 3):

   ```powershell
   Import-Module 'C:/full/path/to/SysAdminToolkit' -Force
   ```
5. Launch the toolkit menu:
   ```powershell
   Start-ToolkitMenu
   ```

---

## Usage

When you run `Start-ToolkitMenu`, you will see a top-level menu. Options include:

- **Server** - Opens the server tools menu:
   - **Active Directory** - Tools for password reset, account unlock, disable user, create user
   - (Other submodules planned, e.g. Microsoft Graph, Troubleshooting)
- **Client** - Reserved for future client‑side utilities (e.g. local user management, workstation scripts)

Select menu options using the number keys (e.g. `1` for Server), or use `Q`, `Quit`, `E`, `Exit`, `C`, `Cancel` to exit. Use `B`, `Back` when prompted to return to the previous menu.

---

## Example

```powershell
Import-Module SysAdminToolkit -Force
Start-ToolkitMenu
# ... choose 1 (Server), then 1 (Active Directory), then 2 (Unlock Account)
```

---

## Roadmap

- [ ] Implement real scripts under `Public/Server/ActiveDirectory`
- [ ] Add Microsoft Graph menu functionality
- [ ] Implement a “Troubleshooting” submenu under Server
- [ ] Add more client-side tools and menu options
- [ ] Improve error-handling and validation
- [ ] Publish to PowerShell Gallery

---

## Contributing

Contributions are welcome! Here’s how you can help:

1. Fork the project
2. Create a branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to your fork (`git push origin feature/YourFeature`)
5. Open a Pull Request

---

## License

Distributed under the **[GNU General Public License v3.0]**. See `LICENSE` for more information.

---

## Contact

- **Alexander Christian** — alexanderechristian@gmail.com
- **SysAdminToolkit**: [https://github.com/xanderboy2001/SysAdminToolkit](https://github.com/xanderboy2001/SysAdminToolkit)

---

## Acknowledgments

- Thanks to the [Best README Template by Othneildrew](https://github.com/othneildrew/Best-README-Template) for the structure
- Inspired by many PowerShell community tools
- 💡 Feel free to customize or add more badges as needed
