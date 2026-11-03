//! Running pamflow jobs: start an R process with the bridge script, pass its
//! progress events to the screen, and stop it (with everything it started).
//!
//! Every event reaches the interface as a "job-event" message:
//!   { "id": "<job id>", "event": { "type": "...", ... } }
//! Event types come from the R bridge (see bridge/protocol.R), plus:
//!   "text"  a plain output line (R warnings, BirdNET messages)
//!   "exit"  the R process ended: { "code": 0 | 1 | null, "stopped": bool }

use crate::runtime::Runtime;
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read};
use std::process::Stdio;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State};

const EVENT_PREFIX: &str = "@@PAM ";

#[derive(Default)]
pub struct Jobs {
    running: Mutex<HashMap<String, RunningJob>>,
    /// Held while a long job runs, so the computer does not go to sleep (and stop it).
    awake: Mutex<Option<keepawake::KeepAwake>>,
}

struct RunningJob {
    pid: u32,
    stop_requested: bool,
    /// A job that can take minutes to days (see `is_long`).
    long: bool,
}

/// Jobs worth keeping the computer awake for and asking before closing the app.
/// Quick jobs (reading a project, saving settings) are not.
fn is_long(job: &str) -> bool {
    matches!(
        job,
        "detect" | "filter" | "standardize" | "std_plan" | "scan" | "process" | "validation_draw" | "report" | "model_download"
    )
}

impl Jobs {
    /// How many long jobs are running now.
    pub fn long_running(&self) -> usize {
        self.running.lock().unwrap().values().filter(|j| j.long).count()
    }

    /// Keep the computer awake exactly while a long job runs.
    fn update_awake(&self) {
        let needed = self.long_running() > 0;
        let mut guard = self.awake.lock().unwrap();
        if needed && guard.is_none() {
            // not being able to do this must never stop the work itself
            *guard = keepawake::Builder::default()
                .idle(true)
                .sleep(true)
                .reason("pamflow is running an analysis")
                .app_name("pamflow")
                .app_reverse_domain("org.pamflow.desktop")
                .create()
                .ok();
        } else if !needed {
            *guard = None; // dropping it lets the computer sleep again
        }
    }
}

/// Is the "really close?" question already on screen?
static CLOSE_PROMPT_OPEN: AtomicBool = AtomicBool::new(false);

/// The window's close button was pressed. With a long job running, ask first
/// (the screen shows the question); a second press while it is open closes anyway.
pub fn on_close_requested(window: &tauri::Window, api: &tauri::CloseRequestApi) {
    let jobs = window.state::<Jobs>();
    if jobs.long_running() > 0 && !CLOSE_PROMPT_OPEN.swap(true, Ordering::SeqCst) {
        api.prevent_close();
        let _ = window.emit("close-requested", ());
    }
}

/// The question was answered (yes or no).
#[tauri::command]
pub fn close_prompt_done() {
    CLOSE_PROMPT_OPEN.store(false, Ordering::SeqCst);
}

/// Stop everything and close the app (the answer "yes" to the question above).
#[tauri::command]
pub fn quit_app(app: AppHandle, jobs: State<'_, Jobs>) {
    stop_all(&jobs);
    app.exit(0);
}

#[derive(Clone, Serialize)]
struct JobEvent {
    id: String,
    event: Value,
}

fn emit(app: &AppHandle, id: &str, event: Value) {
    let _ = app.emit("job-event", JobEvent { id: id.to_string(), event });
}

/// Where the runtime is, or why it cannot be found.
#[tauri::command]
pub fn runtime_info(app: AppHandle) -> Value {
    match Runtime::locate(&app) {
        Ok(rt) => json!({ "found": true, "prefix": rt.prefix, "bridge": rt.bridge, "rscript": rt.rscript() }),
        Err(message) => json!({ "found": false, "message": message }),
    }
}

/// Free space (in GB) on the drive holding `path`. If the folder does not
/// exist yet, the nearest existing parent folder is used.
#[tauri::command]
pub fn free_space_gb(path: String) -> Option<f64> {
    let mut p = std::path::PathBuf::from(path);
    loop {
        if p.exists() {
            return fs4::available_space(&p).ok().map(|b| (b as f64) / 1024f64.powi(3));
        }
        if !p.pop() {
            return None;
        }
    }
}

/// Start a job. `spec` is the job description for bridge/run_job.R
/// (job, project, birdnet overrides, sample_n); the runtime folder is added here.
/// Returns the job id; progress arrives as "job-event" messages.
#[tauri::command]
pub fn start_job(app: AppHandle, jobs: State<'_, Jobs>, spec: Value) -> Result<String, String> {
    let rt = Runtime::locate(&app)?;
    let id = new_job_id();

    let mut spec = spec;
    let long = spec.get("job").and_then(Value::as_str).map(is_long).unwrap_or(false);
    if let Some(obj) = spec.as_object_mut() {
        obj.insert("runtime".into(), json!(rt.prefix));
        if let Some(models) = crate::setup::models_root(&app) {
            obj.insert("models_dir".into(), json!(models));
        }
        if let Ok(docs) = app.path().document_dir() {
            obj.insert("documents_dir".into(), json!(crate::runtime::plain(docs)));
        }
        obj.insert("app_version".into(), json!(app.package_info().version.to_string()));
    } else {
        return Err("job description must be an object".into());
    }

    // The job description is handed to R as a small JSON file.
    let jobs_dir = crate::runtime::plain(app.path().app_data_dir().map_err(|e| e.to_string())?.join("jobs"));
    std::fs::create_dir_all(&jobs_dir).map_err(|e| format!("cannot create {}: {e}", jobs_dir.display()))?;
    let spec_path = jobs_dir.join(format!("{id}.json"));
    std::fs::write(&spec_path, serde_json::to_vec_pretty(&spec).unwrap_or_default())
        .map_err(|e| format!("cannot write {}: {e}", spec_path.display()))?;

    let script = rt.bridge.join("run_job.R");
    let mut cmd = rt.rscript_command(&[script.as_os_str(), spec_path.as_os_str()]);
    cmd.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = cmd
        .spawn()
        .map_err(|e| format!("could not start R ({}): {e}", rt.rscript().display()))?;

    let pid = child.id();
    jobs.running
        .lock()
        .unwrap()
        .insert(id.clone(), RunningJob { pid, stop_requested: false, long });
    jobs.update_awake();

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    if let Some(out) = stdout {
        let (app, id) = (app.clone(), id.clone());
        std::thread::spawn(move || read_lines(out, |line| forward_line(&app, &id, line, "stdout")));
    }
    if let Some(err) = stderr {
        let (app, id) = (app.clone(), id.clone());
        std::thread::spawn(move || read_lines(err, |line| forward_line(&app, &id, line, "stderr")));
    }

    // Wait for the end in the background, then report it.
    {
        let (app, id) = (app.clone(), id.clone());
        std::thread::spawn(move || {
            let status = child.wait();
            let stopped = app
                .state::<Jobs>()
                .running
                .lock()
                .unwrap()
                .remove(&id)
                .map(|j| j.stop_requested)
                .unwrap_or(false);
            app.state::<Jobs>().update_awake();
            let code = status.ok().and_then(|s| s.code());
            emit(&app, &id, json!({ "type": "exit", "code": code, "stopped": stopped }));
            let _ = std::fs::remove_file(&spec_path);
        });
    }

    Ok(id)
}

/// Stop a running job, including BirdNET's worker processes.
/// pamflow saves progress after every batch, so starting the job again
/// continues where it stopped.
#[tauri::command]
pub fn stop_job(app: AppHandle, jobs: State<'_, Jobs>, id: String) -> Result<(), String> {
    let pid = {
        let mut running = jobs.running.lock().unwrap();
        let job = running.get_mut(&id).ok_or("this job is not running")?;
        job.stop_requested = true;
        job.pid
    };
    emit(&app, &id, json!({ "type": "stopping" }));
    kill_tree(pid);
    Ok(())
}

/// Stop every running job (used when the app closes).
pub fn stop_all(jobs: &Jobs) {
    let pids: Vec<u32> = jobs.running.lock().unwrap().values().map(|j| j.pid).collect();
    for pid in pids {
        kill_tree(pid);
    }
    *jobs.awake.lock().unwrap() = None;
}

fn forward_line(app: &AppHandle, id: &str, line: &str, stream: &str) {
    let line = line.trim_end_matches(['\r', '\n']);
    if line.is_empty() {
        return;
    }
    if let Some(rest) = line.strip_prefix(EVENT_PREFIX) {
        match serde_json::from_str::<Value>(rest) {
            Ok(event) => emit(app, id, event),
            Err(_) => emit(app, id, json!({ "type": "text", "stream": stream, "text": line })),
        }
    } else {
        emit(app, id, json!({ "type": "text", "stream": stream, "text": line }));
    }
}

/// Read a stream line by line, tolerating text that is not valid UTF-8.
fn read_lines<R: Read>(stream: R, mut on_line: impl FnMut(&str)) {
    let mut reader = BufReader::new(stream);
    let mut buf = Vec::new();
    loop {
        buf.clear();
        match reader.read_until(b'\n', &mut buf) {
            Ok(0) | Err(_) => break,
            Ok(_) => on_line(&String::from_utf8_lossy(&buf)),
        }
    }
}

/// End a process and all processes it started.
fn kill_tree(pid: u32) {
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        let _ = std::process::Command::new("taskkill")
            .args(["/PID", &pid.to_string(), "/T", "/F"])
            .creation_flags(CREATE_NO_WINDOW)
            .status();
    }
    #[cfg(unix)]
    {
        // The job was started in its own process group (see runtime.rs).
        let group = -(pid as i32);
        unsafe {
            libc::kill(group, libc::SIGTERM);
        }
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_secs(3));
            unsafe {
                libc::kill(group, libc::SIGKILL);
            }
        });
    }
}

fn new_job_id() -> String {
    use std::sync::atomic::{AtomicU32, Ordering};
    static COUNTER: AtomicU32 = AtomicU32::new(0);
    let ms = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0);
    format!("job-{ms}-{}", COUNTER.fetch_add(1, Ordering::Relaxed))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_long_jobs_count() {
        for j in ["detect", "filter", "standardize", "scan", "report", "model_download"] {
            assert!(is_long(j), "{j} should count as long");
        }
        for j in ["inspect", "config_save", "model_info", "project_create", "diagnostics"] {
            assert!(!is_long(j), "{j} should not count as long");
        }
    }

    #[test]
    fn long_running_counts_and_keep_awake_never_panics() {
        let jobs = Jobs::default();
        assert_eq!(jobs.long_running(), 0);
        jobs.running.lock().unwrap().insert("a".into(), RunningJob { pid: 1, stop_requested: false, long: true });
        jobs.running.lock().unwrap().insert("b".into(), RunningJob { pid: 2, stop_requested: false, long: false });
        assert_eq!(jobs.long_running(), 1);
        jobs.update_awake(); // may fail to get a lock on a machine without a desktop session; that is fine
        jobs.running.lock().unwrap().remove("a");
        jobs.update_awake();
        assert!(jobs.awake.lock().unwrap().is_none(), "released when no long job runs");
    }
}
