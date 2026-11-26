"""Build the public, engine-only Android APK from this checkout (run by CI).

The APK is built from the Android source snapshot that the Windows launcher embeds, so
both always come from the same commit. With --keystore the APK is signed with the
published certificate (--release in build_apk.py); without it a throwaway key is used
and the result is only a build check, never a release.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from build_windows import GODOT_VERSION, install_engine
from prepare_android_public import prepare_android
from prepare_public import ROOT


def java_home() -> Path:
    for name in ("JAVA_HOME_21_X64", "JAVA_HOME_17_X64", "JAVA_HOME"):
        if os.environ.get(name) and (Path(os.environ[name]) / "bin/keytool.exe").is_file():
            return Path(os.environ[name])
    raise ValueError("Se requiere un JDK 17 o 21 (JAVA_HOME)")


def android_sdk() -> Path:
    for name in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(name) and (Path(os.environ[name]) / "build-tools").is_dir():
            return Path(os.environ[name])
    raise ValueError("Se requiere el SDK Android (ANDROID_HOME)")


def portable_editor(engine: Path, cache: Path, work: Path, java: Path, sdk: Path, keystore: Path) -> Path:
    """Self-contained Godot copy: its settings and templates never touch the user profile."""
    editor = work / "godot"
    editor.mkdir()
    for name in (engine.name, engine.name.replace("_console", "")):
        shutil.copyfile(engine.parent / name, editor / name)
    (editor / "_sc_").touch()
    templates = editor / f"editor_data/export_templates/{GODOT_VERSION}.stable"
    templates.mkdir(parents=True)
    for name in ("android_debug.apk", "android_release.apk"):
        shutil.copyfile(cache / name, templates / name)
    def gd(path: Path) -> str:
        return json.dumps(path.resolve().as_posix())
    (editor / "editor_data/editor_settings-4.7.tres").write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        f'export/android/java_sdk_path = {gd(java)}\n'
        f'export/android/android_sdk_path = {gd(sdk)}\n'
        f'export/android/debug_keystore = {gd(keystore)}\n'
        'export/android/debug_keystore_user = "androiddebugkey"\n'
        'export/android/debug_keystore_pass = "android"\n', encoding="utf-8")
    return editor / engine.name


def build(cache: Path, out: Path, keystore: Path | None, custom_key: bool = False) -> dict:
    out = out.resolve()
    if out.exists():
        raise ValueError("El destino debe ser nuevo")
    if keystore is None or not keystore.is_file():
        raise RuntimeError("Missing fixed Android signing keystore (--keystore); refusing to generate a throwaway key.")
    out.mkdir(parents=True)
    work = out / "work"
    work.mkdir()
    java, sdk = java_home(), android_sdk()
    env = dict(os.environ, JAVA_HOME=str(java), PATH=str(java / "bin") + os.pathsep + os.environ["PATH"])
    enforce_upstream_cert = not custom_key
    resolved_keystore = keystore.resolve()
    engine = install_engine(cache, android=True)
    godot = portable_editor(engine, cache, work, java, sdk, resolved_keystore)
    source = out / "source"
    prepare_android(ROOT, source)
    apk = out / "PowerOfChaos-Android.apk"
    subprocess.run([sys.executable, str(source / "tools/android/build_apk.py"), "--engine-only",
                    "--release" if enforce_upstream_cert else "--first-build", "--godot", str(godot), "--sdk", str(sdk),
                    "--debug-keystore", str(resolved_keystore), "--work", str(work / "build"),
                    "--output", str(apk)], check=True, env=env)
    shutil.copyfile(work / "build/ANDROID_RELEASE.json", out / "ANDROID_RELEASE.json")
    info = json.loads((out / "ANDROID_RELEASE.json").read_text(encoding="utf-8"))
    info["release_signed"] = True
    print(json.dumps(info, indent=2), flush=True)
    return info


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine-cache", type=Path, required=True)
    parser.add_argument("--keystore", type=Path, required=True, help="clave de firma permanente (obligatoria)")
    parser.add_argument("--custom-key", action="store_true", help="permite firmar con la clave propia del fork en lugar del certificado oficial")
    parser.add_argument("--out", type=Path, required=True, help="directorio nuevo fuera del repositorio")
    args = parser.parse_args()
    build(args.engine_cache, args.out, args.keystore, custom_key=args.custom_key)
