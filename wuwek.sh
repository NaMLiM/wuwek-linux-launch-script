#!/bin/bash
# Unified script for WuWek: Patching, Launcher, and Game modes.
# Uses a single GAME_ROOT_DIR, supports DX11/DX12 selection, VKD3D, wrappers.
# Passes game path + separator + dx mode as a single argument to jadeite.

# --- HARDCODED CONFIGURATION ---
# !!! ONLY EDIT GAME_ROOT_DIR UNLESS YOUR FOLDER STRUCTURE IS DIFFERENT !!!

# --- Main Game Root Configuration ---
GAME_ROOT_DIR="path/to/game/folder/launcher.exe" # <<< EDIT THIS PATH >>>

# --- Derived Paths (DO NOT EDIT THESE NORMALLY) ---
GAME_ROOT_DIR_RESOLVED=$(eval echo "$GAME_ROOT_DIR")
LAUNCHER_PREFIX="${GAME_ROOT_DIR_RESOLVED}/launcher_prefixes"
GAME_PREFIX="${GAME_ROOT_DIR_RESOLVED}/prefixes"
WINE_CMD="${GAME_ROOT_DIR_RESOLVED}/components/wine/bin/wine" # Set to "" or comment out for system wine
NATIVE_LAUNCHER_EXE="${GAME_ROOT_DIR_RESOLVED}/launcher.exe"
JADEITE_LAUNCHER_EXE="${GAME_ROOT_DIR_RESOLVED}/components/jadeite/jadeite.exe"
# !! IMPORTANT !! Verify this relative path points to the correct game executable
GAME_EXE_PATH_VAR="${GAME_ROOT_DIR_RESOLVED}/Wuthering Waves Game/Client/Binaries/Win64/Client-Win64-Shipping.exe"

# --- DXVK Setup (Game Mode - DX9/10/11) ---
ENABLE_DXVK=true
DXVK_SOURCE_DIR="${GAME_ROOT_DIR_RESOLVED}/components/dxvk"
DXVK_HUD_OPTIONS=""
DXVK_FLAG_FILE_NAME=".dxvk_installed_flag"

# --- VKD3D-Proton Setup (Game Mode - DX12) ---
ENABLE_VKD3D=true
HARDCODED_VKD3D_SOURCE_DIR="${GAME_ROOT_DIR_RESOLVED}/components/vkd3d-proton"
VKD3D_FLAG_FILE_NAME=".vkd3d_installed_flag"

# --- Game Mode Settings ---
DEFAULT_DX_MODE="dx11" # Default DirectX mode ("dx11" or "dx12")

# --- Other Overrides (Game Mode Only) ---
ADDITIONAL_OVERRIDES="KRSDKExternal.exe=d"

# --- Patcher Mode Settings ---
PATCHER_BASE_DIR="${GAME_ROOT_DIR_RESOLVED}"
PATCHER_TARGET_DLL="launcher_main.dll"

# --- END CONFIGURATION ---

# --- Runtime Variables ---
SCRIPT_MODE="game" # Default mode
USE_MANGO_HUD=false
USE_GAMEMODE=false
EXTRA_GAME_ARGS_ARRAY=()
WINE_TO_USE=""
SELECTED_DX_MODE="$DEFAULT_DX_MODE"

# --- FUNCTIONS ---

show_help() {
  echo "Usage: $(basename "$0") [mode] [options] [additional_game_args...]"
  echo
  echo "Unified script for Wuthering Waves."
  echo "Paths are derived from GAME_ROOT_DIR set in the script."
  echo
  echo "Modes:"
  echo "  game      (Default) Runs the game via Jadeite launcher. Uses GAME_PREFIX."
  echo "            Constructs first argument as: \"<Game Path> -- -d3d<11|12>\"" # Updated help
  echo "  launcher  Runs the original native launcher cleanly. Uses LAUNCHER_PREFIX."
  echo "  patch     Applies the transparency patch to '$PATCHER_TARGET_DLL'."
  echo
  echo "Options (Only apply to 'game' mode):"
  echo "  --dx11             Select DirectX 11 mode for the combined argument."
  echo "  --dx12             Select DirectX 12 mode for the combined argument."
  echo "                     (Default DX Mode: $DEFAULT_DX_MODE)"
  echo "  -m, --mangohud         Enable MangoHud overlay."
  echo "  -g, --gamemode         Enable Feral GameMode (gamemoderun)."
  echo "  -h, --help             Show this help message and exit."
  echo
  echo "Arguments (Only apply to 'game' mode):"
  echo "  [additional_game_args...]  Passed as separate arguments AFTER the automatically" # Updated help
  echo "                             constructed \"<Game Path> -- -d3d<11|12>\" argument."
  echo
  echo "Requirements Note:"
  echo "  - Using '--dx12' with ENABLE_VKD3D=true requires VKD3D-Proton DLLs"
  echo "    (d3d12.dll, d3d12core.dll) to be installed in GAME_PREFIX (manual or auto-install)."
  echo "  - Using '-m' requires 'mangohud'; '-g' requires 'gamemoderun'."
  echo "  - Using 'patch' mode requires 'bbe'."
  echo
  echo "Current Configuration:"
  echo "  Game Root:        $GAME_ROOT_DIR_RESOLVED"
  exit 0
}

# (install_dxvk_if_needed function remains the same)
install_dxvk_if_needed() {
  local prefix_path="$1"; local dxvk_source_path="$2"; local flag_file_path="$prefix_path/$DXVK_FLAG_FILE_NAME"
  if [[ "$ENABLE_DXVK" != "true" || -z "$dxvk_source_path" ]]; then return 0; fi
  if [[ -f "$flag_file_path" ]]; then echo "Info [Game Mode]: DXVK flag file found. Skipping DXVK copy."; return 0; fi
  echo "Info [Game Mode]: DXVK flag file not found. Attempting DXVK installation/update..."
  local dxvk_source_x64="$dxvk_source_path/x64"; local dxvk_source_x32="$dxvk_source_path/x32"
  if [[ ! -d "$dxvk_source_path" || ! -d "$dxvk_source_x64" || ! -d "$dxvk_source_x32" ]]; then echo "Error [Game Mode]: DXVK Source ('$dxvk_source_path') or subfolders (x64/x32) not found." >&2; return 1; fi
  local target_system32="$prefix_path/drive_c/windows/system32"; local target_syswow64="$prefix_path/drive_c/windows/syswow64"
  mkdir -p "$target_system32" "$target_syswow64"; local all_copied=true
  echo "Info [Game Mode]: Copying x64 DXVK DLLs..."; cp -v "$dxvk_source_x64/"{d3d9,d3d10core,d3d11,dxgi}.dll "$target_system32/" || all_copied=false
  echo "Info [Game Mode]: Copying x32 DXVK DLLs..."; cp -v "$dxvk_source_x32/"{d3d9,d3d10core,d3d11,dxgi}.dll "$target_syswow64/" || all_copied=false
  if [[ "$all_copied" == "true" ]]; then echo "Info [Game Mode]: DXVK DLLs copied successfully."; touch "$flag_file_path"; echo "Info [Game Mode]: Created flag file '$flag_file_path'."; return 0; else echo "Error [Game Mode]: Failed to copy DXVK DLLs."; return 1; fi
}

# (install_vkd3d_if_needed function remains the same)
install_vkd3d_if_needed() {
  local prefix_path="$1"; local vkd3d_source_path="$2"; local flag_file_path="$prefix_path/$VKD3D_FLAG_FILE_NAME"
  if [[ "$ENABLE_VKD3D" != "true" || -z "$vkd3d_source_path" ]]; then return 0; fi
  if [[ -f "$flag_file_path" ]]; then echo "Info [Game Mode]: VKD3D-Proton flag file found. Skipping VKD3D copy."; return 0; fi
  echo "Info [Game Mode]: VKD3D-Proton flag file not found. Attempting VKD3D installation/update..."
  local vkd3d_source_x64="$vkd3d_source_path/x64"; local vkd3d_source_x32="$vkd3d_source_path/x32"
  if [[ ! -d "$vkd3d_source_path" || ! -d "$vkd3d_source_x64" || ! -d "$vkd3d_source_x32" ]]; then echo "Error [Game Mode]: VKD3D Source ('$vkd3d_source_path') or subfolders (x64/x32) not found." >&2; echo "       Cannot install VKD3D. Please check HARDCODED_VKD3D_SOURCE_DIR." >&2; return 1; fi
  local target_system32="$prefix_path/drive_c/windows/system32"; local target_syswow64="$prefix_path/drive_c/windows/syswow64"
  mkdir -p "$target_system32" "$target_syswow64"; local all_copied=true; local vkd3d_dlls_to_copy=("d3d12.dll" "d3d12core.dll")
  echo "Info [Game Mode]: Copying x64 VKD3D-Proton DLLs (${vkd3d_dlls_to_copy[*]})..."; for dll in "${vkd3d_dlls_to_copy[@]}"; do if [[ -f "$vkd3d_source_x64/$dll" ]]; then cp -v "$vkd3d_source_x64/$dll" "$target_system32/" || all_copied=false; else echo "Warning [Game Mode]: VKD3D x64 DLL not found in source: $dll" >&2; fi; done
  echo "Info [Game Mode]: Copying x32 VKD3D-Proton DLLs (${vkd3d_dlls_to_copy[*]})..."; for dll in "${vkd3d_dlls_to_copy[@]}"; do if [[ -f "$vkd3d_source_x32/$dll" ]]; then cp -v "$vkd3d_source_x32/$dll" "$target_syswow64/" || all_copied=false; else echo "Warning [Game Mode]: VKD3D x32 DLL not found in source: $dll" >&2; fi; done
  if [[ "$all_copied" == "true" ]]; then echo "Info [Game Mode]: VKD3D-Proton DLLs copied successfully."; touch "$flag_file_path"; echo "Info [Game Mode]: Created flag file '$flag_file_path'."; return 0; else echo "Error [Game Mode]: Failed to copy one or more VKD3D-Proton DLLs."; return 1; fi
}

# (run_patcher function remains the same)
run_patcher() {
    echo "--- Running Patcher Mode ---"; local base_dir_resolved="$PATCHER_BASE_DIR"
    if ! command -v bbe &> /dev/null; then echo "Error [Patcher Mode]: bbe is not installed." >&2; return 1; fi
    local version_dir=$(find "$base_dir_resolved" -maxdepth 1 -type d -name "[0-9]*.[0-9]*.[0-9]*.[0-9]*" | sort -V | tail -n1)
    if [[ -z "$version_dir" ]]; then echo "Error [Patcher Mode]: No version directory found in '$base_dir_resolved'." >&2; return 1; fi
    echo "Info [Patcher Mode]: Using version directory: $version_dir"; local target_dll_path="$version_dir/$PATCHER_TARGET_DLL"
    if [[ ! -f "$target_dll_path" ]]; then echo "Error [Patcher Mode]: Target DLL not found: '$target_dll_path'" >&2; return 1; fi
    if ! grep -a -q $'\x12AllowsTransparency' "$target_dll_path"; then echo "Info [Patcher Mode]: '$PATCHER_TARGET_DLL' already patched or pattern not found."; return 0; fi
    local backup_dll_path="${target_dll_path}.bak"; echo "Info [Patcher Mode]: Backing up '$target_dll_path'..."; mv "$target_dll_path" "$backup_dll_path" || { echo "Error: Failed backup."; return 1; }
    echo "Info [Patcher Mode]: Applying patch using bbe..."; bbe -e "s/\x12AllowsTransparency/\x09IsEnabled\x1bA\x00\x03AAAAA/" "$backup_dll_path" > "$target_dll_path" || { echo "Error: bbe patch failed. Restoring."; mv "$backup_dll_path" "$target_dll_path"; return 1; }
    echo "Info [Patcher Mode]: Patch applied successfully."; return 0
}

# (run_launcher function remains the same)
run_launcher() {
    echo "--- Running Launcher Mode ---"; local prefix_resolved="$LAUNCHER_PREFIX"; local launcher_exe_resolved="$NATIVE_LAUNCHER_EXE"
    local prefix_parent_dir=$(dirname "$prefix_resolved"); if [[ ! -d "$prefix_parent_dir" ]]; then echo "Error [Launcher Mode]: Parent dir for prefix ('$prefix_parent_dir') missing." >&2; return 1; fi
    if [[ ! -f "$launcher_exe_resolved" ]]; then echo "Error [Launcher Mode]: Native launcher EXE not found: '$launcher_exe_resolved'" >&2; return 1; fi
    echo "Prefix: $prefix_resolved"; echo "Wine: $WINE_TO_USE"; echo "Launcher: $launcher_exe_resolved"; echo "(No extras)"
    export WINEPREFIX="$prefix_resolved"; unset WINEDLLOVERRIDES DXVK_HUD DXVK_ENABLE_NVAPI # Ensure clean environment
    echo "----------------------------"; echo "--- Running Command ---"; echo "Command: \"$WINE_TO_USE\" \"$launcher_exe_resolved\""; echo "----------------------------"
    "$WINE_TO_USE" "$launcher_exe_resolved"; return $?
}

# <<< Modified run_game function >>>
run_game() {
    echo "--- Running Game Mode ---"; local prefix_resolved="$GAME_PREFIX"; local launcher_exe_resolved="$JADEITE_LAUNCHER_EXE"
    local game_exe_path_resolved="$GAME_EXE_PATH_VAR"; # Use the dedicated variable name from config
    local dxvk_source_resolved="$DXVK_SOURCE_DIR"; local vkd3d_source_resolved=$(eval echo "$HARDCODED_VKD3D_SOURCE_DIR")

    local prefix_parent_dir=$(dirname "$prefix_resolved"); if [[ ! -d "$prefix_parent_dir" ]]; then echo "Error [Game Mode]: Parent dir for prefix ('$prefix_parent_dir') missing." >&2; return 1; fi
    if [[ ! -f "$launcher_exe_resolved" ]]; then echo "Error [Game Mode]: Jadeite launcher EXE not found: '$launcher_exe_resolved'" >&2; return 1; fi
    if [[ ! -f "$game_exe_path_resolved" ]]; then echo "Warning [Game Mode]: Game EXE path not found: '$game_exe_path_resolved'." >&2; fi

    # Attempt Installations
    install_dxvk_if_needed "$prefix_resolved" "$dxvk_source_resolved"
    install_vkd3d_if_needed "$prefix_resolved" "$vkd3d_source_resolved"

    # Validate optional tools
    local effective_gamemode=$USE_GAMEMODE; local effective_mangohud=$USE_MANGO_HUD
    if [[ "$effective_gamemode" == "true" ]] && ! command -v gamemoderun &> /dev/null; then echo "Warning [Game Mode]: GameMode (-g) needs 'gamemoderun'. Disabling." >&2; effective_gamemode=false; fi
    if [[ "$effective_mangohud" == "true" ]] && ! command -v mangohud &> /dev/null; then echo "Warning [Game Mode]: MangoHud (-m) needs 'mangohud'. Disabling." >&2; effective_mangohud=false; fi

    # <<< Determine DX mode suffix based on selection (using single dash) >>>
    local dx_mode_suffix=""
    if [[ "$SELECTED_DX_MODE" == "dx11" ]]; then dx_mode_suffix="-d3d11"
    elif [[ "$SELECTED_DX_MODE" == "dx12" ]]; then dx_mode_suffix="-d3d12"
    else echo "Warning [Game Mode]: Invalid SELECTED_DX_MODE '$SELECTED_DX_MODE'. Using default '$DEFAULT_DX_MODE'." >&2; [[ "$DEFAULT_DX_MODE" == "dx12" ]] && dx_mode_suffix="-d3d12" || dx_mode_suffix="-d3d11"; fi

    # <<< Construct the combined first argument string >>>
    local combined_first_arg="${game_exe_path_resolved} -- ${dx_mode_suffix}"

    echo "Prefix: $prefix_resolved"; echo "Wine: $WINE_TO_USE"; echo "Launcher: $launcher_exe_resolved"
    echo "Selected DX Mode: $SELECTED_DX_MODE (Arg Suffix: $dx_mode_suffix)"
    # Display the combined first argument and any extra args separately for clarity
    echo "Launcher Arg 1: $combined_first_arg"
    [[ ${#EXTRA_GAME_ARGS_ARRAY[@]} -gt 0 ]] && echo "Extra Launcher Args: ${EXTRA_GAME_ARGS_ARRAY[*]}"
    echo "MangoHud: $effective_mangohud"; echo "GameMode: $effective_gamemode"

    export WINEPREFIX="$prefix_resolved"

    # (DLL Override logic remains the same - correctly handles DXVK + conditional VKD3D)
    local current_overrides=""
    if [[ "$ENABLE_DXVK" == "true" ]]; then current_overrides+="d3d9,d3d10core,d3d11,dxgi=n"; echo "Info [Game Mode]: Enabling DXVK overrides ($current_overrides)."; fi
    if [[ "$SELECTED_DX_MODE" == "dx12" && "$ENABLE_VKD3D" == "true" ]]; then local vkd3d_overrides="d3d12,d3d12core=n"; echo "Info [Game Mode]: Enabling VKD3D-Proton overrides ($vkd3d_overrides) for DX12."; [[ -n "$current_overrides" ]] && current_overrides+=";"; current_overrides+="$vkd3d_overrides"; elif [[ "$SELECTED_DX_MODE" == "dx12" && "$ENABLE_VKD3D" != "true" ]]; then echo "Warning [Game Mode]: DX12 mode selected, but ENABLE_VKD3D not true." >&2; fi
    if [[ -n "$ADDITIONAL_OVERRIDES" ]]; then echo "Info [Game Mode]: Adding custom overrides ($ADDITIONAL_OVERRIDES)."; [[ -n "$current_overrides" ]] && current_overrides+=";"; current_overrides+="$ADDITIONAL_OVERRIDES"; fi
    [[ -n "$current_overrides" ]] && export WINEDLLOVERRIDES="$current_overrides" || unset WINEDLLOVERRIDES; if [[ "$ENABLE_DXVK" == "true" && -n "$DXVK_HUD_OPTIONS" ]]; then export DXVK_HUD="$DXVK_HUD_OPTIONS"; echo "Info [Game Mode]: Enabling DXVK HUD ($DXVK_HUD_OPTIONS)."; else unset DXVK_HUD; fi

    echo "----------------------------"; echo "--- Running Command ---"
    [[ -n "${WINEDLLOVERRIDES+x}" ]] && echo "Effective Env: WINEDLLOVERRIDES=$WINEDLLOVERRIDES"
    [[ -n "${DXVK_HUD+x}" ]] && echo "Effective Env: DXVK_HUD=$DXVK_HUD"

    local final_command=()
    if [[ "$effective_gamemode" == "true" ]]; then final_command+=("gamemoderun"); fi
    if [[ "$effective_mangohud" == "true" ]]; then final_command+=("mangohud"); fi
    final_command+=("$WINE_TO_USE")
    final_command+=("$launcher_exe_resolved")
    # <<< Add the combined first argument as ONE element >>>
    final_command+=("$combined_first_arg")
    # <<< Add any extra arguments AFTER the first combined one >>>
    final_command+=("${EXTRA_GAME_ARGS_ARRAY[@]}")

    printf "Command: "; printf "%q " "${final_command[@]}"; printf "\n"; echo "----------------------------"
    "${final_command[@]}"
    return $?
}


# --- Argument Parsing ---
if [[ "$1" == "patch" || "$1" == "launcher" || "$1" == "game" ]]; then SCRIPT_MODE="$1"; shift;
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then show_help; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mangohud) USE_MANGO_HUD=true; shift ;;
    -g|--gamemode) USE_GAMEMODE=true; shift ;;
    --dx11) SELECTED_DX_MODE="dx11"; shift ;;
    --dx12) SELECTED_DX_MODE="dx12"; shift ;;
    -h|--help) show_help ;;
    *) EXTRA_GAME_ARGS_ARRAY+=("$1"); shift ;;
  esac
done

# --- Determine Wine Command (Common Step) ---
if [[ -n "$WINE_CMD" ]]; then
  if [[ ! -f "$WINE_CMD" || ! -x "$WINE_CMD" ]]; then echo "Error: Configured Wine ('$WINE_CMD') not found/executable." >&2; exit 1; fi
  WINE_TO_USE="$WINE_CMD"
else
  WINE_TO_USE=$(command -v wine); if [[ -z "$WINE_TO_USE" ]]; then echo "Error: WINE_CMD empty and system 'wine' not found." >&2; exit 1; fi
fi


# --- Main Execution Logic ---
exit_status=0
case "$SCRIPT_MODE" in
    patch) run_patcher ;;
    launcher) run_launcher ;;
    game) run_game ;;
    *) echo "Error: Invalid mode '$SCRIPT_MODE'. Use 'patch', 'launcher', or 'game'." >&2; show_help; exit 1 ;;
esac
exit_status=$?

echo "----------------------------"
echo "Script finished mode '$SCRIPT_MODE' with exit status: $exit_status"
exit $exit_status