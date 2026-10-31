// Rust side of pamflow Desktop.
// Phase 1–2 adds the commands here that start R jobs and stream their progress.

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("error while running pamflow");
}
