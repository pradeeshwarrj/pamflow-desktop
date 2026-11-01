//! Validation answers and media.
//!
//! Answers are written straight to pamflow's `validation_results.csv`
//! (same columns and order as pamflow's own validation app), so each
//! keypress is saved at once without starting R. The clips and
//! spectrograms pamflow made are shown by letting the window read the
//! project's validation folder, and nothing else.

use serde::Deserialize;
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager};

const RESULTS_FILE: &str = "validation_results.csv";
const COLUMNS: [&str; 6] = ["sample_id", "verdict", "true_species", "note", "reviewer", "reviewed_at"];

#[derive(Debug, Clone, Deserialize)]
pub struct Answer {
    pub sample_id: i64,
    pub verdict: String,      // "correct" | "incorrect" | "unsure"
    pub true_species: String, // filled in when the verdict is "incorrect"
    pub note: String,
    pub reviewer: String,
    pub reviewed_at: String,  // "YYYY-MM-DD HH:MM:SS", local time
}

/// Save (or replace) one answer in validation_results.csv.
#[tauri::command]
pub fn save_validation_answer(results_path: String, answer: Answer) -> Result<(), String> {
    let path = PathBuf::from(&results_path);
    if path.file_name().and_then(|n| n.to_str()) != Some(RESULTS_FILE) {
        return Err(format!("refusing to write {results_path}: not a {RESULTS_FILE}"));
    }
    if !matches!(answer.verdict.as_str(), "correct" | "incorrect" | "unsure") {
        return Err(format!("unknown verdict: {}", answer.verdict));
    }
    upsert_answer(&path, &answer)
}

/// Let the window show files from a validation folder (clips, spectrograms).
#[tauri::command]
pub fn allow_media_folder(app: AppHandle, folder: String) -> Result<(), String> {
    let dir = PathBuf::from(&folder);
    if dir.file_name().and_then(|n| n.to_str()) != Some("validation") || !dir.is_dir() {
        return Err(format!("not a validation folder: {folder}"));
    }
    app.asset_protocol_scope()
        .allow_directory(&dir, true)
        .map_err(|e| e.to_string())
}

pub fn upsert_answer(path: &Path, answer: &Answer) -> Result<(), String> {
    // Keep every earlier answer except an older one for the same sample.
    let mut rows: Vec<Vec<String>> = Vec::new();
    if path.is_file() {
        let mut reader = csv::ReaderBuilder::new()
            .flexible(true)
            .from_path(path)
            .map_err(|e| format!("cannot read {}: {e}", path.display()))?;
        let headers = reader.headers().map_err(|e| e.to_string())?.clone();
        let index: Vec<Option<usize>> =
            COLUMNS.iter().map(|c| headers.iter().position(|h| h == *c)).collect();
        for record in reader.records() {
            let record = record.map_err(|e| e.to_string())?;
            let row: Vec<String> = index
                .iter()
                .map(|i| i.and_then(|i| record.get(i)).unwrap_or("").to_string())
                .collect();
            if row[0].trim().parse::<i64>().ok() != Some(answer.sample_id) {
                rows.push(row);
            }
        }
    }
    rows.push(vec![
        answer.sample_id.to_string(),
        answer.verdict.clone(),
        answer.true_species.clone(),
        answer.note.clone(),
        answer.reviewer.clone(),
        answer.reviewed_at.clone(),
    ]);

    // Write to a temporary file first, then swap it in, so a crash never
    // leaves a half-written results file.
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    }
    let tmp = path.with_extension("csv.part");
    {
        let mut writer = csv::Writer::from_path(&tmp).map_err(|e| e.to_string())?;
        writer.write_record(COLUMNS).map_err(|e| e.to_string())?;
        for row in &rows {
            writer.write_record(row).map_err(|e| e.to_string())?;
        }
        writer.flush().map_err(|e| e.to_string())?;
    }
    if path.exists() {
        std::fs::remove_file(path).map_err(|e| format!("cannot replace {}: {e}", path.display()))?;
    }
    std::fs::rename(&tmp, path).map_err(|e| format!("cannot save {}: {e}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn answer(id: i64, verdict: &str, species: &str) -> Answer {
        Answer {
            sample_id: id,
            verdict: verdict.into(),
            true_species: species.into(),
            note: "".into(),
            reviewer: "RJ".into(),
            reviewed_at: "2026-11-01 10:00:00".into(),
        }
    }

    #[test]
    fn creates_updates_and_keeps_other_answers() {
        let dir = std::env::temp_dir().join(format!("pamflow-val-test-{}", std::process::id()));
        let path = dir.join(RESULTS_FILE);
        let _ = std::fs::remove_dir_all(&dir);

        upsert_answer(&path, &answer(3, "correct", "")).unwrap();
        upsert_answer(&path, &answer(7, "incorrect", "Otus alius_Nicobar Scops-Owl, maybe")).unwrap();
        upsert_answer(&path, &answer(3, "unsure", "")).unwrap(); // replaces the first answer

        let text = std::fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines[0], "sample_id,verdict,true_species,note,reviewer,reviewed_at");
        assert_eq!(lines.len(), 3);
        assert!(lines[1].starts_with("7,incorrect,\"Otus alius_Nicobar Scops-Owl, maybe\""));
        assert!(lines[2].starts_with("3,unsure,"));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn reads_files_written_by_pamflow_with_extra_columns() {
        let dir = std::env::temp_dir().join(format!("pamflow-val-test2-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(RESULTS_FILE);
        std::fs::write(&path, "sample_id,verdict,true_species,note,reviewer,reviewed_at,extra\n1,correct,,,RJ,2026-10-01 09:00:00,x\n").unwrap();
        upsert_answer(&path, &answer(2, "correct", "")).unwrap();
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("1,correct,,,RJ,2026-10-01 09:00:00\n"));
        assert!(text.contains("2,correct,,,RJ,2026-11-01 10:00:00\n"));
        let _ = std::fs::remove_dir_all(&dir);
    }
}
