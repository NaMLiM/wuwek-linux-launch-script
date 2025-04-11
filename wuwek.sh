#!/bin/bash
# Unified script for WuWek: Patching, Launcher, and Game modes.
# Uses a single GAME_ROOT_DIR for portability.

# --- HARDCODED CONFIGURATION ---
# !!! ONLY EDIT GAME_ROOT_DIR UNLESS YOUR FOLDER STRUCTURE IS DIFFERENT !!!

# --- Main Game Root Configuration ---
# Set this to the main directory containing the game files, prefixes, components etc.
# All other paths will be derived from this.
GAME_ROOT_DIR="$HOME/path/to/game/launcher" # <<< EDIT THIS PATH >>>

# --- Derived Paths (DO NOT EDIT THESE NORMALLY) ---
# Resolve the root directory path (handles ~)
GAME_ROOT_DIR_RESOLVED=$(eval echo "$GAME_ROOT_DIR")

# --- Wine Prefixes ---
LAUNCHER_PREFIX="${GAME_ROOT_DIR_RESOLVED}/launcher_prefixes"
GAME_PREFIX="${GAME_ROOT_DIR_RESOLVED}/prefixes"
# --- Wine Command ---
# Set WINE_CMD to "" or comment out if you want to use system Wine instead.
WINE_CMD="${GAME_ROOT_DIR_RESOLVED}/components/wine/bin/wine" # Assumes Wine is here
# --- Launchers ---
NATIVE_LAUNCHER_EXE="${GAME_ROOT_DIR_RESOLVED}/launcher.exe" # Assumes launcher is at root
JADEITE_LAUNCHER_EXE="${GAME_ROOT_DIR_RESOLVED}/components/jadeite/jadeite.exe"
# --- Game Mode Settings ---
# !! IMPORTANT !! Verify this relative path points to the correct game executable within your GAME_ROOT_DIR
GAME_EXE_ARG="${GAME_ROOT_DIR_RESOLVED}/WuWek Game/Client/Binaries/Win64/Client-Win64-Shipping.exe" # Example Path - VERIFY THIS
# Base arguments passed AFTER the game path in 'game' mode.
BASE_GAME_ARGS_ARRAY=("--")
# --- DXVK Setup (Game Mode Only) ---
ENABLE_DXVK=true
DXVK_SOURCE_DIR="${GAME_ROOT_DIR_RESOLVED}/components/dxvk" # Assumes DXVK source is here
DXVK_HUD_OPTIONS=""
DXVK_FLAG_FILE_NAME=".dxvk_installed_flag" # Flag file will be inside GAME_PREFIX
# --- Other Overrides (Game Mode Only) ---
ADDITIONAL_OVERRIDES="KRSDKExternal.exe=d"
# --- Patcher Mode Settings ---
PATCHER_BASE_DIR="${GAME_ROOT_DIR_RESOLVED}" # Patcher looks for version dirs here
PATCHER_TARGET_DLL="launcher_main.dll"

# --- END CONFIGURATION ---

# --- Runtime Variables ---
SCRIPT_MODE="game" # Default mode
USE_MANGO HUD=false # Game mode only toggle
USE_GAMEMODE=false # Game mode only toggle
EXTRA_GAME_ARGS_ARRAY=() # Game mode only extra args
WINE_TO_USE="" # Determined later

# --- FUNCTIONS ---

show_help() {
  echo "Usage: $(basename "$0") [mode] [options] [additional_game_args...]"
  echo
  echo "Unified script for WuWek."
  echo "Paths are derived from GAME_ROOT_DIR set in the script."
  echo
  echo "Modes:"
  echo "  game      (Default) Runs the game via Jadeite launcher with DXVK, wrappers,"
  echo "            overrides, and arguments (uses GAME_PREFIX)."
  echo "  launcher  Runs the original native launcher cleanly (uses LAUNCHER_PREFIX)."
  echo "  patch     Applies the transparency patch to '$PATCHER_TARGET_DLL'."
  echo
  echo "Options (Only apply to 'game' mode):"
  echo "  -m, --mangohud         Enable MangoHud overlay."
  echo "  -g, --gamemode         Enable Feral GameMode (gamemoderun)."
  echo "  -h, --help             Show this help message and exit."
  echo
  echo "Arguments (Only apply to 'game' mode):"
  echo "  [additional_game_args...]  Append to the game's launch arguments."
  echo
  echo "Current Configuration:"
  echo "  Game Root:        $GAME_ROOT_DIR_RESOLVED"
  echo "  Game Prefix:      $GAME_PREFIX"
  echo "  Launcher Prefix:  $LAUNCHER_PREFIX"
  local wine_cmd_display="${WINE_CMD:-System Default}"
  echo "  Wine Command:     $wine_cmd_display"
  echo "  Game Launcher:    $JADEITE_LAUNCHER_EXE"
  echo "  Native Launcher:  $NATIVE_LAUNCHER_EXE"
  echo
  echo "Note on DXVK Updates (Game Mode):"
  echo "  Update files in '$DXVK_SOURCE_DIR',"
  echo "  then delete '$GAME_PREFIX/$DXVK_FLAG_FILE_NAME' to force reinstall on next 'game' run."
  exit 0
}

# Checks and copies DXVK files if needed for the GAME_PREFIX
install_dxvk_if_needed() {
  local prefix_path="$1" # Should be GAME_PREFIX
  local dxvk_source_path="$2" # Should be DXVK_SOURCE_DIR
  local flag_file_path="$prefix_path/$DXVK_FLAG_FILE_NAME"

  if [[ "$ENABLE_DXVK" != "true" || -z "$dxvk_source_path" ]]; then return 0; fi
  if [[ -f "$flag_file_path" ]]; then echo "Info [Game Mode]: DXVK flag file found. Skipping DXVK copy."; return 0; fi

  echo "Info [Game Mode]: DXVK flag file not found. Attempting DXVK installation/update..."
  local dxvk_source_x64="$dxvk_source_path/x64"; local dxvk_source_x32="$dxvk_source_path/x32"
  if [[ ! -d "$dxvk_source_path" || ! -d "$dxvk_source_x64" || ! -d "$dxvk_source_x32" ]]; then
      echo "Error [Game Mode]: DXVK Source ('$dxvk_source_path') or subfolders (x64/x32) not found." >&2; return 1; fi

  local target_system32="$prefix_path/drive_c/windows/system32"; local target_syswow64="$prefix_path/drive_c/windows/syswow64"
  mkdir -p "$target_system32" "$target_syswow64"; local all_copied=true

  echo "Info [Game Mode]: Copying x64 DXVK DLLs..."; cp -v "$dxvk_source_x64/"{d3d9,d3d10core,d3d11,dxgi}.dll "$target_system32/" || all_copied=false
  echo "Info [Game Mode]: Copying x32 DXVK DLLs..."; cp -v "$dxvk_source_x32/"{d3d9,d3d10core,d3d11,dxgi}.dll "$target_syswow64/" || all_copied=false

  if [[ "$all_copied" == "true" ]]; then echo "Info [Game Mode]: DXVK DLLs copied successfully."; touch "$flag_file_path"; echo "Info [Game Mode]: Created flag file '$flag_file_path'."; return 0
  else echo "Error [Game Mode]: Failed to copy DXVK DLLs."; return 1; fi
}

# Function to run the patcher logic
run_patcher() {
    echo "--- Running Patcher Mode ---"
    local base_dir_resolved="$PATCHER_BASE_DIR" # Already resolved

    if ! command -v bbe &> /dev/null; then echo "Error [Patcher Mode]: bbe is not installed." >&2; return 1; fi

    local version_dir=$(find "$base_dir_resolved" -maxdepth 1 -type d -name "[0-9]*.[0-9]*.[0-9]*.[0-9]*" | sort -V | tail -n1)
    if [[ -z "$version_dir" ]]; then echo "Error [Patcher Mode]: No version directory found in '$base_dir_resolved'." >&2; return 1; fi
    echo "Info [Patcher Mode]: Using version directory: $version_dir"

    local target_dll_path="$version_dir/$PATCHER_TARGET_DLL"
    if [[ ! -f "$target_dll_path" ]]; then echo "Error [Patcher Mode]: Target DLL not found: '$target_dll_path'" >&2; return 1; fi

    if ! grep -a -q $'\x12AllowsTransparency' "$target_dll_path"; then echo "Info [Patcher Mode]: '$PATCHER_TARGET_DLL' is already patched or does not contain expected pattern."; return 0; fi

    local backup_dll_path="${target_dll_path}.bak"
    echo "Info [Patcher Mode]: Backing up '$target_dll_path' to '$backup_dll_path'..."; mv "$target_dll_path" "$backup_dll_path" || { echo "Error: Failed backup."; return 1; }
    echo "Info [Patcher Mode]: Applying patch using bbe..."; bbe -e "s/\x12AllowsTransparency/\x09IsEnabled\x1bA\x00\x03AAAAA/" "$backup_dll_path" > "$target_dll_path" || { echo "Error: bbe patch failed. Restoring."; mv "$backup_dll_path" "$target_dll_path"; return 1; }

    echo "Info [Patcher Mode]: Patch applied successfully."
    return 0
}

# Function to run the native launcher cleanly
run_launcher() {
    echo "--- Running Launcher Mode ---"
    local prefix_resolved="$LAUNCHER_PREFIX"
    local launcher_exe_resolved="$NATIVE_LAUNCHER_EXE"

    # Validate paths specific to this mode
    local prefix_parent_dir=$(dirname "$prefix_resolved")
    if [[ ! -d "$prefix_parent_dir" ]]; then echo "Error [Launcher Mode]: Parent directory for prefix ('$prefix_parent_dir') does not exist." >&2; return 1; fi
    if [[ ! -f "$launcher_exe_resolved" ]]; then echo "Error [Launcher Mode]: Native launcher EXE not found: '$launcher_exe_resolved'" >&2; return 1; fi

    echo "Prefix:     $prefix_resolved"; echo "Wine:       $WINE_TO_USE"; echo "Launcher:   $launcher_exe_resolved"
    echo "(No extra arguments, DXVK, overrides, or wrappers)"

    export WINEPREFIX="$prefix_resolved"
    unset WINEDLLOVERRIDES DXVK_HUD DXVK_ENABLE_NVAPI # Ensure clean environment

    echo "----------------------------"; echo "--- Running Command ---"
    echo "Command: \"$WINE_TO_USE\" \"$launcher_exe_resolved\""; echo "----------------------------"
    "$WINE_TO_USE" "$launcher_exe_resolved"
    return $?
}

# Function to run the game via Jadeite launcher
run_game() {
    echo "--- Running Game Mode ---"
    local prefix_resolved="$GAME_PREFIX"
    local launcher_exe_resolved="$JADEITE_LAUNCHER_EXE"
    local game_exe_arg_resolved="$GAME_EXE_ARG"
    local dxvk_source_resolved="$DXVK_SOURCE_DIR"

    # Validate paths specific to this mode
    local prefix_parent_dir=$(dirname "$prefix_resolved")
    if [[ ! -d "$prefix_parent_dir" ]]; then echo "Error [Game Mode]: Parent directory for prefix ('$prefix_parent_dir') does not exist." >&2; return 1; fi
    if [[ ! -f "$launcher_exe_resolved" ]]; then echo "Error [Game Mode]: Jadeite launcher EXE not found: '$launcher_exe_resolved'" >&2; return 1; fi
    if [[ ! -f "$game_exe_arg_resolved" ]]; then echo "Warning [Game Mode]: Game EXE Arg path not found: '$game_exe_arg_resolved'. Launcher might fail." >&2; fi


    # Attempt DXVK Installation/Update for the game prefix
    install_dxvk_if_needed "$prefix_resolved" "$dxvk_source_resolved"
    # [[ $? -ne 0 ]] && return 1 # Optional: Halt if DXVK install fails

    # Validate optional tools if enabled
    local effective_gamemode=$USE_GAMEMODE; local effective_mangohud=$USE_MANGO HUD
    if [[ "$effective_gamemode" == "true" ]] && ! command -v gamemoderun &> /dev/null; then echo "Warning [Game Mode]: GameMode requested (-g) but 'gamemoderun' not found. Disabling." >&2; effective_gamemode=false; fi
    if [[ "$effective_mangohud" == "true" ]] && ! command -v mangohud &> /dev/null; then echo "Warning [Game Mode]: MangoHud requested (-m) but 'mangohud' not found. Disabling." >&2; effective_mangohud=false; fi

    local ALL_GAME_ARGS=("${BASE_GAME_ARGS_ARRAY[@]}" "${EXTRA_GAME_ARGS_ARRAY[@]}")
    echo "Prefix:     $prefix_resolved"; echo "Wine:       $WINE_TO_USE"; echo "Launcher:   $launcher_exe_resolved"
    echo "Game Exe Arg: $game_exe_arg_resolved"; echo "All Game Args: ${ALL_GAME_ARGS[*]}"
    echo "MangoHud:   $effective_mangohud"; echo "GameMode:   $effective_gamemode"

    export WINEPREFIX="$prefix_resolved"

    # --- Handle DLL Overrides (Game Mode Only) ---
    local current_overrides=""
    if [[ "$ENABLE_DXVK" == "true" ]]; then
      local dxvk_override_part="d3d9,d3d10core,d3d11,dxgi=n"; current_overrides="$dxvk_override_part"
      echo "Info [Game Mode]: Enabling DXVK overrides ($dxvk_override_part)."
      [[ -n "$DXVK_HUD_OPTIONS" ]] && export DXVK_HUD="$DXVK_HUD_OPTIONS" && echo "Info [Game Mode]: Enabling DXVK HUD ($DXVK_HUD_OPTIONS)." || unset DXVK_HUD
    else
      echo "Info [Game Mode]: DXVK overrides disabled."; unset DXVK_HUD
    fi
    if [[ -n "$ADDITIONAL_OVERRIDES" ]]; then
        echo "Info [Game Mode]: Adding custom overrides ($ADDITIONAL_OVERRIDES)."
        [[ -n "$current_overrides" ]] && current_overrides+=";$ADDITIONAL_OVERRIDES" || current_overrides="$ADDITIONAL_OVERRIDES"
    fi
    [[ -n "$current_overrides" ]] && export WINEDLLOVERRIDES="$current_overrides" || unset WINEDLLOVERRIDES
    # --- End Handle DLL Overrides ---

    echo "----------------------------"; echo "--- Running Command ---"
    [[ -n "${WINEDLLOVERRIDES+x}" ]] && echo "Effective Env: WINEDLLOVERRIDES=$WINEDLLOVERRIDES"
    [[ -n "${DXVK_HUD+x}" ]] && echo "Effective Env: DXVK_HUD=$DXVK_HUD"

    local final_command=()
    if [[ "$effective_gamemode" == "true" ]]; then final_command+=("gamemoderun"); fi
    if [[ "$effective_mangohud" == "true" ]]; then final_command+=("mangohud"); fi
    final_command+=("$WINE_TO_USE")
    final_command+=("$launcher_exe_resolved")
    final_command+=("$game_exe_arg_resolved")
    final_command+=("${ALL_GAME_ARGS[@]}")

    printf "Command: "; printf "%q " "${final_command[@]}"; printf "\n"; echo "----------------------------"
    "${final_command[@]}"
    return $?
}


# --- Argument Parsing ---
if [[ "$1" == "patch" || "$1" == "launcher" || "$1" == "game" ]]; then SCRIPT_MODE="$1"; shift;
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then show_help; fi # Handle help early

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mangohud) USE_MANGO HUD=true; shift ;;
    -g|--gamemode) USE_GAMEMODE=true; shift ;;
    -h|--help) show_help ;;
    *) EXTRA_GAME_ARGS_ARRAY+=("$1"); shift ;; # Assume extra arg for game mode
  esac
done

# --- Determine Wine Command (Common Step) ---
# Use configured WINE_CMD if set and valid, otherwise find system wine
if [[ -n "$WINE_CMD" ]]; then
  # WINE_CMD already contains the resolved path from config section
  if [[ ! -f "$WINE_CMD" || ! -x "$WINE_CMD" ]]; then
      echo "Error: Configured Wine command ('$WINE_CMD') not found or not executable." >&2; exit 1;
  fi
  WINE_TO_USE="$WINE_CMD"
else
  WINE_TO_USE=$(command -v wine)
  if [[ -z "$WINE_TO_USE" ]]; then echo "Error: WINE_CMD is empty and system 'wine' command not found." >&2; exit 1; fi
fi


# --- Main Execution Logic ---
exit_status=0
case "$SCRIPT_MODE" in
    patch) run_patcher ;;
    launcher) run_launcher ;;
    game) run_game ;;
    *) echo "Error: Invalid mode '$SCRIPT_MODE'. Use 'patch', 'launcher', or 'game'." >&2; show_help; exit 1 ;;
esac
exit_status=$? # Capture exit status from function

echo "----------------------------"
echo "Script finished mode '$SCRIPT_MODE' with exit status: $exit_status"
exit $exit_status