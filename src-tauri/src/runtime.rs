//! Finding the bundled runtime (R + pamflow + Python/BirdNET + ffmpeg) and
//! preparing commands that run inside it, sealed off from any R or Python
//! the user may have installed themselves.
//!
//! Where the runtime is looked for, in order:
//!   1. the PAMFLOW_RUNTIME environment variable (a runtime folder)
//!   2. the installed app's runtime, unpacked on first launch (see setup.rs)
//!   3. a runtime folder inside the app: <resources>/runtime
//!   4. while developing: <project>/runtime/.pixi/envs/default
//!      (made by `pixi install` in the runtime folder)

use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Command;
use tauri::{AppHandle, Manager};

#[derive(Debug, Clone, Serialize)]
pub struct Runtime {
    /// Runtime folder (the conda/pixi environment).
    pub prefix: PathBuf,
    /// Folder holding the R bridge scripts (run_job.R, protocol.R, ...).
    pub bridge: PathBuf,
}

impl Runtime {
    pub fn locate(app: &AppHandle) -> Result<Runtime, String> {
        let mut tried: Vec<PathBuf> = Vec::new();

        // Bridge scripts: next to the app when installed, in the project when developing.
        let bridge_candidates = [
            app.path().resource_dir().ok().map(|d| d.join("bridge")),
            dev_root().map(|d| d.join("bridge")),
        ];
        let bridge = bridge_candidates
            .into_iter()
            .flatten()
            .find(|d| d.join("run_job.R").is_file())
            .ok_or_else(|| "The app's R bridge scripts (bridge/run_job.R) were not found.".to_string())?;

        let mut candidates: Vec<PathBuf> = Vec::new();
        if let Ok(p) = std::env::var("PAMFLOW_RUNTIME") {
            candidates.push(PathBuf::from(p));
        }
        if let Some(p) = crate::setup::installed_prefix(app) {
            candidates.push(p);
        }
        if let Ok(d) = app.path().resource_dir() {
            candidates.push(d.join("runtime"));
        }
        if let Some(root) = dev_root() {
            candidates.push(root.join("runtime").join(".pixi").join("envs").join("default"));
        }

        // R cannot read Windows "\\?\C:\..." long-path names; use plain C:\... names.
        let bridge = plain(bridge);
        for prefix in candidates.into_iter().map(plain) {
            if rscript_in(&prefix).is_file() {
                return Ok(Runtime { prefix, bridge });
            }
            tried.push(prefix);
        }
        Err(format!(
            "The analysis engine (runtime) was not found. Looked in:\n{}\n\nWhile developing, build it with `pixi install` and `pixi run setup-r` in the runtime folder.",
            tried.iter().map(|p| format!("  {}", p.display())).collect::<Vec<_>>().join("\n")
        ))
    }

    pub fn rscript(&self) -> PathBuf {
        rscript_in(&self.prefix)
    }

    /// A command that runs `Rscript <args>` inside the runtime.
    pub fn rscript_command(&self, args: &[&std::ffi::OsStr]) -> Command {
        let mut cmd = Command::new(self.rscript());
        cmd.args(args);
        self.apply_env(&mut cmd);
        cmd
    }

    /// The same environment `pixi run` sets up, plus isolation from the
    /// user's own R and Python settings.
    fn apply_env(&self, cmd: &mut Command) {
        let p = &self.prefix;
        let mut path_dirs: Vec<PathBuf> = if cfg!(windows) {
            vec![
                p.clone(),
                p.join("Library").join("mingw-w64").join("bin"),
                p.join("Library").join("usr").join("bin"),
                p.join("Library").join("bin"),
                p.join("Scripts"),
                p.join("bin"),
                p.join("lib").join("R").join("bin").join("x64"),
            ]
        } else {
            vec![p.join("bin")]
        };
        if let Some(existing) = std::env::var_os("PATH") {
            path_dirs.extend(std::env::split_paths(&existing));
        }
        if let Ok(joined) = std::env::join_paths(path_dirs) {
            cmd.env("PATH", joined);
        }
        cmd.env("CONDA_PREFIX", p);

        // Ignore the user's own R installation and settings.
        for var in ["R_HOME", "R_LIBS_SITE", "PYTHONHOME", "PYTHONPATH", "RETICULATE_PYTHON"] {
            cmd.env_remove(var);
        }
        cmd.env("R_LIBS_USER", "NULL")
            .env("R_LIBS", "")
            .env("R_PROFILE_USER", "NULL")
            .env("R_ENVIRON_USER", "NULL");

        // Certificates for any HTTPS the runtime does (e.g. model downloads).
        let cert = if cfg!(windows) {
            p.join("Library").join("ssl").join("cacert.pem")
        } else {
            p.join("ssl").join("cacert.pem")
        };
        if cert.is_file() {
            cmd.env("SSL_CERT_FILE", cert);
        }

        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            const CREATE_NO_WINDOW: u32 = 0x0800_0000;
            cmd.creation_flags(CREATE_NO_WINDOW); // no black console window
        }
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            cmd.process_group(0); // so Stop can end R and everything it started
        }
    }
}

/// A path without Windows' "\\?\" prefix (no change elsewhere).
pub fn plain(p: PathBuf) -> PathBuf {
    dunce::simplified(&p).to_path_buf()
}

fn rscript_in(prefix: &Path) -> PathBuf {
    if cfg!(windows) {
        prefix.join("lib").join("R").join("bin").join("Rscript.exe")
    } else {
        prefix.join("bin").join("Rscript")
    }
}

/// The project folder while developing (`pnpm tauri dev`); None in release builds.
fn dev_root() -> Option<PathBuf> {
    if cfg!(debug_assertions) {
        Path::new(env!("CARGO_MANIFEST_DIR")).parent().map(Path::to_path_buf)
    } else {
        None
    }
}
