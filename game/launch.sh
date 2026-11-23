#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${PROJECT_DIR}/.godot-version"
if [[ ! -f "${VERSION_FILE}" ]]; then
	echo "[launch] Missing ${VERSION_FILE}; cannot verify the pinned Godot version." >&2
	exit 1
fi
PINNED_GODOT_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
if [[ -z "${PINNED_GODOT_VERSION}" ]]; then
	echo "[launch] ${VERSION_FILE} is empty." >&2
	exit 1
fi
PROJECT_NAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' "${PROJECT_DIR}/project.godot" | head -n 1)"
if [[ -z "${PROJECT_NAME}" ]]; then
	PROJECT_NAME="守望·永昌"
fi

if [[ -n "${WATCH_SETTINGS_PATH:-}" ]]; then
	SETTINGS_FILE="${WATCH_SETTINGS_PATH}"
else
	case "$(uname -s)" in
		Darwin)
			GODOT_USER_ROOT="${HOME}/Library/Application Support/Godot/app_userdata"
			;;
		*)
			GODOT_USER_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/app_userdata"
			;;
	esac
	SETTINGS_FILE="${GODOT_USER_ROOT}/${PROJECT_NAME}/settings.cfg"
fi

case "$(uname -s)" in
	Darwin)
		RENDERER_MIRROR="${HOME}/Library/Application Support/WatchYongchang/renderer.cfg"
		;;
	*)
		RENDERER_MIRROR="${XDG_CONFIG_HOME:-${HOME}/.config}/watch-yongchang/renderer.cfg"
		;;
esac

MODE="${WATCH_RENDERER:-auto}"
if [[ -z "${WATCH_RENDERER:-}" && -f "${RENDERER_MIRROR}" ]]; then
	CONFIG_MODE="$(sed -n 's/^renderer_mode="\(.*\)"/\1/p' "${RENDERER_MIRROR}" | tail -n 1)"
	if [[ -n "${CONFIG_MODE}" ]]; then
		MODE="${CONFIG_MODE}"
	fi
elif [[ -z "${WATCH_RENDERER:-}" && -f "${SETTINGS_FILE}" ]]; then
	CONFIG_MODE="$(sed -n 's/^renderer_mode="\(.*\)"/\1/p' "${SETTINGS_FILE}" | tail -n 1)"
	if [[ -n "${CONFIG_MODE}" ]]; then
		MODE="${CONFIG_MODE}"
	fi
fi

case "${MODE}" in
	auto|vulkan|opengl) ;;
	*) MODE="auto" ;;
esac

vulkan_supported() {
	if command -v vulkaninfo >/dev/null 2>&1; then
		local summary
		if summary="$(vulkaninfo --summary 2>/dev/null)"; then
			grep -q '^Devices:' <<<"${summary}" || return 1
			grep -q 'deviceName' <<<"${summary}" || return 1
			return 0
		fi
	fi
	for icd_dir in /usr/share/vulkan/icd.d /usr/local/share/vulkan/icd.d /etc/vulkan/icd.d; do
		if compgen -G "${icd_dir}/*.json" >/dev/null 2>&1 \
			&& compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; then
			return 0
		fi
	done
	return 1
}

TARGET="${MODE}"
if [[ "${TARGET}" == "auto" ]]; then
	if vulkan_supported; then
		TARGET="vulkan"
	else
		TARGET="opengl"
	fi
elif [[ "${TARGET}" == "vulkan" ]] && ! vulkan_supported; then
	echo "[launch] Vulkan requested but unavailable; falling back to OpenGL." >&2
	TARGET="opengl"
fi

GODOT_BIN="${GDA_GODOT:-}"
if [[ -z "${GODOT_BIN}" || ( ! -x "${GODOT_BIN}" && ! -x "$(command -v "${GODOT_BIN}" 2>/dev/null || true)" ) ]]; then
	GODOT_BIN=""
	for candidate in "${PROJECT_DIR}/Godot_v${PINNED_GODOT_VERSION}_linux.x86_64" godot4 godot; do
		if [[ -x "${candidate}" ]]; then
			GODOT_BIN="${candidate}"
			break
		fi
		if command -v "${candidate}" >/dev/null 2>&1; then
			GODOT_BIN="$(command -v "${candidate}")"
			break
		fi
	done
fi
if [[ -z "${GODOT_BIN}" ]]; then
	echo "[launch] Godot 4 was not found. Set GDA_GODOT or add godot4/godot to PATH." >&2
	exit 127
fi

ACTUAL_GODOT_VERSION="$("${GODOT_BIN}" --version 2>/dev/null | head -n 1 | tr -d '\r')"
EXPECTED_BASE="${PINNED_GODOT_VERSION%-*}"
EXPECTED_STATUS="${PINNED_GODOT_VERSION#*-}"
if [[ "${ACTUAL_GODOT_VERSION}" != "${EXPECTED_BASE}.${EXPECTED_STATUS}."* ]]; then
	echo "[launch] Godot version mismatch: expected ${PINNED_GODOT_VERSION}, got ${ACTUAL_GODOT_VERSION:-unknown}." >&2
	if [[ "${WATCH_SKIP_GODOT_VERSION_CHECK:-0}" != "1" ]]; then
		echo "[launch] Install the pinned version or set WATCH_SKIP_GODOT_VERSION=1 for local experiments." >&2
		exit 1
	fi
fi

if [[ "${TARGET}" == "vulkan" ]]; then
	METHOD="forward_plus"
	DRIVER="vulkan"
else
	METHOD="gl_compatibility"
	DRIVER="opengl3"
fi

echo "[launch] renderer=${TARGET} (mode=${MODE})" >&2
exec "${GODOT_BIN}" \
	--path "${PROJECT_DIR}" \
	--rendering-method "${METHOD}" \
	--rendering-driver "${DRIVER}" \
	"$@"
