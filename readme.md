# WuWek Linux Launcher Script

A unified Bash script designed to manage and launch WuWek on Linux, handling patching, separate launcher execution, and game execution with various enhancements including DX11/DX12 selection.

## Features

- **Multiple Modes:**
  - `game` (Default): Launches the game with DXVK/VKD3D-Proton, optional wrappers, custom overrides, and specific argument handling. Uses a dedicated game prefix.
  - `launcher`: Runs the original native game launcher (`launcher.exe` by default) cleanly in its own dedicated prefix, useful for checking for updates.
  - `patch`: Applies a specific binary patch to `launcher_main.dll`.
- **DirectX Mode Selection:** Choose between DX11 (`--dx11`, default) or DX12 (`--dx12`) launch options for `game` mode. The script constructs the first argument passed to the game launcher accordingly.
- **DXVK & VKD3D-Proton Support:**
  - Uses DXVK for DX9/10/11 to Vulkan translation (if enabled).
  - Uses VKD3D-Proton overrides for DX12 to Vulkan translation when `--dx12` mode is selected (if enabled, requires manual/auto-install).
  - Automatically installs DXVK and/or VKD3D-Proton from source directories on first run/reset (optional).
- **Simplified Configuration:** Uses a single `GAME_ROOT_DIR` variable to derive most paths.
- **Optional Wrappers:** Easily toggle Feral GameMode (`gamemoderun`) and MangoHud via command-line options (`-g`, `-m`) in `game` mode.
- **Custom Overrides:** Apply custom Wine DLL overrides (`WINEDLLOVERRIDES`).
- **Specific Argument Handling:** Passes the game path, separator (`--`), and DX mode (`-d3d11` or `-d3d12`) as a single combined first argument to the game launcher (`jadeite.exe`), followed by any user-provided extra arguments.

## Requirements

- **Bash:** The script interpreter.
- **Wine:** A specific version of Wine is recommended (path configured in the script). System Wine can be used.
- **DXVK:** DLL files must be present in the `DXVK_SOURCE_DIR` specified in the script if using the auto-install feature with `ENABLE_DXVK=true`. Otherwise, manual installation in `GAME_PREFIX` is needed.
- **VKD3D-Proton:** DLL files must be present in the `HARDCODED_VKD3D_SOURCE_DIR` if using the auto-install feature with `ENABLE_VKD3D=true`. Otherwise, **manual installation** of `d3d12.dll` and `d3d12core.dll` into the `GAME_PREFIX` is required for `--dx12` mode to work correctly when `ENABLE_VKD3D=true`.
- **`bbe`:** Required **only** for the `patch` mode.
- **(Optional) `gamemoderun`:** Required for the `-g` / `--gamemode` option.
- **(Optional) `mangohud`:** Required for the `-m` / `--mangohud` option.

## Setup & Configuration

1.  **Download/Clone:** Get the script (e.g., `wuwek.sh`).
2.  **Make Executable:** `chmod +x wuwek.sh`
3.  **Edit Configuration:** Open `wuwek.sh` in a text editor.
    - **Crucial:** Set `GAME_ROOT_DIR` to the full path of your WuWek installation directory.
      ```bash
      # Example:
      GAME_ROOT_DIR="path/to/game/folder/launcher.exe"
      ```
    - **Verify Game Executable Path:** Ensure `GAME_EXE_PATH_VAR` correctly points to the relative path of the game executable within `GAME_ROOT_DIR`.
      ```bash
      # Example - VERIFY THIS RELATIVE PATH:
      GAME_EXE_PATH_VAR="${GAME_ROOT_DIR_RESOLVED}/Game Folder/Client/Binaries/Win64/Client-Win64-Shipping.exe"
      ```
    - **(Optional)** Set `WINE_CMD` or leave `""` for system Wine.
    - **(Optional)** Set `DXVK_SOURCE_DIR` and ensure `ENABLE_DXVK=true` for DXVK features/auto-install.
    - **(Optional)** Set `HARDCODED_VKD3D_SOURCE_DIR` and ensure `ENABLE_VKD3D=true` for VKD3D-Proton features/auto-install.
    - **(Optional)** Adjust `DEFAULT_DX_MODE`, `ADDITIONAL_OVERRIDES`, etc.

## Usage

Run the script from your terminal.

**Modes:**

- **Run the Game (Default Mode, Default DX):**
  ```bash
  ./wuwek.sh [options] [additional_game_args...]
  # OR explicitly:
  ./wuwek.sh game [options] [additional_game_args...]
  ```
  _(Passes `"<Game Path> -- -d3d11"` as the first argument to Jadeite, followed by additional args)_
- **Run Game in DX11 Mode:**
  ```bash
  ./wuwek.sh --dx11 [options] [additional_game_args...]
  ```
  _(Passes `"<Game Path> -- -d3d11"` as the first argument to Jadeite, followed by additional args)_
- **Run Game in DX12 Mode:**
  ```bash
  ./wuwek.sh --dx12 [options] [additional_game_args...]
  ```
  _(Passes `"<Game Path> -- -d3d12"` as the first argument to Jadeite, followed by additional args. Requires VKD3D setup as noted in Requirements)_
- **Run the Native Launcher:**
  ```bash
  ./wuwek.sh launcher
  ```
- **Apply the DLL Patch:**
  ```bash
  ./wuwek.sh patch
  ```

**Options (Only apply to `game` mode):**

- `--dx11`: Select DirectX 11 mode for the combined argument.
- `--dx12`: Select DirectX 12 mode for the combined argument.
- `-m`, `--mangohud`: Enable MangoHud overlay.
- `-g`, `--gamemode`: Use `gamemoderun` wrapper.
- `-h`, `--help`: Show help message.

**Additional Game Arguments (Only for `game` mode):**

Any arguments provided by the user on the command line are passed as **separate, subsequent arguments** AFTER the automatically constructed first argument (`"<Game Path> -- -d3d<11|12>"`).

**Examples:**

```bash
# Run game (uses default DX11)
./wuwek.sh

# Run game explicitly in DX11 mode with MangoHud
./wuwek.sh --dx11 -m

# Run game explicitly in DX12 mode with GameMode and an extra argument
# (Assumes VKD3D setup is correct)
./wuwek.sh --dx12 -g --some-extra-arg

# Run the original launcher
./wuwek.sh launcher

# Apply the patch
./wuwek.sh patch

# Show help/config
./wuwek.sh -h
```
