# WuWek Linux Launcher Script

A unified Bash script designed to manage and launch WuWek on Linux, handling patching, separate launcher execution, and game execution with various enhancements.

## Features

- **Multiple Modes:**
  - `game` (Default): Launches the game with DXVK, optional wrappers, and custom arguments. Uses a dedicated game prefix.
  - `launcher`: Runs the original native game launcher (`launcher.exe` by default) cleanly in its own dedicated prefix, useful for checking for updates.
  - `patch`: Applies a specific binary patch to `launcher_main.dll` (useful for certain game versions).
- **Simplified Configuration:** Uses a single `GAME_ROOT_DIR` variable to derive most paths, assuming a consistent folder structure.
- **DXVK Management:** Automatically installs DXVK from a specified source directory into the game prefix on the first run (or after manual reset).
- **Optional Wrappers:** Easily toggle Feral GameMode (`gamemode`) and MangoHud via command-line options when running in `game` mode.
- **Custom Overrides:** Apply custom Wine DLL overrides (`WINEDLLOVERRIDES`).
- **Argument Handling:** Pass additional arguments directly to the game when running in `game` mode.

## Requirements

- **Wine:** A specific version of Wine is recommended (path configured in the script). System Wine can be used if the configured path is empty.
- **`bbe` (Binary Block Editor):** Required **only** for the `patch` mode. Install via your distribution's package manager (e.g., `sudo apt install bbe`, `sudo pacman -S bbe`).
- **(Optional) `gamemode`:** Required if using the `-g` / `--gamemode` option in `game` mode. (From FeralInteractive/gamemode).
- **(Optional) `mangohud`:** Required if using the `-m` / `--mangohud` option in `game` mode.

## Setup & Configuration

1.  **Download/Clone:** Get the script (e.g., `wuwek.sh`) into your desired location.
2.  **Make Executable:** Open a terminal and run:
    ```bash
    chmod +x wuwek.sh
    ```
3.  **Edit Configuration:** Open the script file (`wuwek.sh`) in a text editor.
    - **Crucial:** Locate the `GAME_ROOT_DIR` variable and set it to the **full path** of your main WuWek installation directory (the one containing `components`, `prefixes`, `launcher.exe`, etc.).
      ```bash
      # Example:
      GAME_ROOT_DIR="$HOME/Games/WuWek"
      ```
    - **Verify Game Executable Path:** Double-check the `GAME_EXE_ARG` variable. Ensure the relative path correctly points to the main game executable (e.g., `Client-Win64-Shipping.exe`) _within_ your `GAME_ROOT_DIR`. The default might need adjustment.
      ```bash
      # Example - VERIFY THIS RELATIVE PATH:
      GAME_EXE_ARG="${GAME_ROOT_DIR_RESOLVED}/WuWek Game/Client/Binaries/Win64/Client-Win64-Shipping.exe"
      ```
    - **(Optional) Wine Command:** Set `WINE_CMD` to the full path of your preferred Wine binary, or leave it as `""` to use the system's default `wine`.
    - **(Optional) DXVK Source:** Ensure `DXVK_SOURCE_DIR` points to the extracted folder of the DXVK version you want the script to potentially auto-install (must contain `x64` and `x32` subfolders).
    - **(Optional) Other Settings:** Review other variables like `BASE_GAME_ARGS_ARRAY`, `ADDITIONAL_OVERRIDES`, `ENABLE_DXVK`, etc., and adjust if needed. Most other paths are derived automatically from `GAME_ROOT_DIR`.

## Usage

Run the script from your terminal.

**Modes:**

- **Run the Game (Default Mode):**
  ```bash
  ./wuwek.sh [options] [additional_game_args...]
  # OR explicitly:
  ./wuwek.sh game [options] [additional_game_args...]
  ```
- **Run the Native Launcher (e.g., for updates):**
  ```bash
  ./wuwek.sh launcher
  ```
- **Apply the DLL Patch:**
  ```bash
  ./wuwek.sh patch
  ```

**Options (Only for `game` mode):**

- `-m`, `--mangohud`: Enable MangoHud overlay.
- `-g`, `--gamemode`: Use `gamemoderun` wrapper.
- `-h`, `--help`: Show help and configuration summary.

**Additional Game Arguments (Only for `game` mode):**

Any arguments provided after the mode (if specified) and options will be passed directly to the game launcher, _after_ the hardcoded `BASE_GAME_ARGS_ARRAY`.

**Examples:**

```bash
# Run game with default settings
./wuwek.sh

# Run game with MangoHud enabled
./wuwek.sh -m

# Run game with GameMode and an extra argument
./wuwek.sh -g --skip-videos

# Run game with both wrappers and multiple extra arguments
./wuwek.sh -m -g --skip-videos --another-arg="some value"

# Run the original launcher
./wuwek.sh launcher

# Apply the patch
./wuwek.sh patch

# Show help/config
./wuwek.sh -h
```
