use anyhow::{Context, Result};
use clap::Parser;
use log::{debug, error, info, warn};
use std::collections::HashMap;

mod aws_client;
mod env_handler;
pub mod secret_masker;
mod template_parser;

use aws_client::AwsClient;
use env_handler::{EnvHandler, Strategy};
use secret_masker::SecretMasker;
use template_parser::TemplateParser;

#[derive(Parser)]
#[command(name = "psenv")]
#[command(about = "AWS Parameter Store to .env tool")]
#[command(version)]
struct Cli {
    #[arg(short, long)]
    #[arg(help = "Template file path (e.g., .env.example)")]
    template: String,

    #[arg(short, long)]
    #[arg(help = "Parameter Store prefix (must start with /)")]
    prefix: String,

    #[arg(short, long, default_value = ".env")]
    #[arg(help = "Output file (default: .env)")]
    output: String,

    #[arg(short, long, default_value = "update")]
    #[arg(help = "Processing strategy")]
    strategy: Strategy,

    #[arg(short, long)]
    #[arg(help = "Skip these keys (comma-separated)")]
    ignore_keys: Option<String>,

    #[arg(long, default_value = "true")]
    #[arg(help = "All keys must exist, otherwise error")]
    require_all: bool,

    #[arg(short, long)]
    #[arg(help = "AWS region")]
    region: Option<String>,

    #[arg(long)]
    #[arg(help = "AWS profile")]
    profile: Option<String>,

    #[arg(long, default_value = "false")]
    #[arg(help = "Preview mode")]
    dry_run: bool,

    #[arg(short, long, default_value = "false")]
    #[arg(help = "Quiet mode")]
    quiet: bool,

    #[arg(short, long, default_value = "false")]
    #[arg(help = "Verbose logging")]
    verbose: bool,

    #[arg(long, default_value = "false")]
    #[arg(help = "Show secrets in plaintext (default: mask sensitive values)")]
    show_secrets: bool,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    // Initialize logging
    let log_level = if cli.verbose {
        "debug"
    } else if cli.quiet {
        "error"
    } else {
        "info"
    };

    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(log_level)).init();

    if let Err(e) = run(cli).await {
        error!("Error: {}", e);
        let exit_code = match e.downcast_ref::<PsenvError>() {
            Some(PsenvError::InvalidArguments(_)) => 1,
            Some(PsenvError::RequiredParameterMissing(_)) => 3,
            Some(PsenvError::FileExists(_)) => 4,
            _ => 1,
        };
        std::process::exit(exit_code);
    }
}

async fn run(cli: Cli) -> Result<()> {
    // Validate prefix
    if !cli.prefix.starts_with('/') {
        return Err(PsenvError::InvalidArguments("Prefix must start with '/'".to_string()).into());
    }

    debug!("Starting psenv with template: {}, prefix: {}, output: {}",
           cli.template, cli.prefix, cli.output);

    // Parse ignore keys
    let ignore_keys: Vec<String> = cli.ignore_keys
        .as_deref()
        .unwrap_or("")
        .split(',')
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.trim().to_string())
        .collect();

    debug!("Ignore keys: {:?}", ignore_keys);

    // Parse template file
    let parser = TemplateParser::new();
    let keys = parser.parse_template(&cli.template)
        .with_context(|| format!("Failed to parse template file: {}", cli.template))?;

    info!("Found {} keys in template", keys.len());

    // Filter out ignored keys
    let filtered_keys: Vec<String> = keys.into_iter()
        .filter(|key| !ignore_keys.contains(key))
        .collect();

    info!("Processing {} keys after filtering", filtered_keys.len());

    // Initialize AWS client
    let aws_client = AwsClient::new(cli.region.as_deref(), cli.profile.as_deref()).await
        .with_context(|| "Failed to initialize AWS client")?;

    // Fetch parameters from AWS Parameter Store
    let mut values = HashMap::new();
    let mut missing_keys = Vec::new();

    for key in &filtered_keys {
        let param_path = format!("{}{}", cli.prefix, key);
        debug!("Fetching parameter: {}", param_path);

        match aws_client.get_parameter(&param_path).await {
            Ok(Some(value)) => {
                values.insert(key.clone(), value);
                debug!("Retrieved value for key: {}", key);
            }
            Ok(None) => {
                warn!("Parameter not found: {}", param_path);
                missing_keys.push(key.clone());
            }
            Err(e) => {
                error!("Failed to retrieve parameter {}: {}", param_path, e);
                missing_keys.push(key.clone());
            }
        }
    }

    // Check if all required parameters are present
    if cli.require_all && !missing_keys.is_empty() {
        return Err(PsenvError::RequiredParameterMissing(
            format!("Missing required parameters: {}", missing_keys.join(", "))
        ).into());
    }

    info!("Retrieved {} out of {} parameters", values.len(), filtered_keys.len());

    if !missing_keys.is_empty() {
        warn!("Missing parameters: {}", missing_keys.join(", "));
    }

    // Handle .env file generation
    let env_handler = EnvHandler::new();

    if cli.dry_run {
        info!("Dry run mode - would write to: {}", cli.output);
        let masker = SecretMasker::new();
        let mut sorted_keys: Vec<&String> = values.keys().collect();
        sorted_keys.sort();

        for key in sorted_keys {
            if let Some(value) = values.get(key) {
                println!("{}", masker.format_output(key, value, cli.show_secrets));
            }
        }
    } else {
        env_handler.handle_env_file(&cli.output, &values, cli.strategy)
            .with_context(|| format!("Failed to handle .env file: {}", cli.output))?;

        info!("Successfully updated {}", cli.output);
    }

    Ok(())
}

#[derive(Debug, thiserror::Error)]
enum PsenvError {
    #[error("Invalid arguments: {0}")]
    InvalidArguments(String),

    #[error("Required parameter missing: {0}")]
    RequiredParameterMissing(String),

    #[error("File exists: {0}")]
    FileExists(String),
}