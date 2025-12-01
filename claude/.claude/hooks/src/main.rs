use anyhow::{Context, Result};
use clap::Parser;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tokio::time::sleep;

#[derive(Parser)]
#[command(name = "claude-zulip-sync")]
#[command(about = "Sync Claude Code conversations to Zulip in real-time")]
struct Args {
    /// Claude transcript directory
    #[arg(long, default_value = "~/.claude/projects")]
    transcript_dir: PathBuf,
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
            stream: env::var("ZULIP_STREAM_CLAUDE_CODE")
                .unwrap_or_else(|_| "claude-code".to_string()),
        })
    }
}

#[derive(Clone)]
struct Message {
    role: String,
    content: String,
    session_id: String,
}

struct SyncState {
    sent_hashes: Arc<RwLock<HashSet<String>>>,
    last_counts: Arc<RwLock<HashMap<String, usize>>>,
    config: ZulipConfig,
    transcript_dir: PathBuf,
}

impl SyncState {
    fn new(config: ZulipConfig, transcript_dir: PathBuf) -> Self {
        Self {
            sent_hashes: Arc::new(RwLock::new(HashSet::new())),
            last_counts: Arc::new(RwLock::new(HashMap::new())),
            config,
            transcript_dir,
        }
    }

    fn format_content_block(block: &Value) -> Option<String> {
        let block_type = block.get("type").and_then(|v| v.as_str()).unwrap_or("");

        match block_type {
            "text" => block.get("text").and_then(|v| v.as_str()).map(|s| s.to_string()),
            
            "tool_use" => {
                let tool_name = block.get("name").and_then(|v| v.as_str()).unwrap_or("unknown");
                let tool_input = block.get("input").unwrap_or(&Value::Null);
                let formatted_input = serde_json::to_string_pretty(tool_input).unwrap_or_default();
                Some(format!("**Tool: {}**\n```json\n{}```", tool_name, formatted_input))
            }
            
            "tool_result" => {
                let content = block.get("content").unwrap_or(&Value::Null);
                let is_error = block.get("is_error").and_then(|v| v.as_bool()).unwrap_or(false);
                let status = if is_error { "Error" } else { "Result" };
                
                let content_str = if content.is_string() {
                    content.as_str().unwrap_or("").to_string()
                } else if content.is_array() {
                    let text_parts: Vec<String> = content
                        .as_array()
                        .unwrap_or(&vec![])
                        .iter()
                        .filter_map(|item| {
                            if let Some(item_obj) = item.as_object() {
                                if item_obj.get("type").and_then(|v| v.as_str()) == Some("text") {
                                    item_obj.get("text").and_then(|v| v.as_str()).map(|s| s.to_string())
                                } else {
                                    None
                                }
                            } else {
                                item.as_str().map(|s| s.to_string())
                            }
                        })
                        .collect();
                    text_parts.join("\n")
                } else {
                    content.to_string()
                };
                
                Some(format!("**Tool {}**\n```\n{}```", status, content_str))
            }
            
            "thinking" => None, // Skip thinking blocks
            
            _ => Some(block.to_string()),
        }
    }

    async fn send_to_zulip(&self, message: &Message) -> Result<()> {
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
            "**Claude**"
        };

        let mut content = message.content.clone();
        if content.len() > 10000 {
            content.truncate(10000);
            content.push_str("\n\n... (truncated)");
        }

        let formatted_content = format!("{}\n\n{}", prefix, content);
        let short_session = message.session_id.chars().take(8).collect::<String>();

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

        if response.status().as_u16() != 200 {
            let error_text = response.text().await.unwrap_or_default();
            anyhow::bail!("Zulip error: {} {}", response.status(), error_text);
        }

        Ok(())
    }

    async fn parse_transcript(&self, filepath: &Path) -> Result<Vec<Message>> {
        let mut messages = Vec::new();
        
        let content = fs::read_to_string(filepath)?;
        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }

            let msg: Value = match serde_json::from_str(line) {
                Ok(msg) => msg,
                Err(_) => continue, // Skip invalid JSON lines
            };

            let msg_type = msg.get("type").and_then(|v| v.as_str()).unwrap_or("");

            if msg_type == "user" {
                let message_content = msg.get("message").unwrap_or(&Value::Null);
                let content_str = if message_content.is_object() {
                    message_content
                        .get("content")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string()
                } else if message_content.is_array() {
                    let formatted_parts: Vec<String> = message_content
                        .as_array()
                        .unwrap_or(&vec![])
                        .iter()
                        .filter_map(|item| {
                            if let Some(item_obj) = item.as_object() {
                                Self::format_content_block(&Value::Object(item_obj.clone()))
                            } else {
                                Some(item.to_string())
                            }
                        })
                        .collect();
                    formatted_parts.join("\n\n")
                } else {
                    message_content.to_string()
                };

                messages.push(Message {
                    role: "user".to_string(),
                    content: content_str,
                    session_id: filepath.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string(),
                });
            } else if msg_type == "assistant" {
                let content_blocks = msg
                    .get("message")
                    .and_then(|v| v.get("content"))
                    .and_then(|v| v.as_array())
                    .unwrap_or(&vec![]);

                let formatted_parts: Vec<String> = content_blocks
                    .iter()
                    .filter_map(|block| Self::format_content_block(block))
                    .collect();

                if !formatted_parts.is_empty() {
                    messages.push(Message {
                        role: "assistant".to_string(),
                        content: formatted_parts.join("\n\n"),
                        session_id: filepath.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string(),
                    });
                }
            }
        }

        Ok(messages)
    }

    async fn process_transcript_file(&self, filepath: &Path) -> Result<()> {
        if filepath.extension().and_then(|s| s.to_str()) != Some("jsonl") {
            return Ok(());
        }

        let session_id = filepath
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_string();

        // Parse all messages
        let messages = self.parse_transcript(filepath).await?;

        // Get previously seen count
        let last_count = {
            let last_counts = self.last_counts.read().await;
            last_counts.get(&filepath.to_string_lossy().to_string()).copied().unwrap_or(0)
        };

        // Send only new messages
        for message in messages.iter().skip(last_count) {
            if let Err(e) = self.send_to_zulip(message).await {
                eprintln!("Failed to send message: {}", e);
            }
        }

        // Update last count
        {
            let mut last_counts = self.last_counts.write().await;
            last_counts.insert(filepath.to_string_lossy().to_string(), messages.len());
        }

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Expand tilde in path
    let transcript_dir = shellexpand::tilde(&args.transcript_dir.to_string_lossy()).to_string();
    let transcript_dir = PathBuf::from(transcript_dir);

    let config = match ZulipConfig::from_env() {
        Ok(config) => config,
        Err(e) => {
            eprintln!("Error: Missing Zulip configuration. Set these environment variables:");
            eprintln!("  ZULIP_SITE (e.g., https://zulip.example.com)");
            eprintln!("  ZULIP_BOT_EMAIL");
            eprintln!("  ZULIP_BOT_API_KEY");
            eprintln!("  ZULIP_STREAM_CLAUDE_CODE (optional, defaults to 'claude-code')");
            eprintln!("\nError details: {}", e);
            return Ok(());
        }
    };

    let state = SyncState::new(config.clone(), transcript_dir.clone());

    println!("Watching {} for Claude conversations...", state.transcript_dir.display());
    println!("Sending to: {} stream '{}'", config.site, config.stream);
    println!("ZULIP_STREAM_CLAUDE_CODE: {}", config.stream);

    let (tx, mut rx) = tokio::sync::mpsc::channel::<notify::Result<Event>>(100);

    let mut watcher = RecommendedWatcher::new(
        move |res| {
            let _ = tx.blocking_send(res);
        },
        Config::default(),
    )?;

    watcher.watch(&state.transcript_dir, RecursiveMode::Recursive)?;

    let state_clone = state.clone();
    tokio::spawn(async move {
        while let Some(res) = rx.recv().await {
            match res {
                Ok(event) => {
                    if let EventKind::Create(_) | EventKind::Modify(_) = event.kind {
                        for path in event.paths {
                            if path.is_file() {
                                if let Err(e) = state_clone.process_transcript_file(&path).await {
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