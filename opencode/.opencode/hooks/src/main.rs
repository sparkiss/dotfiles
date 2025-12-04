use anyhow::{Context, Result};
use clap::Parser;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tokio::time::sleep;

#[derive(Parser)]
#[command(name = "opencode-zulip-sync")]
#[command(about = "Sync OpenCode conversations to Zulip in real-time")]
struct Args {
    /// OpenCode storage directory
    #[arg(long, default_value = "~/.local/share/opencode/storage")]
    storage_dir: PathBuf,
}

#[derive(Clone)]
struct ZulipConfig {
    site: String,
    bot_email: String,
    bot_api_key: String,
    stream: String,
}

impl ZulipConfig {
    fn from_env() -> Result<Self> {
        Ok(Self {
            site: env::var("ZULIP_SITE").context("ZULIP_SITE not set")?,
            bot_email: env::var("ZULIP_BOT_EMAIL").context("ZULIP_BOT_EMAIL not set")?,
            bot_api_key: env::var("ZULIP_BOT_API_KEY").context("ZULIP_BOT_API_KEY not set")?,
            stream: env::var("ZULIP_STREAM_OPEN_CODE")
                .unwrap_or_else(|_| "opencode".to_string()),
        })
    }
}

#[derive(Clone)]
struct Message {
    role: String,
    content: String,
    session_id: String,
}

#[derive(Clone)]
struct SyncState {
    sent_hashes: Arc<RwLock<HashSet<String>>>,
    processed_messages: Arc<RwLock<HashSet<String>>>,
    config: ZulipConfig,
    message_dir: PathBuf,
    part_dir: PathBuf,
}

impl SyncState {
    fn new(config: ZulipConfig, storage_dir: PathBuf) -> Self {
        Self {
            sent_hashes: Arc::new(RwLock::new(HashSet::new())),
            processed_messages: Arc::new(RwLock::new(HashSet::new())),
            config,
            message_dir: storage_dir.join("message"),
            part_dir: storage_dir.join("part"),
        }
    }

    async fn get_message_content(&self, msg_id: &str) -> Result<String> {
        let part_dir = self.part_dir.join(msg_id);
        if !part_dir.exists() {
            return Ok(String::new());
        }

        let mut text_parts = Vec::new();
        let mut entries: Vec<_> = fs::read_dir(&part_dir)?.collect::<Result<Vec<_>, _>>()?;
        entries.sort_by_key(|entry| entry.file_name());

        for entry in entries {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("json") {
                continue;
            }

            let content = fs::read_to_string(&path)?;
            if let Ok(part) = serde_json::from_str::<Value>(&content) {
                if let Some(part_type) = part.get("type").and_then(|v| v.as_str()) {
                    if part_type == "text" {
                        if let Some(text) = part.get("text").and_then(|v| v.as_str()) {
                            text_parts.push(text.to_string());
                        }
                    }
                }
            }
        }

        Ok(text_parts.join("\n"))
    }

    async fn send_to_zulip(&self, message: &Message) -> Result<()> {
        if message.content.trim().is_empty() {
            return Ok(());
        }

        // Create hash for duplicate detection
        let hash_input = format!("{}:{}:{}", message.session_id, message.role, message.content);
        let hash = hex::encode(Sha256::digest(hash_input.as_bytes()));

        // Check if already sent
        {
            let sent_hashes = self.sent_hashes.read().await;
            if sent_hashes.contains(&hash) {
                return Ok(());
            }
        }

        // Add to sent hashes
        {
            let mut sent_hashes = self.sent_hashes.write().await;
            sent_hashes.insert(hash);
        }

        // Format message
        let prefix = if message.role == "user" {
            "**You**"
        } else {
            "**OpenCode**"
        };

        let mut content = message.content.clone();
        if content.len() > 10000 {
            // Find a valid UTF-8 boundary to truncate at
            let mut truncate_at = 10000;
            while truncate_at > 0 && !content.is_char_boundary(truncate_at) {
                truncate_at -= 1;
            }
            content.truncate(truncate_at);
            content.push_str("\n\n... (truncated)");
        }

        let formatted_content = format!("{}\n\n{}", prefix, content);
        let short_session = message.session_id.replace("ses_", "").chars().take(8).collect::<String>();

        // Send to Zulip
        let client = reqwest::Client::new();
        let response = client
            .post(&format!("{}/api/v1/messages", self.config.site))
            .basic_auth(&self.config.bot_email, Some(&self.config.bot_api_key))
            .form(&[
                ("type", "stream"),
                ("to", &self.config.stream),
                ("topic", &format!("Session {}", short_session)),
                ("content", &formatted_content),
            ])
            .timeout(Duration::from_secs(10))
            .send()
            .await?;

        let status = response.status();
        if status.as_u16() != 200 {
            let error_text = response.text().await.unwrap_or_default();
            anyhow::bail!("Zulip error: {} {}", status, error_text);
        }

        println!(
            "Sent {} message from session {}...",
            message.role,
            &message.session_id[..message.session_id.len().min(16)]
        );

        Ok(())
    }

    async fn process_message_file(&self, filepath: &Path) -> Result<()> {
        if filepath.extension().and_then(|s| s.to_str()) != Some("json") {
            return Ok(());
        }

        let msg_id = filepath
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_string();

        // Check if already processed
        {
            let processed = self.processed_messages.read().await;
            if processed.contains(&msg_id) {
                return Ok(());
            }
        }

        // Read message file
        let content = fs::read_to_string(filepath)?;
        let msg: Value = serde_json::from_str(&content)?;

        let role = msg.get("role").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let session_id = msg.get("sessionID").and_then(|v| v.as_str()).unwrap_or("").to_string();

        if role.is_empty() || session_id.is_empty() {
            return Ok(());
        }

        // Small delay to let part files be written
        sleep(Duration::from_millis(500)).await;

        // Get content from parts
        let message_content = self.get_message_content(&msg_id).await?;

        if !message_content.is_empty() {
            let message = Message {
                role,
                content: message_content,
                session_id,
            };

            // Mark as processed before sending to avoid duplicates
            {
                let mut processed = self.processed_messages.write().await;
                processed.insert(msg_id);
            }

            self.send_to_zulip(&message).await?;
        }

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Expand tilde in path
    let storage_dir = shellexpand::tilde(&args.storage_dir.to_string_lossy()).to_string();
    let storage_dir = PathBuf::from(storage_dir);

    let config = match ZulipConfig::from_env() {
        Ok(config) => config,
        Err(e) => {
            eprintln!("Error: Missing Zulip configuration. Set these environment variables:");
            eprintln!("  ZULIP_SITE (e.g., https://zulip.example.com)");
            eprintln!("  ZULIP_BOT_EMAIL");
            eprintln!("  ZULIP_BOT_API_KEY");
            eprintln!("  ZULIP_STREAM_OPEN_CODE (optional, defaults to 'opencode')");
            eprintln!("\nError details: {}", e);
            return Ok(());
        }
    };

    let state = SyncState::new(config.clone(), storage_dir.clone());

    println!("Watching {} for opencode conversations...", state.message_dir.display());
    println!("Parts directory: {}", state.part_dir.display());
    println!("Sending to: {} stream '{}'", config.site, config.stream);

    // Create directories if they don't exist
    if !state.message_dir.exists() {
        fs::create_dir_all(&state.message_dir)?;
        println!("Warning: Message directory did not exist, created: {}", state.message_dir.display());
    }

    let (tx, mut rx) = tokio::sync::mpsc::channel::<notify::Result<Event>>(100);

    let mut watcher = RecommendedWatcher::new(
        move |res| {
            let _ = tx.blocking_send(res);
        },
        Config::default(),
    )?;

    watcher.watch(&state.message_dir, RecursiveMode::Recursive)?;

    let state_clone = state.clone();
    tokio::spawn(async move {
        while let Some(res) = rx.recv().await {
            match res {
                Ok(event) => {
                    if let EventKind::Create(_) | EventKind::Modify(_) = event.kind {
                        for path in event.paths {
                            if path.is_file() {
                                if let Err(e) = state_clone.process_message_file(&path).await {
                                    eprintln!("Error processing {}: {}", path.display(), e);
                                }
                            }
                        }
                    }
                }
                Err(e) => eprintln!("Watch error: {:?}", e),
            }
        }
    });

    // Keep the program running
    loop {
        sleep(Duration::from_secs(1)).await;
    }
}