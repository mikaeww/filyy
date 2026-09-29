"""Archives as folders: browse zip/jar and tar (gz, bz2, xz, zst) like directories and extract from them.

A path such as /home/m/pack.zip/assets/logo.png means "logo.png inside pack.zip". Everything inside an archive
is read-only. Member names are checked before anything is written, so an archive cannot place files outside the
chosen folder ("zip slip").
"""
import datetime
import os
import posixpath
import tarfile
import zipfile

ZIP = (".zip", ".jar", ".apk", ".war", ".xpi", ".mrpack")
TAR = (".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz", ".tar.zst", ".tzst")
_cache = {}


def supported(path):
    name = path.lower()
    return name.endswith(ZIP) or name.endswith(TAR)


def split(path):
    """(archive, inner) when path points into an archive file, else None."""
    parts = path.rstrip("/").split("/")
    for i in range(len(parts), 1, -1):
        head = "/".join(parts[:i])
        if supported(head) and os.path.isfile(head):
            return head, "/".join(parts[i:])
    return None


def safe(name):
    """The member's normalised relative name, or None when it would escape the target folder."""
    name = name.replace("\\", "/")
    clean = posixpath.normpath(name)
    if name.startswith("/") or clean == ".." or clean.startswith("../") or "\0" in name:
        return None
    return "" if clean == "." else clean


def members(archive):
    """{name: {dir, size, mtime}} for every member, cached until the archive changes."""
    st = os.stat(archive)
    key = (archive, st.st_mtime, st.st_size)
    if key in _cache:
        return _cache[key]
    found = {}
    if archive.lower().endswith(ZIP):
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                name = safe(info.filename)
                if name:
                    found[name] = {"dir": info.is_dir(), "size": info.file_size,
                                   "mtime": zipfile_time(info), "member": info.filename}
    else:
        with tarfile.open(archive) as t:
            for info in t:
                name = safe(info.name)
                if name and (info.isdir() or info.isfile()):
                    found[name] = {"dir": info.isdir(), "size": info.size, "mtime": info.mtime * 1000, "member": info.name}
    # Folders that only exist as prefixes of files still need to show up.
    for name in list(found):
        parent = posixpath.dirname(name)
        while parent and parent not in found:
            found[parent] = {"dir": True, "size": 0, "mtime": 0, "member": ""}
            parent = posixpath.dirname(parent)
    _cache.clear()
    _cache[key] = found
    return found


def zipfile_time(info):
    try:
        return datetime.datetime(*info.date_time).timestamp() * 1000
    except ValueError:
        return 0


def listing(archive, inner, kind_of, natural_key):
    inner = inner.strip("/")
    all_members = members(archive)
    if inner and not all_members.get(inner, {}).get("dir"):
        return {"path": f"{archive}/{inner}", "entries": [], "error": "Nicht im Archiv"}
    entries = []
    for name, info in all_members.items():
        if posixpath.dirname(name) != inner:
            continue
        base = posixpath.basename(name)
        entries.append({"name": base, "path": f"{archive}/{name}", "dir": info["dir"], "size": info["size"],
                        "mtime": info["mtime"], "kind": kind_of(base, info["dir"]), "link": False, "archived": True})
    entries.sort(key=lambda e: (not e["dir"], natural_key(e["name"])))
    return {"path": f"{archive}/{inner}".rstrip("/"), "entries": entries, "error": ""}


def plan(paths):
    """(archive, [(member name, relative target, size)]) for virtual paths, folders expanded to their files."""
    archive = None
    picked = []
    for path in paths:
        where = split(path)
        if not where:
            raise ValueError(f"{os.path.basename(path)} liegt in keinem Archiv")
        if archive and where[0] != archive:
            raise ValueError("Nur aus einem Archiv auf einmal")
        archive = where[0]
        picked.append(where[1].strip("/"))
    all_members = members(archive)
    out = []
    for chosen in picked:
        base = posixpath.dirname(chosen)
        for name, info in all_members.items():
            if name == chosen or name.startswith(chosen + "/") or chosen == "":
                relative = posixpath.relpath(name, base) if base else name
                out.append((name, relative, info))
    return archive, out


def each_member(archive, names):
    """Yields (name, readable file) for the wanted file members; a tar is read in one pass, not once per file."""
    wanted = set(names)
    all_members = members(archive)
    if archive.lower().endswith(ZIP):
        with zipfile.ZipFile(archive) as z:
            for name in names:
                with z.open(all_members[name]["member"]) as handle:
                    yield name, handle
        return
    by_member = {all_members[n]["member"]: n for n in wanted}
    with tarfile.open(archive) as t:
        for member in t:
            name = by_member.get(member.name)
            if name is None or not member.isfile():
                continue
            # Python's own guard against links, devices and escaping paths, on top of safe().
            tarfile.data_filter(member, "/")
            with t.extractfile(member) as handle:
                yield name, handle
