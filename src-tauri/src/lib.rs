// Rust side of pamflow Desktop.
//
//   runtime.rs  finds the bundled R/Python runtime and prepares commands in it
//   jobs.rs     starts, follows and stops pamflow jobs (via bridge/run_job.R)
//   validation.rs  saves validation answers, shows clips and spectrograms

mod jobs;
mod runtime;
mod validation;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(jobs::Jobs::default())
        .invoke_handler(tauri::generate_handler![
            jobs::runtime_info,
            jobs::free_space_gb,
            jobs::start_job,
            jobs::stop_job,
            validation::save_validation_answer,
            validation::allow_media_folder
        ])
        .build(tauri::generate_context!())
        .expect("error while building pamflow")
        .run(|app, event| {
            // Closing the app stops running jobs; they resume on the next Start.
            if let tauri::RunEvent::Exit = event {
                jobs::stop_all(&app.state::<jobs::Jobs>());
            }
        });
}
