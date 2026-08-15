"""Blind Mice Gaming updater — high-contrast Windows app for WoW addons."""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
import tempfile
import threading
import webbrowser
from datetime import datetime
from email.utils import parsedate_to_datetime
from pathlib import Path
from tkinter import filedialog, messagebox
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import zipfile

import tkinter as tk
from PIL import Image, ImageTk

APP_NAME = "Blind Mice Gaming Updater"
APP_VERSION = "1.1.0"
BG = "#000000"
FG = "#FFFFFF"
YELLOW = "#FFE600"
GREEN = "#00FF66"
RED = "#FF4D4D"
PANEL = "#111111"
BTN = "#1A1A1A"
MUTED = "#CCCCCC"
ROYAL = "#0B1F5C"

IS_FROZEN = getattr(sys, "frozen", False)
HERE = Path(sys._MEIPASS) if IS_FROZEN else Path(__file__).resolve().parent
LOGO_PATH = HERE / "assets" / "logo.png"
CATALOG_PATH = HERE / "catalog.json"
CONFIG_DIR = Path(os.environ.get("APPDATA", str(Path.home()))) / "BlindMiceUpdater"
CONFIG_PATH = CONFIG_DIR / "config.json"
LOCAL_SOURCE = Path(__file__).resolve().parent.parent if not IS_FROZEN else None

DEFAULT_WOW_ROOT = Path(r"C:\Program Files (x86)\World of Warcraft")
VERSION_RE = re.compile(r"^##\s*Version:\s*(.+)$", re.MULTILINE | re.IGNORECASE)
INTERFACE_RE = re.compile(r"^##\s*Interface:\s*(.+)$", re.MULTILINE | re.IGNORECASE)
SAVED_RE = re.compile(r"^##\s*SavedVariables:\s*(.+)$", re.MULTILINE | re.IGNORECASE)
SAVED_CHAR_RE = re.compile(r"^##\s*SavedVariablesPerCharacter:\s*(.+)$", re.MULTILINE | re.IGNORECASE)

COPY_IGNORE = shutil.ignore_patterns(
    "__pycache__",
    ".git",
    ".cursor",
    ".github",
    "*.pyc",
    "*.pyo",
    "Thumbs.db",
    ".DS_Store",
)

# Detected from ## Interface in each addon TOC, then matched to an installed client folder.
FLAVOR_DEFS = [
    {
        "id": "retail",
        "name": "Retail (Midnight)",
        "folders": ("_retail_",),
        "match": lambda n: n >= 100000,
    },
    {
        "id": "classic",
        "name": "Classic (Mists of Pandaria)",
        "folders": ("_classic_",),
        "match": lambda n: 50000 <= n < 60000,
    },
    {
        "id": "cata",
        "name": "Cataclysm Classic",
        "folders": ("_classic_cata_", "_cata_"),
        "match": lambda n: 40000 <= n < 50000,
    },
    {
        "id": "titan",
        "name": "Titan Reforged",
        "folders": ("_titan_", "_classic_titan_"),
        "match": lambda n: 38000 <= n < 39000,
    },
    {
        "id": "wrath",
        "name": "Wrath Classic",
        "folders": ("_wrath_", "_classic_wrath_"),
        "match": lambda n: 30000 <= n < 38000,
    },
    {
        "id": "anniversary",
        "name": "Classic (Anniversary)",
        "folders": ("_anniversary_",),
        "match": lambda n: 20000 <= n < 30000,
    },
    {
        "id": "tbc",
        "name": "Burning Crusade Classic",
        "folders": ("_classic_tbc_", "_burning_crusade_"),
        "match": lambda n: 20000 <= n < 30000,
    },
    {
        "id": "era",
        "name": "Classic (Vanilla)",
        "folders": ("_classic_era_",),
        "match": lambda n: 10000 <= n < 20000,
    },
]


def load_json(path: Path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def parse_toc_text(text: str) -> dict:
    interfaces: list[int] = []
    match = INTERFACE_RE.search(text)
    if match:
        for part in match.group(1).split(","):
            digits = re.sub(r"\D", "", part)
            if digits:
                interfaces.append(int(digits))
    version_match = VERSION_RE.search(text)
    saved: list[str] = []
    for pattern in (SAVED_RE, SAVED_CHAR_RE):
        found = pattern.search(text)
        if found:
            saved.extend(name.strip() for name in found.group(1).split(",") if name.strip())
    return {
        "version": version_match.group(1).strip() if version_match else None,
        "interfaces": interfaces,
        "saved": saved,
    }


def find_toc(folder: Path) -> Path | None:
    if not folder.is_dir():
        return None
    preferred = folder / f"{folder.name}.toc"
    if preferred.is_file():
        return preferred
    matches = list(folder.glob("*.toc"))
    return matches[0] if matches else None


def read_toc(folder: Path) -> dict:
    toc = find_toc(folder)
    if not toc:
        return {"version": None, "interfaces": [], "saved": []}
    text = toc.read_text(encoding="utf-8", errors="replace")
    return parse_toc_text(text)


def folder_modified(folder: Path) -> datetime | None:
    toc = find_toc(folder)
    if toc and toc.is_file():
        return datetime.fromtimestamp(toc.stat().st_mtime)
    if folder.is_dir():
        return datetime.fromtimestamp(folder.stat().st_mtime)
    return None


def format_date(value: datetime | None) -> str:
    if not value:
        return "unknown date"
    if value.tzinfo:
        value = value.astimezone().replace(tzinfo=None)
    return value.strftime("%d %b %Y").lstrip("0")


def version_tuple(version: str | None) -> tuple[int, ...]:
    parts = [int(part) for part in re.findall(r"\d+", version or "")]
    return tuple(parts) if parts else (0,)


def is_newer(latest: str | None, installed: str | None) -> bool:
    if not latest or not installed:
        return False
    return version_tuple(latest) > version_tuple(installed)


def wow_root_from_legacy(path: Path) -> Path:
    parts = list(path.parts)
    for i, part in enumerate(parts):
        if part.startswith("_") and part.endswith("_"):
            return Path(*parts[:i]) if i else path
    if path.name.lower() == "addons":
        return path.parent.parent.parent
    return path


def http_get(url: str, token: str = "") -> tuple[bytes, datetime | None]:
    headers = {"User-Agent": "BMG-Updater/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
        headers["Accept"] = "application/vnd.github+json"
    with urlopen(Request(url, headers=headers), timeout=60) as resp:
        modified = None
        raw = resp.headers.get("Last-Modified")
        if raw:
            try:
                modified = parsedate_to_datetime(raw)
            except (TypeError, ValueError):
                modified = None
        return resp.read(), modified


class UpdaterApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.catalog = load_json(CATALOG_PATH, {"repo": "", "branch": "main", "addons": []})
        self.config = load_json(CONFIG_PATH, {})
        self.busy = False
        self.rows: dict[str, dict] = {}
        self.remote: dict[str, dict] = {}
        self.toc_cache: dict[str, dict] = {}
        self.flavor_clients: list[dict] = []
        self.notify_names: list[str] = []
        self.updater_update = False
        self.updater_latest = APP_VERSION

        root.title(f"{APP_NAME} {APP_VERSION}")
        root.configure(bg=BG)
        root.minsize(1040, 760)
        root.geometry("1180x880")

        self._build()
        self.refresh_local()
        self.root.after(400, self.check_updates_silent)

    def _font(self, size: int, bold: bool = True):
        return ("Segoe UI", size, "bold" if bold else "normal")

    def source_dir(self) -> Path | None:
        if LOCAL_SOURCE and LOCAL_SOURCE.exists():
            return LOCAL_SOURCE
        return None

    def catalog_toc(self, addon: dict) -> dict:
        interfaces = []
        for number in addon.get("interfaces") or []:
            try:
                interfaces.append(int(number))
            except (TypeError, ValueError):
                continue
        return {
            "version": addon.get("version"),
            "interfaces": interfaces,
            "saved": list(addon.get("saved") or []),
        }

    def addon_toc(self, addon: dict) -> dict:
        addon_id = addon["id"]
        if addon_id in self.toc_cache:
            return self.toc_cache[addon_id]
        info = self.catalog_toc(addon)
        source = self.source_dir()
        if source:
            parsed = read_toc(source / addon["folders"][0])
            if parsed.get("interfaces"):
                info = parsed
        self.toc_cache[addon_id] = info
        return info

    def addon_supports(self, addon: dict, flavor: dict) -> bool:
        interfaces = self.addon_toc(addon).get("interfaces") or []
        if not interfaces:
            return False
        return any(flavor["match"](number) for number in interfaces)

    def detect_wow_root(self) -> Path:
        stored = self.config.get("wow_root") or self.config.get("addons_path")
        if stored:
            path = Path(stored)
            if self.config.get("addons_path") and not self.config.get("wow_root"):
                path = wow_root_from_legacy(path)
            if path.exists():
                return path
        if DEFAULT_WOW_ROOT.exists():
            return DEFAULT_WOW_ROOT
        return DEFAULT_WOW_ROOT

    def detect_clients(self) -> list[dict]:
        root = Path(self.path_var.get().strip() or self.detect_wow_root())
        found = []
        for flavor in FLAVOR_DEFS:
            for folder in flavor["folders"]:
                client = root / folder
                addons = client / "Interface" / "AddOns"
                if client.is_dir():
                    found.append(
                        {
                            **flavor,
                            "client_folder": folder,
                            "client_root": client,
                            "addons_dir": addons,
                            "wtf_dir": client / "WTF",
                        }
                    )
                    break
        return found

    def _build(self) -> None:
        header = tk.Frame(self.root, bg=BG, padx=20, pady=8)
        header.pack(fill="x")

        if LOGO_PATH.is_file():
            image = Image.open(LOGO_PATH).convert("RGBA")
            image.thumbnail((520, 96), Image.Resampling.LANCZOS)
            self.logo_photo = ImageTk.PhotoImage(image)
            tk.Label(header, image=self.logo_photo, bg=BG).pack(anchor="w")
        else:
            tk.Label(header, text="BLIND MICE GAMING", bg=BG, fg=YELLOW, font=self._font(22)).pack(anchor="w")

        tk.Label(header, text="ADDON UPDATER", bg=BG, fg=FG, font=self._font(15)).pack(anchor="w", pady=(4, 0))

        path_row = tk.Frame(self.root, bg=BG, padx=20)
        path_row.pack(fill="x", pady=4)
        tk.Label(path_row, text="World of Warcraft folder", bg=BG, fg=YELLOW, font=self._font(13)).pack(anchor="w")

        entry_row = tk.Frame(path_row, bg=BG)
        entry_row.pack(fill="x", pady=6)
        self.path_var = tk.StringVar(value=str(self.detect_wow_root()))
        self.path_entry = tk.Entry(
            entry_row,
            textvariable=self.path_var,
            bg=PANEL,
            fg=FG,
            insertbackground=FG,
            font=self._font(12, bold=False),
            relief="flat",
        )
        self.path_entry.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 8))
        self._button(entry_row, "Browse", self.browse_folder).pack(side="left")

        actions = tk.Frame(self.root, bg=BG, padx=20, pady=6)
        actions.pack(fill="x")
        self._button(actions, "Check for updates", self.check_updates).pack(side="left", padx=(0, 8))
        self._button(actions, "Update all", self.update_all).pack(side="left", padx=(0, 8))
        self.get_updater_btn = self._button(actions, "Get updater update", self.download_updater)
        if not IS_FROZEN:
            self._button(actions, "Install from this PC", self.install_all_local).pack(side="left")

        self.banner = tk.Label(
            self.root,
            text="",
            bg=ROYAL,
            fg=YELLOW,
            font=self._font(12),
            anchor="w",
            padx=20,
            pady=8,
        )

        list_wrap = tk.Frame(self.root, bg=BG, padx=20)
        list_wrap.pack(fill="both", expand=True)
        self.canvas = tk.Canvas(list_wrap, bg=BG, highlightthickness=0)
        scroll = tk.Scrollbar(list_wrap, command=self.canvas.yview)
        self.list_frame = tk.Frame(self.canvas, bg=BG)
        self.list_window = self.canvas.create_window((0, 0), window=self.list_frame, anchor="nw")
        self.list_frame.bind("<Configure>", lambda _e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", lambda e: self.canvas.itemconfigure(self.list_window, width=e.width))
        self.canvas.configure(yscrollcommand=scroll.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        def on_mousewheel(event):
            self.canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

        self.canvas.bind("<Enter>", lambda _e: self.canvas.bind_all("<MouseWheel>", on_mousewheel))
        self.canvas.bind("<Leave>", lambda _e: self.canvas.unbind_all("<MouseWheel>"))

        self.status = tk.Label(
            self.root,
            text="Ready. Addons are grouped by the WoW versions installed on this PC.",
            bg=ROYAL,
            fg=YELLOW,
            font=self._font(12),
            anchor="w",
            padx=20,
            pady=8,
        )
        self.status.pack(fill="x", side="bottom")

        self.rebuild_list()

    def _button(self, parent, text, command, width: int | None = None) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=BTN,
            fg=YELLOW,
            activebackground=YELLOW,
            activeforeground=BG,
            font=self._font(11),
            relief="flat",
            padx=10,
            pady=5,
            cursor="hand2",
            highlightthickness=2,
            highlightbackground=YELLOW,
            width=width or 0,
        )

    def rebuild_list(self) -> None:
        for child in self.list_frame.winfo_children():
            child.destroy()
        self.rows.clear()
        self.flavor_clients = self.detect_clients()

        if not self.flavor_clients:
            tk.Label(
                self.list_frame,
                text="No WoW game versions were found in that folder. Browse to the World of Warcraft directory that contains _retail_ or _classic_.",
                bg=BG,
                fg=YELLOW,
                font=self._font(13),
                wraplength=960,
                justify="left",
            ).pack(anchor="w", pady=10)
            return

        for flavor in self.flavor_clients:
            addons = [addon for addon in self.catalog.get("addons", []) if self.addon_supports(addon, flavor)]
            header = tk.Frame(self.list_frame, bg=BG, pady=6)
            header.pack(fill="x")
            tk.Label(header, text=flavor["name"].upper(), bg=BG, fg=YELLOW, font=self._font(15)).pack(anchor="w")
            tk.Label(
                header,
                text=str(flavor["addons_dir"]),
                bg=BG,
                fg=MUTED,
                font=self._font(10, bold=False),
            ).pack(anchor="w", pady=(1, 4))
            if not addons:
                tk.Label(
                    header,
                    text="No Blind Mice Gaming addons target this game version.",
                    bg=BG,
                    fg=MUTED,
                    font=self._font(11, bold=False),
                ).pack(anchor="w")
                continue
            flavor_actions = tk.Frame(header, bg=BG)
            flavor_actions.pack(anchor="w", pady=(4, 2))
            self._button(
                flavor_actions,
                f"Install all for {flavor['name']}",
                lambda f=flavor, items=addons: self.install_many(items, f),
            ).pack(side="left", padx=(0, 8))
            self._button(
                flavor_actions,
                f"Update all for {flavor['name']}",
                lambda f=flavor, items=addons: self.update_many(items, f),
            ).pack(side="left")

            for addon in addons:
                self._addon_row(addon, flavor)

    def _addon_row(self, addon: dict, flavor: dict) -> None:
        key = f"{flavor['id']}:{addon['id']}"
        frame = tk.Frame(self.list_frame, bg=PANEL, padx=12, pady=8)
        frame.pack(fill="x", pady=4)

        left = tk.Frame(frame, bg=PANEL)
        left.pack(side="left", fill="x", expand=True)
        tk.Label(left, text=addon["name"], bg=PANEL, fg=FG, font=self._font(14)).pack(anchor="w")
        meta = tk.Label(left, text="Checking local files…", bg=PANEL, fg=MUTED, font=self._font(11, bold=False), justify="left")
        meta.pack(anchor="w", pady=2)

        buttons = tk.Frame(frame, bg=PANEL)
        buttons.pack(side="right", padx=(12, 0))
        install_btn = self._button(buttons, "Install", lambda a=addon, f=flavor: self.install_one(a, f), width=18)
        install_btn.pack(pady=2, fill="x")
        uninstall_btn = self._button(buttons, "Uninstall", lambda a=addon, f=flavor: self.uninstall_one(a, f), width=18)
        uninstall_btn.pack(pady=2, fill="x")
        sv_btn = self._button(buttons, "Delete Saved Variables", lambda a=addon, f=flavor: self.delete_saved_variables(a, f), width=18)
        sv_btn.pack(pady=2, fill="x")

        self.rows[key] = {
            "meta": meta,
            "install": install_btn,
            "uninstall": uninstall_btn,
            "sv": sv_btn,
            "addon": addon,
            "flavor": flavor,
        }

    def set_status(self, text: str, color: str = YELLOW) -> None:
        self.status.configure(text=text, bg=ROYAL, fg=YELLOW)

    def set_banner(self, names: list[str]) -> None:
        self.notify_names = names
        parts = []
        if self.updater_update:
            parts.append(
                f"BMG Updater {self.updater_latest} is available. You have {APP_VERSION}. Use Get updater update."
            )
            self.get_updater_btn.pack(side="left", padx=(0, 8))
        else:
            self.get_updater_btn.pack_forget()
        unique = []
        for name in names:
            if name not in unique:
                unique.append(name)
        if unique:
            parts.append(f"Addon updates available: {', '.join(unique)}. Use Update on those rows, or Update all.")
        if not parts:
            self.banner.pack_forget()
            return
        self.banner.configure(text=" ".join(parts))
        if not self.banner.winfo_ismapped():
            self.banner.pack(fill="x", side="bottom", before=self.status)

    def save_settings(self) -> None:
        self.config["wow_root"] = self.path_var.get().strip()
        save_json(CONFIG_PATH, self.config)

    def browse_folder(self) -> None:
        chosen = filedialog.askdirectory(title="Select the World of Warcraft folder")
        if not chosen:
            return
        root = wow_root_from_legacy(Path(chosen))
        self.path_var.set(str(root))
        self.save_settings()
        self.toc_cache.clear()
        self.rebuild_list()
        self.refresh_local()

    def browse_ok(self) -> bool:
        root = Path(self.path_var.get().strip())
        if not root.exists():
            messagebox.showerror(APP_NAME, f"World of Warcraft folder not found:\n{root}")
            return False
        self.save_settings()
        if not self.detect_clients():
            messagebox.showerror(
                APP_NAME,
                "No game versions were found. Choose the folder that contains _retail_, _classic_, or _classic_era_.",
            )
            return False
        return True

    def installed_info(self, addon: dict, flavor: dict) -> dict:
        folder = flavor["addons_dir"] / addon["folders"][0]
        toc = read_toc(folder)
        return {
            "version": toc.get("version"),
            "date": folder_modified(folder),
            "saved": toc.get("saved") or self.addon_toc(addon).get("saved") or [],
            "folder": folder,
        }

    def catalog_info(self, addon: dict) -> dict:
        remote = self.remote.get(addon["id"])
        if remote:
            return remote
        source = self.source_dir()
        if source:
            folder = source / addon["folders"][0]
            toc = read_toc(folder)
            return {"version": toc.get("version"), "date": folder_modified(folder)}
        toc = self.addon_toc(addon)
        return {"version": toc.get("version"), "date": None}

    def refresh_local(self) -> None:
        updates = []
        for key, row in self.rows.items():
            addon = row["addon"]
            flavor = row["flavor"]
            local = self.installed_info(addon, flavor)
            latest = self.catalog_info(addon)
            latest_version = latest.get("version")
            latest_date = format_date(latest.get("date"))
            if local["version"]:
                installed_date = format_date(local["date"])
                if is_newer(latest_version, local["version"]):
                    text = (
                        f"Version {local['version']} · {installed_date}\n"
                        f"Update {latest_version} released {latest_date}"
                    )
                    color = YELLOW
                    row["install"].configure(text="Update")
                    updates.append(f"{addon['name']} ({flavor['name']})")
                elif latest_version and local["version"] == latest_version:
                    text = f"Version {local['version']} · {installed_date}\nUp to date"
                    color = GREEN
                    row["install"].configure(text="Reinstall")
                else:
                    text = f"Version {local['version']} · {installed_date}"
                    color = GREEN
                    row["install"].configure(text="Reinstall")
                row["uninstall"].configure(state="normal")
                row["sv"].configure(state="normal")
            else:
                text = f"Not installed\nLatest {latest_version or 'unknown'} · {latest_date}"
                color = RED
                row["install"].configure(text="Install")
                row["uninstall"].configure(state="disabled")
                row["sv"].configure(state="normal")
            row["meta"].configure(text=text, fg=color)
        self.set_banner(updates)

    def run_bg(self, work, done_message: str) -> None:
        if self.busy:
            return
        self.busy = True

        def runner():
            try:
                work()
                self.root.after(0, lambda: self.finish(done_message, GREEN))
            except Exception as exc:
                self.root.after(0, lambda: self.finish(str(exc), RED))

        threading.Thread(target=runner, daemon=True).start()

    def finish(self, message: str, color: str) -> None:
        self.busy = False
        self.refresh_local()
        self.set_status(message, color)

    def check_updates_silent(self) -> None:
        if not Path(self.path_var.get().strip()).exists():
            return
        self.set_status("Checking GitHub for addon versions…")
        self._check_updates(show_errors=False)

    def check_updates(self) -> None:
        if not self.browse_ok():
            return
        self.set_status("Checking GitHub for addon versions…")
        self._check_updates(show_errors=True)

    def download_updater(self) -> None:
        repo = self.catalog.get("repo") or "charswebdev/Blind-Mice-Gaming"
        url = self.catalog.get("setupUrl") or f"https://github.com/{repo}/releases/latest"
        webbrowser.open(url)

    def apply_remote_catalog(self, remote: dict) -> None:
        if remote.get("addons"):
            self.catalog["addons"] = remote["addons"]
            self.toc_cache.clear()
        if remote.get("setupUrl"):
            self.catalog["setupUrl"] = remote["setupUrl"]
        latest = remote.get("updaterVersion")
        self.updater_latest = latest or APP_VERSION
        self.updater_update = is_newer(latest, APP_VERSION)

    def _check_updates(self, show_errors: bool) -> None:
        def work():
            token = ""
            repo = self.catalog.get("repo") or ""
            branch = self.catalog.get("branch", "main")
            if not repo:
                raise RuntimeError("catalog.json is missing the GitHub repo.")
            catalog_url = f"https://raw.githubusercontent.com/{repo}/{branch}/updater/catalog.json"
            try:
                raw, _modified = http_get(catalog_url, token)
                remote_catalog = json.loads(raw.decode("utf-8"))
                self.apply_remote_catalog(remote_catalog)
            except (HTTPError, URLError, json.JSONDecodeError):
                if show_errors:
                    raise
            for addon in self.catalog.get("addons", []):
                folder = addon["folders"][0]
                url = f"https://raw.githubusercontent.com/{repo}/{branch}/{folder}/{folder}.toc"
                try:
                    text, modified = http_get(url, token)
                    parsed = parse_toc_text(text.decode("utf-8", errors="replace"))
                    self.remote[addon["id"]] = {
                        "version": parsed.get("version") or "unknown",
                        "date": modified,
                    }
                except HTTPError as exc:
                    if exc.code in (401, 403, 404) and not show_errors:
                        continue
                    if exc.code in (401, 403, 404):
                        self.remote[addon["id"]] = {
                            "version": self.addon_toc(addon).get("version"),
                            "date": folder_modified((self.source_dir() or Path()) / folder) if self.source_dir() else None,
                        }
                        continue
                    raise
                except URLError:
                    if show_errors:
                        raise
                    continue

        def after():
            self.busy = False
            self.rebuild_list()
            self.refresh_local()
            if self.updater_update:
                self.set_status(
                    f"BMG Updater {self.updater_latest} is available. You have {APP_VERSION}.",
                    YELLOW,
                )
            elif self.notify_names:
                self.set_status(f"Updates available for {len(self.notify_names)} install(s).", YELLOW)
            else:
                self.set_status("Version check finished. No updates found.", GREEN)

        if self.busy:
            return
        self.busy = True

        def runner():
            try:
                work()
                self.root.after(0, after)
            except Exception as exc:
                self.root.after(0, lambda: self.finish(str(exc), RED))

        threading.Thread(target=runner, daemon=True).start()

    def update_all(self) -> None:
        jobs = []
        for row in self.rows.values():
            local = self.installed_info(row["addon"], row["flavor"])
            latest = self.catalog_info(row["addon"])
            if local["version"] and is_newer(latest.get("version"), local["version"]):
                jobs.append((row["addon"], row["flavor"]))
        if not jobs:
            if not self.browse_ok():
                return
            messagebox.showinfo(APP_NAME, "No installed addons have a newer version available.")
            return
        self.install_jobs(jobs, f"{len(jobs)} update(s)")

    def update_many(self, addons: list[dict], flavor: dict) -> None:
        jobs = []
        for addon in addons:
            local = self.installed_info(addon, flavor)
            latest = self.catalog_info(addon)
            if local["version"] and is_newer(latest.get("version"), local["version"]):
                jobs.append((addon, flavor))
        if not jobs:
            messagebox.showinfo(APP_NAME, f"No updates are waiting for {flavor['name']}.")
            return
        self.install_jobs(jobs, f"{len(jobs)} update(s) for {flavor['name']}")

    def install_one(self, addon: dict, flavor: dict) -> None:
        self.install_jobs([(addon, flavor)], f"{addon['name']} for {flavor['name']}")

    def install_many(self, addons: list[dict], flavor: dict) -> None:
        self.install_jobs([(addon, flavor) for addon in addons], f"all addons for {flavor['name']}")

    def install_all_local(self) -> None:
        if not self.browse_ok():
            return
        if not self.source_dir():
            messagebox.showerror(APP_NAME, "Local source folder is only available on the developer PC.")
            return
        jobs = [(row["addon"], row["flavor"]) for row in self.rows.values()]
        self.install_jobs(jobs, "all Blind Mice Gaming addons from this PC", local_only=True)

    def install_jobs(self, jobs: list[tuple[dict, dict]], label: str, local_only: bool = False) -> None:
        if not jobs:
            return
        if not self.browse_ok():
            return
        self.set_status(f"Installing {label}…")

        def work():
            source = self.source_dir() if local_only else None
            extracted = None
            tmp_dir = None
            if source is None:
                repo = self.catalog.get("repo") or ""
                branch = self.catalog.get("branch", "main")
                url = f"https://api.github.com/repos/{repo}/zipball/{branch}"
                data, _modified = http_get(url)
                tmp_dir = tempfile.TemporaryDirectory()
                zip_path = Path(tmp_dir.name) / "addons.zip"
                zip_path.write_bytes(data)
                with zipfile.ZipFile(zip_path) as zf:
                    root_name = zf.namelist()[0].split("/")[0]
                    zf.extractall(tmp_dir.name)
                extracted = Path(tmp_dir.name) / root_name
                source = extracted
            try:
                for addon, flavor in jobs:
                    self._copy_folders(source, addon["folders"], flavor["addons_dir"])
            finally:
                if tmp_dir is not None:
                    tmp_dir.cleanup()

        self.run_bg(work, f"Installed {label}.")

    def _copy_folders(self, source: Path, folders, dest: Path) -> None:
        dest.mkdir(parents=True, exist_ok=True)
        missing = []
        for folder in folders:
            src = source / folder
            if not src.is_dir():
                missing.append(folder)
                continue
            target = dest / folder
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(src, target, ignore=COPY_IGNORE)
        if missing and len(missing) == len(list(folders)):
            raise FileNotFoundError("Addon folders were not in the download: " + ", ".join(missing))

    def uninstall_one(self, addon: dict, flavor: dict) -> None:
        local = self.installed_info(addon, flavor)
        if not local["version"]:
            messagebox.showinfo(APP_NAME, f"{addon['name']} is not installed in {flavor['name']}.")
            return
        if not messagebox.askyesno(
            APP_NAME,
            f"Uninstall {addon['name']} from {flavor['name']}?\n\n"
            "This removes the addon folder. Saved variables are kept unless you delete them separately.",
        ):
            return
        dest = flavor["addons_dir"]
        removed = 0
        for folder in addon["folders"]:
            target = dest / folder
            if target.exists():
                shutil.rmtree(target)
                removed += 1
        self.refresh_local()
        self.set_status(f"Uninstalled {addon['name']} from {flavor['name']} ({removed} folder(s)).", GREEN)

    def delete_saved_variables(self, addon: dict, flavor: dict) -> None:
        names = self.installed_info(addon, flavor)["saved"] or self.addon_toc(addon).get("saved") or []
        if not names:
            messagebox.showinfo(APP_NAME, f"No saved variable names were found for {addon['name']}.")
            return
        wtf = flavor["wtf_dir"]
        if not wtf.is_dir():
            messagebox.showinfo(APP_NAME, f"No WTF folder exists for {flavor['name']}.")
            return
        files = find_saved_variable_files(wtf, names)
        if not files:
            messagebox.showinfo(APP_NAME, f"No saved variable files were found for {addon['name']} in {flavor['name']}.")
            return
        preview = "\n".join(str(path) for path in files[:8])
        extra = "" if len(files) <= 8 else f"\n… and {len(files) - 8} more"
        if not messagebox.askyesno(
            APP_NAME,
            f"Delete saved variables for {addon['name']} on {flavor['name']}?\n\n"
            f"{preview}{extra}\n\nThis cannot be undone. The addon itself stays installed.",
        ):
            return
        for path in files:
            try:
                path.unlink()
            except OSError:
                pass
        self.set_status(f"Deleted {len(files)} saved variable file(s) for {addon['name']} on {flavor['name']}.", GREEN)


def find_saved_variable_files(wtf_dir: Path, names: list[str]) -> list[Path]:
    found: list[Path] = []
    account_root = wtf_dir / "Account"
    if not account_root.is_dir():
        return found
    wanted = set(names)

    def collect(folder: Path) -> None:
        if not folder.is_dir():
            return
        for name in wanted:
            for suffix in (".lua", ".lua.bak"):
                path = folder / f"{name}{suffix}"
                if path.is_file():
                    found.append(path)

    for account in account_root.iterdir():
        if not account.is_dir():
            continue
        collect(account / "SavedVariables")
        for realm in account.iterdir():
            if not realm.is_dir() or realm.name == "SavedVariables":
                continue
            for character in realm.iterdir():
                if character.is_dir():
                    collect(character / "SavedVariables")
    return found


def main() -> None:
    root = tk.Tk()
    UpdaterApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
