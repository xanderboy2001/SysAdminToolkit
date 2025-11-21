
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
2. Navigate into the folder:
   ```powershell
   cd SysAdminToolkit
   ```
3. To run the toolkit, execute:
   ```powershell
   .\Toolkit.ps1
   ```

---

## Usage

Once you run `Toolkit.ps1`, you'll see a menu like:

```
=== SysAdmin Toolkit ===
1. Server
2. Client
```

- Select **Server** to access submenus like Active Directory.
- Within the **Active Directory** menu, you’ll find options: *Reset Password*, *Unlock Account*, *Disable User*, *Create User*. Each option currently runs a placeholder or script.
- Use the **Quit** or **Back** commands (e.g. `Q`, `Exit`, `B`) when prompted to navigate or exit.

---

## Roadmap

- [ ] Implement real scripts under `Modules/SysAdminToolkit/Server/ActiveDirectory/Scripts`
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
