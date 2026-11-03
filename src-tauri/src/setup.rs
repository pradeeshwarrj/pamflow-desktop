//! First-launch setup: unpack the runtime that ships inside the installer.
//!
//! The installer carries the runtime packed (see .github/workflows/release.yml):
//!   <resources>/runtime-pack/runtime.tar         conda packages + Python wheels (pixi-pack)
//!   <resources>/runtime-pack/r-extras.tar.gz     R packages that are not conda packages
//!   <resources>/runtime-pack/pixi-unpack[.exe]   the unpacker
//!   <resources>/runtime-pack/runtime-id.txt      which runtime this is
//!
//! On first launch it is unpacked, offline, into the user's own folders:
//!   Windows  %LOCALAPPDATA%\org.pamflow.desktop\runtime\<id>\env
//!   macOS    ~/Library/pamflow/runtime/<id>/env
//!   Linux    ~/.local/share/pamflow/runtime/<id>/env   ($XDG_DATA_HOME respected)
//! (macOS and Linux avoid paths with spaces: R cannot run from them there.)
//! pixi-unpack writes the real folder into every file that needs it, so the
//! runtime must be unpacked where it will stay. `ready.json` is written last;
//! a folder without it is an interrupted setup and is unpacked again.

use serde::Serialize;
use serde_json::{json, Value};
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;
use tauri::{AppHandle, Emitter, Manager};

use crate::runtime::Runtime;

/// About how much disk the unpacked runtime needs (GB), with some room to spare.
const NEED_GB: f64 = 6.0;

static RUNNING: AtomicBool = AtomicBool::new(false);

/// The packed runtime inside the installed app, if this build has one.
struct Pack {
    dir: PathBuf,
    id: String,
}

fn pack(app: &AppHandle) -> Option<Pack> {
    let dir = crate::runtime::plain(app.path().resource_dir().ok()?.join("runtime-pack"));
    let id = std::fs::read_to_string(dir.join("runtime-id.txt")).ok()?.trim().to_string();
    if id.is_empty() || !dir.join("runtime.tar").is_file() {
        return None;
    }
    Some(Pack { dir, id })
}

/// Folder that holds unpacked runtimes (one sub-folder per runtime id).
pub fn install_root(app: &AppHandle) -> Result<PathBuf, String> {
    let root = if cfg!(windows) {
        app.path().app_local_data_dir().map_err(|e| e.to_string())?.join("runtime")
    } else {
        let home = app.path().home_dir().map_err(|e| e.to_string())?;
        if cfg!(target_os = "macos") {
            home.join("Library").join("pamflow").join("runtime")
        } else {
            let data = std::env::var_os("XDG_DATA_HOME")
                .map(PathBuf::from)
                .filter(|p| p.is_absolute())
                .unwrap_or_else(|| home.join(".local").join("share"));
            data.join("pamflow").join("runtime")
        }
    };
    let root = crate::runtime::plain(root);
    if !cfg!(windows) && root.to_string_lossy().contains(' ') {
        return Err(format!(
            "pamflow needs a folder without spaces for its analysis engine, but this is {}.",
            root.display()
        ));
    }
    Ok(root)
}

/// Folder for models the user downloads (shared by all projects), next to the runtimes:
/// <data>/models, e.g. %LOCALAPPDATA%\org.pamflow.desktop\models.
pub fn models_root(app: &AppHandle) -> Option<PathBuf> {
    install_root(app).ok().and_then(|r| r.parent().map(|p| p.join("models")))
}

/// The unpacked runtime of this build, if its setup has finished.
pub fn installed_prefix(app: &AppHandle) -> Option<PathBuf> {
    let p = pack(app)?;
    let dir = install_root(app).ok()?.join(&p.id);
    dir.join("ready.json").is_file().then(|| dir.join("env"))
}

/// Does this installation still need its one-time setup?
#[tauri::command]
pub fn setup_status(app: AppHandle) -> Value {
    let Some(p) = pack(&app) else {
        // development build, or a runtime given with PAMFLOW_RUNTIME
        return json!({ "needed": false, "packed": false });
    };
    let root = install_root(&app);
    let ready = installed_prefix(&app).is_some();
    json!({
        "needed": !ready,
        "packed": true,
        "running": RUNNING.load(Ordering::SeqCst),
        "id": p.id,
        "target": root.as_ref().map(|r| r.join(&p.id).display().to_string()).ok(),
        "problem": root.err(),
        "need_gb": NEED_GB,
    })
}

#[derive(Clone, Serialize)]
struct SetupEvent {
    phase: &'static str, // "space" | "unpack" | "extras" | "check" | "done" | "failed" | "log"
    message: String,
    seconds: u64,
}

fn emit(app: &AppHandle, t0: Instant, phase: &'static str, message: impl Into<String>) {
    let _ = app.emit(
        "setup-event",
        SetupEvent { phase, message: message.into(), seconds: t0.elapsed().as_secs() },
    );
}

/// Start the one-time setup in the background; progress arrives as "setup-event"s.
#[tauri::command]
pub fn start_setup(app: AppHandle) -> Result<(), String> {
    let p = pack(&app).ok_or("This build has no packed runtime to set up.")?;
    if RUNNING.swap(true, Ordering::SeqCst) {
        return Ok(()); // already running: the screen just keeps listening
    }
    std::thread::spawn(move || {
        let t0 = Instant::now();
        let result = run_setup(&app, &p, t0);
        match result {
            Ok(()) => emit(&app, t0, "done", "pamflow is ready."),
            Err(e) => emit(&app, t0, "failed", e),
        }
        RUNNING.store(false, Ordering::SeqCst);
    });
    Ok(())
}

fn run_setup(app: &AppHandle, p: &Pack, t0: Instant) -> Result<(), String> {
    let root = install_root(app)?;
    let target = root.join(&p.id);

    // 1. room on the disk
    emit(app, t0, "space", "Checking free disk space");
    std::fs::create_dir_all(&root).map_err(|e| format!("Could not create {}: {e}", root.display()))?;
    if let Ok(bytes) = fs4::available_space(&root) {
        let free = bytes as f64 / 1024f64.powi(3);
        if free < NEED_GB {
            return Err(format!(
                "Not enough free disk space: pamflow needs about {NEED_GB:.0} GB in {}, but only {free:.1} GB is free.",
                root.display()
            ));
        }
    }

    // 2. unpack (an interrupted earlier attempt is removed first)
    if target.exists() {
        std::fs::remove_dir_all(&target)
            .map_err(|e| format!("Could not remove an unfinished setup in {}: {e}", target.display()))?;
    }
    std::fs::create_dir_all(&target).map_err(|e| e.to_string())?;
    emit(app, t0, "unpack", "Unpacking R, Python, BirdNET and ffmpeg");
    let unpacker = runnable_unpacker(&p.dir, &root)?;
    let mut cmd = Command::new(&unpacker);
    cmd.arg("--output-directory").arg(&target).arg(p.dir.join("runtime.tar"));
    run_logged(app, t0, cmd).map_err(|e| format!("Unpacking the runtime failed: {e}"))?;
    let prefix = target.join("env");

    // 3. the R packages that are not conda packages
    emit(app, t0, "extras", "Adding pamflow and its R packages");
    add_r_extras(&prefix, &p.dir.join("r-extras.tar.gz"))?;

    // 4. does pamflow load?
    emit(app, t0, "check", "Checking that pamflow starts");
    let rt = Runtime { prefix: prefix.clone(), bridge: PathBuf::new() };
    let script = "suppressPackageStartupMessages(library(pamflow)); cat('pamflow', as.character(utils::packageVersion('pamflow')))";
    let out = rt
        .rscript_command(&["-e".as_ref(), script.as_ref()])
        .output()
        .map_err(|e| format!("Could not start R: {e}"))?;
    let text = format!("{}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
    if !out.status.success() || !text.contains("pamflow ") {
        return Err(format!("pamflow did not start in the new runtime:\n{}", text.trim()));
    }
    emit(app, t0, "log", text.trim().to_string());

    // 5. done: mark it, and remove runtimes of older versions
    let ready = json!({ "id": p.id, "seconds": t0.elapsed().as_secs(), "check": text.trim() });
    std::fs::write(target.join("ready.json"), ready.to_string()).map_err(|e| e.to_string())?;
    if let Ok(entries) = std::fs::read_dir(&root) {
        for e in entries.flatten() {
            if e.path() != target && e.path().is_dir() && e.file_name().to_string_lossy().starts_with("rt-") {
                let _ = std::fs::remove_dir_all(e.path());
            }
        }
    }
    Ok(())
}

/// The unpacker, ready to run. On macOS and Linux a bundled file can lose its
/// "executable" flag, and an AppImage's files cannot be changed, so it is
/// copied next to the runtimes and marked executable there when needed.
fn runnable_unpacker(pack_dir: &Path, root: &Path) -> Result<PathBuf, String> {
    let bundled = pack_dir.join(if cfg!(windows) { "pixi-unpack.exe" } else { "pixi-unpack" });
    if !bundled.is_file() {
        return Err(format!("The unpacker is missing from the app: {}", bundled.display()));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let executable = |p: &Path| std::fs::metadata(p).map(|m| m.permissions().mode() & 0o111 != 0).unwrap_or(false);
        if !executable(&bundled) {
            let copy = root.join("pixi-unpack");
            std::fs::copy(&bundled, &copy).map_err(|e| format!("Could not copy the unpacker: {e}"))?;
            std::fs::set_permissions(&copy, std::fs::Permissions::from_mode(0o755)).map_err(|e| e.to_string())?;
            return Ok(copy);
        }
    }
    let _ = root;
    Ok(bundled)
}

/// Run a command, passing each line it prints on as a "log" event.
fn run_logged(app: &AppHandle, t0: Instant, mut cmd: Command) -> Result<(), String> {
    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    }
    let mut child = cmd.spawn().map_err(|e| e.to_string())?;
    let stderr = child.stderr.take();
    let app2 = app.clone();
    let err_thread = std::thread::spawn(move || {
        let mut last = Vec::new();
        if let Some(s) = stderr {
            for line in BufReader::new(s).lines().map_while(Result::ok) {
                emit(&app2, t0, "log", line.clone());
                last.push(line);
                if last.len() > 20 {
                    last.remove(0);
                }
            }
        }
        last
    });
    if let Some(s) = child.stdout.take() {
        for line in BufReader::new(s).lines().map_while(Result::ok) {
            emit(app, t0, "log", line);
        }
    }
    let status = child.wait().map_err(|e| e.to_string())?;
    let last = err_thread.join().unwrap_or_default();
    if status.success() {
        Ok(())
    } else {
        let code = status.code().map_or_else(|| "stopped".to_string(), |c| c.to_string());
        Err(format!("exit code {code}\n{}", last.join("\n")))
    }
}

/// Unpack the extra R packages into the runtime's R library.
fn add_r_extras(prefix: &Path, archive: &Path) -> Result<(), String> {
    let library = prefix.join(if cfg!(windows) { "Lib" } else { "lib" }).join("R").join("library");
    if !library.is_dir() {
        return Err(format!("The runtime's R library was not found at {}", library.display()));
    }
    let open = || -> Result<tar::Archive<flate2::read::GzDecoder<std::fs::File>>, String> {
        let f = std::fs::File::open(archive).map_err(|e| format!("Could not open {}: {e}", archive.display()))?;
        Ok(tar::Archive::new(flate2::read::GzDecoder::new(f)))
    };
    // replace older copies of the same packages
    let mut names = std::collections::BTreeSet::new();
    for entry in open()?.entries().map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        if let Some(first) = entry.path().ok().and_then(|p| p.components().next().map(|c| c.as_os_str().to_owned())) {
            names.insert(first);
        }
    }
    for n in &names {
        let _ = std::fs::remove_dir_all(library.join(n));
    }
    open()?
        .unpack(&library)
        .map_err(|e| format!("Could not add the extra R packages: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extras_replace_old_copies_in_the_r_library() {
        let tmp = std::env::temp_dir().join(format!("pf-setup-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let lib = tmp.join("env").join(if cfg!(windows) { "Lib" } else { "lib" }).join("R").join("library");
        std::fs::create_dir_all(lib.join("pamflow").join("old")).unwrap();
        std::fs::write(lib.join("pamflow").join("old").join("stale.txt"), "x").unwrap();

        // archive with pamflow/DESCRIPTION and tuneR/DESCRIPTION
        let src = tmp.join("src");
        for p in ["pamflow", "tuneR"] {
            std::fs::create_dir_all(src.join(p)).unwrap();
            std::fs::write(src.join(p).join("DESCRIPTION"), format!("Package: {p}\n")).unwrap();
        }
        let archive = tmp.join("r-extras.tar.gz");
        let gz = flate2::write::GzEncoder::new(std::fs::File::create(&archive).unwrap(), flate2::Compression::fast());
        let mut b = tar::Builder::new(gz);
        b.append_dir_all("pamflow", src.join("pamflow")).unwrap();
        b.append_dir_all("tuneR", src.join("tuneR")).unwrap();
        b.into_inner().unwrap().finish().unwrap();

        add_r_extras(&tmp.join("env"), &archive).unwrap();
        assert!(lib.join("pamflow").join("DESCRIPTION").is_file());
        assert!(lib.join("tuneR").join("DESCRIPTION").is_file());
        assert!(!lib.join("pamflow").join("old").exists(), "old copy must be replaced");
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
