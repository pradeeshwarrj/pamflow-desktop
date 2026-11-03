"""
Download BirdNET's own (global) model for pamflow Desktop.

    python download_model.py --dest <folder>

Fetches the BirdNET v2.4 TFLite model published on Zenodo (the same file the
`birdnet` Python package downloads), checks it, and unpacks it into <folder>:

    <folder>/audio-model.tflite     the model (FP32)
    <folder>/labels/<lang>.txt      species lists, one file per language
    <folder>/model.json             what this is and where it came from

pamflow loads this file exactly like a custom classifier (it has the same
layout as a classifier trained with BirdNET-Analyzer), so the project's
settings simply point `model_dir` / `classifier_name` / `labels_file` at it.

Progress goes to stdout as "@@PAM {json}" lines (the app's protocol):
    {"type":"download","phase":"download","done":bytes,"total":bytes}
    {"type":"download","phase":"extract"}
    {"type":"download","phase":"done"}
    {"type":"download_failed","message":"..."}
Exit status: 0 = model is ready, 1 = failed.

Only the Python standard library is used. Nothing is written into <folder>
until the download is complete and checked; an interrupted run leaves the
previous model (if any) untouched.
"""
import argparse
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

URL = "https://zenodo.org/records/15050749/files/BirdNET_v2.4_tflite.zip"
ZIP_SIZE = 76_822_925          # size of the zip (for progress when the server does not say)
MODEL_FILE = "audio-model.tflite"
MODEL_SIZE = 51_726_412        # size of the model inside it (FP32)
LICENSE = "CC BY-NC-SA 4.0 (non-commercial use; research and education count)"
CITATION = ("Kahl, S., Wood, C. M., Eibl, M. and Klinck, H. (2021). BirdNET: A deep learning solution "
            "for avian diversity monitoring. Ecological Informatics, 61, 101236.")


def emit(**fields):
    print("@@PAM " + json.dumps(fields), flush=True)


def fail(message):
    emit(type="download_failed", message=message)
    return 1


def download(url, target, expected, throttle=0.4):
    request = urllib.request.Request(url, headers={"User-Agent": "pamflow-desktop"})
    with urllib.request.urlopen(request, timeout=60) as response, open(target, "wb") as out:
        total = int(response.headers.get("Content-Length") or expected)
        done, last = 0, 0.0
        emit(type="download", phase="download", done=0, total=total)
        while True:
            chunk = response.read(256 * 1024)
            if not chunk:
                break
            out.write(chunk)
            done += len(chunk)
            now = time.monotonic()
            if now - last >= throttle:
                last = now
                emit(type="download", phase="download", done=done, total=total)
        emit(type="download", phase="download", done=done, total=total)
    return done


def find_member(names, basename):
    hits = [n for n in names if n.rstrip("/").split("/")[-1] == basename]
    return hits[0] if hits else None


def unpack(zip_path, out_dir, model_size):
    """Pull the model and the label files out of the zip into out_dir."""
    if not zipfile.is_zipfile(zip_path):
        raise ValueError("The downloaded file is not a valid zip file (the download may have been interrupted).")
    with zipfile.ZipFile(zip_path) as zf:
        bad = zf.testzip()
        if bad:
            raise ValueError(f"The downloaded zip is damaged ({bad}).")
        names = zf.namelist()
        model_member = find_member(names, MODEL_FILE)
        if model_member is None:
            raise ValueError(f"{MODEL_FILE} was not found in the download.")
        out_dir.mkdir(parents=True)
        (out_dir / "labels").mkdir()
        with zf.open(model_member) as src, open(out_dir / MODEL_FILE, "wb") as dst:
            shutil.copyfileobj(src, dst)
        size = (out_dir / MODEL_FILE).stat().st_size
        if size != model_size:
            raise ValueError(f"The model file has an unexpected size ({size} bytes, expected {model_size}).")
        languages = []
        for member in names:
            parts = member.split("/")
            if len(parts) >= 2 and parts[-2] == "labels" and parts[-1].endswith(".txt"):
                with zf.open(member) as src, open(out_dir / "labels" / parts[-1], "wb") as dst:
                    shutil.copyfileobj(src, dst)
                languages.append(parts[-1][:-4])
    if "en_us" not in languages:
        raise ValueError("The English species list (labels/en_us.txt) was not found in the download.")
    return sorted(languages)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--dest", required=True, help="folder to put the model in")
    ap.add_argument("--url", default=URL)
    ap.add_argument("--zip-size", type=int, default=ZIP_SIZE)
    ap.add_argument("--model-size", type=int, default=MODEL_SIZE)
    ap.add_argument("--force", action="store_true", help="download again even if the model is already there")
    args = ap.parse_args()

    dest = Path(args.dest).expanduser().resolve()
    meta = dest / "model.json"
    if not args.force and meta.is_file() and (dest / MODEL_FILE).is_file() \
            and (dest / MODEL_FILE).stat().st_size == args.model_size:
        emit(type="download", phase="done", already=True)
        return 0

    parent = dest.parent
    try:
        parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        return fail(f"Could not create {parent}: {e}")
    # leftovers of an interrupted earlier download
    for old in parent.glob(f".download-{dest.name}-*"):
        shutil.rmtree(old, ignore_errors=True)
    work = parent / f".download-{dest.name}-{os.getpid()}"
    work.mkdir()
    try:
        zip_path = work / "download.zip"
        try:
            download(args.url, zip_path, args.zip_size)
        except urllib.error.HTTPError as e:
            return fail(f"The download server answered {e.code} {e.reason}.")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            reason = getattr(e, "reason", e)
            return fail(f"Could not download the model: {reason}. Check the internet connection "
                        f"(a firewall or proxy may be blocking zenodo.org) and try again.")
        emit(type="download", phase="extract")
        try:
            languages = unpack(zip_path, work / "model", args.model_size)
        except (ValueError, OSError, zipfile.BadZipFile) as e:
            return fail(str(e))
        staged = work / "model"
        n_species = len((staged / "labels" / "en_us.txt").read_text(encoding="utf-8").splitlines())
        (staged / "model.json").write_text(json.dumps({
            "name": "BirdNET v2.4 global model (FP32)",
            "version": "2.4",
            "model_file": MODEL_FILE,
            "source": args.url,
            "license": LICENSE,
            "citation": CITATION,
            "downloaded": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "languages": languages,
            "n_species": n_species,
        }, indent=2), encoding="utf-8")
        # replace the old copy only now that the new one is complete
        if dest.exists():
            shutil.rmtree(dest)
        os.replace(staged, dest)
    except OSError as e:
        return fail(f"Could not save the model in {dest}: {e}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    emit(type="download", phase="done", n_species=n_species)
    return 0


if __name__ == "__main__":
    sys.exit(main())
