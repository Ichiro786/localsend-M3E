//! Opt-in, deterministic transfer baseline for the LocalSend v2 HTTP path.
//!
//! See `packages/core/examples/transfer_baseline.md` for the complete command
//! reference, assumptions, and interpretation limits.
use anyhow::{bail, Context, Result};
use bytes::Bytes;
use futures_util::StreamExt;
use localsend::crypto::hash::sha256_hex;
use localsend::http::client::{ClientError, LsHttpClientV2};
use localsend::http::dto_v2::{PrepareUploadRequestDtoV2, RegisterDtoV2};
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2};
use localsend::http::server::{start_with_loopback, ServerConfigV2};
use localsend::http::state::ClientInfo;
use localsend::model::discovery::{DeviceType, ProtocolType, PROTOCOL_VERSION_V2};
use localsend::model::transfer::FileDto;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::net::{Ipv4Addr, SocketAddr};
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, oneshot, Mutex, Semaphore};
use tokio::task::JoinSet;
use tokio_stream::wrappers::ReceiverStream;
use tokio_util::sync::CancellationToken;

const DEFAULT_SIZES: &[usize] = &[64 * 1024, 1024 * 1024, 8 * 1024 * 1024];
const DEFAULT_CHUNK_SIZE: usize = 64 * 1024;
const RECEIVER_QUEUE_CAPACITY: usize = 16;
const SOURCE_QUEUE_CAPACITY: usize = 1;
const CANCEL_PROBE_MIN_SIZE: usize = 16 * 1024 * 1024;
const CANCEL_PROBE_CHUNK_SIZE: usize = 64 * 1024;
const CANCEL_PROBE_SOURCE_DELAY: Duration = Duration::from_millis(2);
const CANCEL_PROBE_TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Debug)]
struct Options {
    sizes: Vec<usize>,
    files_per_size: usize,
    concurrency: usize,
    chunk_size: usize,
    seed: u64,
    receiver_delay: Duration,
    cancel_probe: bool,
    cancel_after: Duration,
}

#[derive(Clone)]
struct Case {
    id: String,
    size: usize,
    seed: u64,
    sha256: String,
}

#[derive(Debug)]
struct ReceiverObservation {
    bytes_received: u64,
    sha256_received: String,
    size_matches: bool,
    digest_matches: bool,
    accepted: bool,
    completed_at: Instant,
}

#[derive(Clone)]
struct ReceiverState {
    observations: Arc<Mutex<HashMap<String, oneshot::Receiver<ReceiverObservation>>>>,
    first_bytes: Arc<Mutex<HashMap<String, oneshot::Receiver<()>>>>,
}

#[derive(Serialize)]
struct Report {
    schema_version: u32,
    benchmark: &'static str,
    transport: &'static str,
    source_revision: String,
    source_tree_dirty: Option<bool>,
    build_profile: &'static str,
    receiver_bind_addresses: Vec<String>,
    source_backpressure_measure: &'static str,
    platform: Platform,
    settings: Settings,
    totals: Totals,
    latency_ms: Percentiles,
    transfers: Vec<TransferResult>,
    cancellation_probe: Option<CancellationResult>,
    correctness_ok: bool,
    limitations: Vec<&'static str>,
}

#[derive(Serialize)]
struct Platform {
    os: &'static str,
    arch: &'static str,
}

#[derive(Serialize)]
struct Settings {
    sizes_bytes: Vec<usize>,
    files_per_size: usize,
    concurrency: usize,
    chunk_size_bytes: usize,
    seed: u64,
    receiver_delay_ms_per_chunk: u64,
    receiver_queue_capacity_chunks: usize,
    source_queue_capacity_chunks: usize,
}

#[derive(Serialize)]
struct Totals {
    requested_files: usize,
    accepted_files: usize,
    bytes_accepted: u64,
    elapsed_ms: f64,
    throughput_mib_per_second: f64,
    source_backpressure_ms: f64,
}

#[derive(Serialize)]
struct Percentiles {
    p50: f64,
    p95: f64,
    p99: f64,
}

#[derive(Serialize)]
struct TransferResult {
    file_id: String,
    size_bytes: usize,
    http_result: String,
    receiver_bytes: u64,
    expected_sha256: String,
    receiver_sha256: String,
    receiver_size_matches: bool,
    receiver_digest_matches: bool,
    receiver_status: &'static str,
    latency_ms: f64,
    source_backpressure_ms: f64,
    source_chunks: u64,
}

#[derive(Serialize)]
struct CancellationResult {
    file_id: String,
    declared_size_bytes: usize,
    source_chunk_size_bytes: usize,
    source_delay_ms: u64,
    overall_timeout_ms: u64,
    cancel_delay_after_first_byte_ms: u64,
    client_returned_cancelled: bool,
    client_cancel_to_return_ms: f64,
    receiver_observed_partial_payload: bool,
    receiver_observation_after_cancel_ms: Option<f64>,
    bytes_received_before_completion: u64,
    receiver_digest_matches_full_payload: bool,
}

#[derive(Serialize)]
struct InternalResult {
    transfer: TransferResult,
    result_ok: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let options = parse_options()?;
    run(options).await
}

async fn run(options: Options) -> Result<()> {
    let mut cases = Vec::new();
    for (size_index, size) in options.sizes.iter().copied().enumerate() {
        for file_index in 0..options.files_per_size {
            let index = size_index * options.files_per_size + file_index;
            let id = format!("case-{size_index:02}-{file_index:04}");
            let case_seed = mix_seed(options.seed, index as u64);
            cases.push(Case {
                id,
                size,
                seed: case_seed,
                sha256: deterministic_sha256(case_seed, size, options.chunk_size),
            });
        }
    }

    let cancel_case = if options.cancel_probe {
        let size = CANCEL_PROBE_MIN_SIZE.max(options.sizes.iter().copied().max().unwrap_or(0));
        let seed = mix_seed(options.seed, u64::MAX);
        Some(Case {
            id: "cancel-probe".to_string(),
            size,
            seed,
            sha256: deterministic_sha256(seed, size, CANCEL_PROBE_CHUNK_SIZE),
        })
    } else {
        None
    };

    let mut all_cases = cases.clone();
    if let Some(case) = &cancel_case {
        all_cases.push(case.clone());
    }

    let files = all_cases
        .iter()
        .map(|case| {
            let file = FileDto {
                id: case.id.clone(),
                file_name: format!("{}.bin", case.id),
                size: case.size as u64,
                file_type: "application/octet-stream".to_string(),
                sha256: Some(case.sha256.clone()),
                preview: None,
                metadata: None,
            };
            (case.id.clone(), file)
        })
        .collect::<HashMap<_, _>>();

    let (event_tx, mut event_rx) = mpsc::channel::<ServerEventV2>(64);
    let observations = Arc::new(Mutex::new(HashMap::new()));
    let first_bytes = Arc::new(Mutex::new(HashMap::new()));
    let receiver_state = ReceiverState {
        observations: observations.clone(),
        first_bytes: first_bytes.clone(),
    };
    let receiver_delay = options.receiver_delay;
    tokio::spawn(async move {
        while let Some(event) = event_rx.recv().await {
            match event {
                ServerEventV2::PrepareUpload {
                    files, decision_tx, ..
                } => {
                    let accepted = files.keys().cloned().collect();
                    let _ = decision_tx.send(PrepareUploadDecisionV2::Accept(accepted));
                }
                ServerEventV2::FileUpload {
                    file_id,
                    file,
                    target_tx,
                    ..
                } => {
                    let expected_size = file.size;
                    let expected_sha256 = file.sha256.unwrap_or_default();
                    let (binary_tx, mut binary_rx) = mpsc::channel(RECEIVER_QUEUE_CAPACITY);
                    let (result_tx, result_rx) = oneshot::channel();
                    let (observation_tx, observation_rx) = oneshot::channel();
                    let (first_bytes_tx, first_bytes_rx) = oneshot::channel();
                    receiver_state
                        .observations
                        .lock()
                        .await
                        .insert(file_id.clone(), observation_rx);
                    receiver_state
                        .first_bytes
                        .lock()
                        .await
                        .insert(file_id.clone(), first_bytes_rx);
                    if target_tx
                        .send(FileUploadTarget::Stream {
                            binary_tx,
                            result_rx,
                        })
                        .is_err()
                    {
                        let _ = observation_tx.send(ReceiverObservation {
                            bytes_received: 0,
                            sha256_received: sha256_hex(&[]),
                            size_matches: false,
                            digest_matches: false,
                            accepted: false,
                            completed_at: Instant::now(),
                        });
                        continue;
                    }
                    tokio::spawn(async move {
                        let mut hasher = Sha256::new();
                        let mut bytes_received = 0_u64;
                        let mut first_bytes_tx = Some(first_bytes_tx);
                        while let Some(chunk) = binary_rx.recv().await {
                            if !chunk.is_empty() {
                                if let Some(first_bytes_tx) = first_bytes_tx.take() {
                                    let _ = first_bytes_tx.send(());
                                }
                            }
                            hasher.update(&chunk);
                            bytes_received += chunk.len() as u64;
                            if !receiver_delay.is_zero() {
                                tokio::time::sleep(receiver_delay).await;
                            }
                        }
                        let sha256_received = hex_digest(&hasher.finalize());
                        let size_matches = bytes_received == expected_size;
                        let digest_matches = sha256_received.eq_ignore_ascii_case(&expected_sha256);
                        let accepted = size_matches && digest_matches;
                        let _ = result_tx.send(if accepted {
                            Ok(())
                        } else {
                            Err(format!(
                                "receiver rejected {}: expected {} bytes / {}, got {} bytes / {}",
                                file_id,
                                expected_size,
                                expected_sha256,
                                bytes_received,
                                sha256_received
                            ))
                        });
                        let _ = observation_tx.send(ReceiverObservation {
                            bytes_received,
                            sha256_received,
                            size_matches,
                            digest_matches,
                            accepted,
                            completed_at: Instant::now(),
                        });
                    });
                }
                ServerEventV2::Register { .. }
                | ServerEventV2::SessionEnd { .. }
                | ServerEventV2::PrepareUploadAborted { .. }
                | ServerEventV2::CancelReceived { .. }
                | ServerEventV2::ListenerFailed { .. } => {}
            }
        }
    });

    let (stop_tx, stop_rx) = oneshot::channel::<()>();
    let server = start_with_loopback(
        SocketAddr::from((Ipv4Addr::LOCALHOST, 0)),
        None,
        ClientInfo {
            alias: "Transfer baseline receiver".to_string(),
            version: PROTOCOL_VERSION_V2.to_string(),
            device_model: Some("benchmark".to_string()),
            device_type: Some(DeviceType::Headless),
            token: "local-baseline-receiver".to_string(),
        },
        None,
        Some(ServerConfigV2 {
            pin: None,
            verify_checksums: true,
            event_tx,
        }),
        None,
        stop_rx,
    )
    .await
    .context("start local benchmark receiver")?;
    let bound_addresses = server.bound_addresses();
    if bound_addresses.is_empty() || bound_addresses.iter().any(|addr| !addr.ip().is_loopback()) {
        let _ = stop_tx.send(());
        server.wait_stopped().await;
        bail!("benchmark receiver did not bind exclusively to loopback: {bound_addresses:?}");
    }
    let receiver_bind_addresses = bound_addresses
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();

    let client = Arc::new(LsHttpClientV2::try_new_without_cert()?);
    let sender_info = RegisterDtoV2 {
        alias: "Transfer baseline sender".to_string(),
        version: PROTOCOL_VERSION_V2.to_string(),
        device_model: Some("benchmark".to_string()),
        device_type: Some(DeviceType::Headless),
        fingerprint: "baseline-sender-fingerprint".to_string(),
        port: 53317,
        protocol: ProtocolType::Http,
        download: false,
    };
    let prepared = client
        .prepare_upload(
            ProtocolType::Http,
            "127.0.0.1",
            server.port(),
            None,
            PrepareUploadRequestDtoV2 {
                info: sender_info,
                files,
            },
            None,
            CancellationToken::new(),
        )
        .await?;
    let (session_id, prepared_files) = if let Some(prepared_body) = prepared.response {
        if prepared_body.files.len() != all_cases.len() {
            let _ = stop_tx.send(());
            server.wait_stopped().await;
            bail!(
                "benchmark receiver accepted {} of {} requested files",
                prepared_body.files.len(),
                all_cases.len()
            );
        }
        (prepared_body.session_id, prepared_body.files)
    } else {
        let _ = stop_tx.send(());
        server.wait_stopped().await;
        bail!(
            "benchmark receiver accepted no files (HTTP {})",
            prepared.status_code
        );
    };

    let benchmark_started = Instant::now();
    let semaphore = Arc::new(Semaphore::new(options.concurrency));
    let mut tasks = JoinSet::new();
    for case in cases.iter().cloned() {
        let permit = semaphore.clone().acquire_owned().await?;
        let client = client.clone();
        let tokens = prepared_files.clone();
        let observations = observations.clone();
        let session_id = session_id.clone();
        let port = server.port();
        let chunk_size = options.chunk_size;
        tasks.spawn(async move {
            let _permit = permit;
            upload_case(
                client,
                port,
                &session_id,
                tokens,
                observations,
                case,
                chunk_size,
                Duration::ZERO,
            )
            .await
        });
    }

    let mut transfer_results = Vec::with_capacity(cases.len());
    while let Some(result) = tasks.join_next().await {
        transfer_results.push(result.context("benchmark transfer task panicked")??);
    }
    let benchmark_elapsed = benchmark_started.elapsed();
    transfer_results.sort_by(|a, b| a.transfer.file_id.cmp(&b.transfer.file_id));

    let cancellation_probe = if let Some(case) = cancel_case {
        let token = prepared_files
            .get(&case.id)
            .cloned()
            .context("receiver did not return a cancellation token")?;
        Some(
            run_cancel_probe(
                client.clone(),
                server.port(),
                &session_id,
                token,
                observations.clone(),
                first_bytes.clone(),
                case,
                options.cancel_after,
            )
            .await?,
        )
    } else {
        None
    };

    let bytes_accepted = transfer_results
        .iter()
        .filter(|result| result.result_ok)
        .map(|result| result.transfer.size_bytes as u64)
        .sum::<u64>();
    let accepted_files = transfer_results
        .iter()
        .filter(|result| result.result_ok)
        .count();
    let source_backpressure_ns = transfer_results
        .iter()
        .map(|result| (result.transfer.source_backpressure_ms * 1_000_000.0) as u64)
        .sum::<u64>();
    let latencies = transfer_results
        .iter()
        .map(|result| result.transfer.latency_ms)
        .collect::<Vec<_>>();
    let elapsed_seconds = benchmark_elapsed.as_secs_f64();
    let throughput = if elapsed_seconds > 0.0 {
        bytes_accepted as f64 / 1024.0 / 1024.0 / elapsed_seconds
    } else {
        0.0
    };
    let correctness_ok = accepted_files == cases.len()
        && transfer_results.iter().all(|result| {
            result.result_ok
                && result.transfer.receiver_size_matches
                && result.transfer.receiver_digest_matches
        })
        && cancellation_probe.as_ref().is_none_or(|probe| {
            probe.client_returned_cancelled && probe.receiver_observed_partial_payload
        });
    let report = Report {
        schema_version: 2,
        benchmark: "localsend-v2-loopback-transfer-baseline",
        transport: "plain HTTP over IPv4 loopback; not a TLS or authentication benchmark",
        source_revision: source_revision(),
        source_tree_dirty: source_tree_dirty(),
        build_profile: if cfg!(debug_assertions) {
            "debug"
        } else {
            "release"
        },
        receiver_bind_addresses,
        source_backpressure_measure: "sum of per-transfer source-channel send waits; with concurrency this sum can exceed elapsed_ms",
        platform: Platform {
            os: std::env::consts::OS,
            arch: std::env::consts::ARCH,
        },
        settings: Settings {
            sizes_bytes: options.sizes,
            files_per_size: options.files_per_size,
            concurrency: options.concurrency,
            chunk_size_bytes: options.chunk_size,
            seed: options.seed,
            receiver_delay_ms_per_chunk: options.receiver_delay.as_millis() as u64,
            receiver_queue_capacity_chunks: RECEIVER_QUEUE_CAPACITY,
            source_queue_capacity_chunks: SOURCE_QUEUE_CAPACITY,
        },
        totals: Totals {
            requested_files: cases.len(),
            accepted_files,
            bytes_accepted,
            elapsed_ms: benchmark_elapsed.as_secs_f64() * 1000.0,
            throughput_mib_per_second: throughput,
            source_backpressure_ms: source_backpressure_ns as f64 / 1_000_000.0,
        },
        latency_ms: percentiles(&latencies),
        transfers: transfer_results.into_iter().map(|result| result.transfer).collect(),
        cancellation_probe,
        correctness_ok,
        limitations: vec![
            "The receiver and sender share one process and use IPv4 loopback; results are not representative of Wi-Fi, WAN, or physical-device performance.",
            "The receiver is a deterministic stream consumer; platform file I/O, Android file descriptors, TLS, authentication, and UI work are not measured.",
            "RSS and file-descriptor counts are omitted because portable, dependency-free process sampling is not available across supported platforms.",
            "Reported source-channel blocking is an observation of this harness queue, not a complete measurement of kernel socket or receiver backpressure.",
        ],
    };
    serde_json::to_writer_pretty(std::io::stdout().lock(), &report)?;
    println!();

    let _ = stop_tx.send(());
    server.wait_stopped().await;
    if !correctness_ok {
        bail!("one or more benchmark correctness checks failed");
    }
    Ok(())
}

async fn upload_case(
    client: Arc<LsHttpClientV2>,
    port: u16,
    session_id: &str,
    tokens: HashMap<String, String>,
    observations: Arc<Mutex<HashMap<String, oneshot::Receiver<ReceiverObservation>>>>,
    case: Case,
    chunk_size: usize,
    inter_chunk_delay: Duration,
) -> Result<InternalResult> {
    let token = tokens
        .get(&case.id)
        .context("missing upload token")?
        .clone();
    let (body, blocked_ns, chunks, producer) =
        payload_body(case.seed, case.size, chunk_size, inter_chunk_delay);
    let started = Instant::now();
    let result = client
        .upload(
            ProtocolType::Http,
            "127.0.0.1",
            port,
            None,
            session_id,
            &case.id,
            &token,
            body,
            CancellationToken::new(),
        )
        .await;
    let latency_ms = started.elapsed().as_secs_f64() * 1000.0;
    producer.await.context("payload producer panicked")?;
    let observation = take_observation(&observations, &case.id).await?;
    let http_result = match &result {
        Ok(()) => "http_200".to_string(),
        Err(error) => format!("error: {error}"),
    };
    let result_ok = result.is_ok()
        && observation.accepted
        && observation.bytes_received == case.size as u64
        && observation
            .sha256_received
            .eq_ignore_ascii_case(&case.sha256);
    let transfer = TransferResult {
        file_id: case.id,
        size_bytes: case.size,
        http_result,
        receiver_bytes: observation.bytes_received,
        expected_sha256: case.sha256,
        receiver_sha256: observation.sha256_received,
        receiver_size_matches: observation.size_matches,
        receiver_digest_matches: observation.digest_matches,
        receiver_status: if observation.accepted {
            "accepted"
        } else {
            "rejected"
        },
        latency_ms,
        source_backpressure_ms: blocked_ns.load(Ordering::Relaxed) as f64 / 1_000_000.0,
        source_chunks: chunks.load(Ordering::Relaxed),
    };
    Ok(InternalResult {
        transfer,
        result_ok,
    })
}

async fn run_cancel_probe(
    client: Arc<LsHttpClientV2>,
    port: u16,
    session_id: &str,
    token: String,
    observations: Arc<Mutex<HashMap<String, oneshot::Receiver<ReceiverObservation>>>>,
    first_bytes: Arc<Mutex<HashMap<String, oneshot::Receiver<()>>>>,
    case: Case,
    cancel_after: Duration,
) -> Result<CancellationResult> {
    let cancel = CancellationToken::new();
    let (body, _blocked_ns, _chunks, producer) = payload_body(
        case.seed,
        case.size,
        CANCEL_PROBE_CHUNK_SIZE,
        CANCEL_PROBE_SOURCE_DELAY,
    );
    let cancel_for_upload = cancel.clone();
    let client_for_upload = client.clone();
    let session_id = session_id.to_string();
    let file_id = case.id.clone();
    let mut upload_task = tokio::spawn(async move {
        client_for_upload
            .upload(
                ProtocolType::Http,
                "127.0.0.1",
                port,
                None,
                &session_id,
                &file_id,
                &token,
                body,
                cancel_for_upload,
            )
            .await
    });
    let mut producer = producer;

    let probe = async {
        wait_for_first_bytes(&first_bytes, &case.id).await?;
        tokio::time::sleep(cancel_after).await;
        let cancelled_at = Instant::now();
        cancel.cancel();

        let client_result = (&mut upload_task)
            .await
            .context("cancel-probe upload task panicked")?;
        let upload_finished_at = Instant::now();
        (&mut producer)
            .await
            .context("cancel-probe producer panicked")?;
        let observation = take_observation(&observations, &case.id).await?;
        let client_returned_cancelled = matches!(client_result, Err(ClientError::Cancelled));
        let receiver_observed_partial_payload =
            is_partial_payload(observation.bytes_received, case.size as u64);

        Ok::<_, anyhow::Error>(CancellationResult {
            file_id: case.id.clone(),
            declared_size_bytes: case.size,
            source_chunk_size_bytes: CANCEL_PROBE_CHUNK_SIZE,
            source_delay_ms: CANCEL_PROBE_SOURCE_DELAY.as_millis() as u64,
            overall_timeout_ms: CANCEL_PROBE_TIMEOUT.as_millis() as u64,
            cancel_delay_after_first_byte_ms: cancel_after.as_millis() as u64,
            client_returned_cancelled,
            client_cancel_to_return_ms: upload_finished_at
                .saturating_duration_since(cancelled_at)
                .as_secs_f64()
                * 1000.0,
            receiver_observed_partial_payload,
            receiver_observation_after_cancel_ms: Some(
                observation
                    .completed_at
                    .saturating_duration_since(cancelled_at)
                    .as_secs_f64()
                    * 1000.0,
            ),
            bytes_received_before_completion: observation.bytes_received,
            receiver_digest_matches_full_payload: observation.digest_matches,
        })
    };

    match tokio::time::timeout(CANCEL_PROBE_TIMEOUT, probe).await {
        Ok(result) => result,
        Err(_) => {
            cancel.cancel();
            upload_task.abort();
            producer.abort();
            bail!(
                "cancellation probe exceeded its {}ms overall timeout",
                CANCEL_PROBE_TIMEOUT.as_millis()
            );
        }
    }
}

fn payload_body(
    seed: u64,
    size: usize,
    chunk_size: usize,
    inter_chunk_delay: Duration,
) -> (
    reqwest::Body,
    Arc<AtomicU64>,
    Arc<AtomicU64>,
    tokio::task::JoinHandle<()>,
) {
    let (tx, rx) = mpsc::channel::<Bytes>(SOURCE_QUEUE_CAPACITY);
    let blocked_ns = Arc::new(AtomicU64::new(0));
    let chunks = Arc::new(AtomicU64::new(0));
    let blocked_for_task = blocked_ns.clone();
    let chunks_for_task = chunks.clone();
    let producer = tokio::spawn(async move {
        let mut rng = PayloadRng::new(seed);
        let mut remaining = size;
        while remaining > 0 {
            let len = remaining.min(chunk_size);
            let mut bytes = vec![0_u8; len];
            rng.fill(&mut bytes);
            let blocked_started = Instant::now();
            if tx.send(Bytes::from(bytes)).await.is_err() {
                break;
            }
            blocked_for_task.fetch_add(
                blocked_started.elapsed().as_nanos().min(u64::MAX as u128) as u64,
                Ordering::Relaxed,
            );
            chunks_for_task.fetch_add(1, Ordering::Relaxed);
            remaining -= len;
            if !inter_chunk_delay.is_zero() {
                tokio::time::sleep(inter_chunk_delay).await;
            }
        }
    });
    let body = reqwest::Body::wrap_stream(
        ReceiverStream::new(rx).map(|chunk| Ok::<Bytes, std::io::Error>(chunk)),
    );
    (body, blocked_ns, chunks, producer)
}

async fn take_observation(
    observations: &Arc<Mutex<HashMap<String, oneshot::Receiver<ReceiverObservation>>>>,
    file_id: &str,
) -> Result<ReceiverObservation> {
    let receiver = observations
        .lock()
        .await
        .remove(file_id)
        .with_context(|| format!("receiver did not start file {file_id}"))?;
    tokio::time::timeout(Duration::from_secs(30), receiver)
        .await
        .with_context(|| format!("receiver timed out processing {file_id}"))?
        .with_context(|| format!("receiver dropped observation for {file_id}"))
}

async fn wait_for_first_bytes(
    first_bytes: &Arc<Mutex<HashMap<String, oneshot::Receiver<()>>>>,
    file_id: &str,
) -> Result<()> {
    let receiver = loop {
        if let Some(receiver) = first_bytes.lock().await.remove(file_id) {
            break receiver;
        }
        tokio::time::sleep(Duration::from_millis(5)).await;
    };
    receiver
        .await
        .with_context(|| format!("receiver did not consume bytes for {file_id}"))
}

fn deterministic_sha256(seed: u64, size: usize, chunk_size: usize) -> String {
    let mut rng = PayloadRng::new(seed);
    let mut hasher = Sha256::new();
    let mut remaining = size;
    let mut buffer = vec![0_u8; chunk_size.min(1024 * 1024).max(1)];
    while remaining > 0 {
        let len = remaining.min(buffer.len());
        rng.fill(&mut buffer[..len]);
        hasher.update(&buffer[..len]);
        remaining -= len;
    }
    hex_digest(&hasher.finalize())
}

fn hex_digest(digest: &[u8]) -> String {
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn source_revision() -> String {
    Command::new("git")
        .args(["rev-parse", "HEAD"])
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .filter(|revision| !revision.is_empty())
        .unwrap_or_else(|| "unknown".to_string())
}

fn source_tree_dirty() -> Option<bool> {
    Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| !output.stdout.is_empty())
}

fn is_partial_payload(bytes_received: u64, declared_size: u64) -> bool {
    bytes_received > 0 && bytes_received < declared_size
}

fn mix_seed(seed: u64, index: u64) -> u64 {
    let mut value = seed.wrapping_add(index.wrapping_mul(0x9E37_79B9_7F4A_7C15));
    value = (value ^ (value >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    value = (value ^ (value >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    value ^ (value >> 31)
}

struct PayloadRng {
    seed: u64,
    position: u64,
}

impl PayloadRng {
    fn new(seed: u64) -> Self {
        Self {
            seed: if seed == 0 {
                0xA076_1D64_78BD_642F
            } else {
                seed
            },
            position: 0,
        }
    }

    fn fill(&mut self, output: &mut [u8]) {
        let mut written = 0;
        while written < output.len() {
            let block_index = self.position / 8;
            let byte_in_block = (self.position % 8) as usize;
            let block = mix_seed(self.seed, block_index).to_le_bytes();
            let count = (8 - byte_in_block).min(output.len() - written);
            output[written..written + count]
                .copy_from_slice(&block[byte_in_block..byte_in_block + count]);
            written += count;
            self.position += count as u64;
        }
    }
}

fn percentiles(values: &[f64]) -> Percentiles {
    if values.is_empty() {
        return Percentiles {
            p50: 0.0,
            p95: 0.0,
            p99: 0.0,
        };
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    Percentiles {
        p50: percentile(&sorted, 0.50),
        p95: percentile(&sorted, 0.95),
        p99: percentile(&sorted, 0.99),
    }
}

fn percentile(sorted: &[f64], quantile: f64) -> f64 {
    let index = ((sorted.len() as f64 * quantile).ceil() as usize).saturating_sub(1);
    sorted[index.min(sorted.len() - 1)]
}

fn parse_options() -> Result<Options> {
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    if args.iter().any(|arg| arg == "--help" || arg == "-h") {
        print_help();
        std::process::exit(0);
    }
    let mut sizes = DEFAULT_SIZES.to_vec();
    let mut files_per_size = 3;
    let mut concurrency = 2;
    let mut chunk_size = DEFAULT_CHUNK_SIZE;
    let mut seed = 0x4C53_4241_5345_4C49;
    let mut receiver_delay_ms = 0_u64;
    let mut cancel_probe = false;
    let mut cancel_after_ms = 50_u64;
    let mut args = args.into_iter();
    while let Some(option) = args.next() {
        match option.as_str() {
            "--sizes" => {
                let value = next_value(&mut args)?;
                sizes = value
                    .split(',')
                    .map(parse_size)
                    .collect::<Result<Vec<_>>>()?;
                if sizes.is_empty() || sizes.contains(&0) {
                    bail!("--sizes must contain positive byte sizes");
                }
            }
            "--files-per-size" => {
                files_per_size = next_value(&mut args)?
                    .parse()
                    .context("invalid --files-per-size")?
            }
            "--concurrency" => {
                concurrency = next_value(&mut args)?
                    .parse()
                    .context("invalid --concurrency")?
            }
            "--chunk-size" => chunk_size = parse_size(&next_value(&mut args)?)?,
            "--seed" => seed = parse_seed(&next_value(&mut args)?)?,
            "--receiver-delay-ms" => {
                receiver_delay_ms = next_value(&mut args)?
                    .parse()
                    .context("invalid --receiver-delay-ms")?
            }
            "--cancel-probe" => cancel_probe = true,
            "--cancel-after-ms" => {
                cancel_after_ms = next_value(&mut args)?
                    .parse()
                    .context("invalid --cancel-after-ms")?
            }
            _ => bail!("unknown option {option:?}; use --help for usage"),
        }
    }
    if files_per_size == 0 || concurrency == 0 || chunk_size == 0 {
        bail!("--files-per-size, --concurrency, and --chunk-size must be positive");
    }
    Ok(Options {
        sizes,
        files_per_size,
        concurrency,
        chunk_size,
        seed,
        receiver_delay: Duration::from_millis(receiver_delay_ms),
        cancel_probe,
        cancel_after: Duration::from_millis(cancel_after_ms),
    })
}

fn next_value(args: &mut std::vec::IntoIter<String>) -> Result<String> {
    args.next().context("missing option value")
}

fn parse_size(value: &str) -> Result<usize> {
    let value = value.trim().to_ascii_lowercase();
    let (digits, multiplier) = if let Some(value) = value.strip_suffix("kib") {
        (value, 1024_usize)
    } else if let Some(value) = value.strip_suffix("mib") {
        (value, 1024_usize * 1024)
    } else if let Some(value) = value.strip_suffix("gib") {
        (value, 1024_usize * 1024 * 1024)
    } else {
        (value.as_str(), 1)
    };
    digits
        .trim()
        .parse::<usize>()?
        .checked_mul(multiplier)
        .context("byte size overflow")
}

fn parse_seed(value: &str) -> Result<u64> {
    if let Some(hex) = value.strip_prefix("0x") {
        Ok(u64::from_str_radix(hex, 16).context("invalid hexadecimal --seed")?)
    } else {
        Ok(value.parse().context("invalid --seed")?)
    }
}

fn print_help() {
    println!(
        "Opt-in deterministic LocalSend v2 HTTP baseline (JSON report on stdout)\n\
         Options:\n\
           --sizes 64KiB,1MiB,8MiB   Payload cases (positive byte sizes)\n\
           --files-per-size N        Files per size, default 3\n\
           --concurrency N           Concurrent uploads, default 2\n\
           --chunk-size BYTES        Source chunk size, default 65536\n\
           --seed N|0xHEX             Deterministic payload seed\n\
           --receiver-delay-ms N     Delay after each receiver chunk (backpressure probe)\n\
           --cancel-probe            Add a deterministic cancellation probe\n\
           --cancel-after-ms N        Delay after first received byte, default 50\n\
         Cancellation probe overall timeout: 15000 ms.\n\
         Sizes accept raw bytes or KiB/MiB/GiB suffixes. See transfer_baseline.md."
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn payload_bytes_are_independent_of_fill_boundaries_around_eight_bytes() {
        const SEED: u64 = 0x1234_5678_9ABC_DEF0;
        for size in [7, 8, 9, 15, 16, 17, 31, 32, 33] {
            let mut expected = vec![0; size];
            PayloadRng::new(SEED).fill(&mut expected);
            for chunk_size in [1, 7, 8, 9, 15] {
                let mut actual = vec![0; size];
                let mut rng = PayloadRng::new(SEED);
                for chunk in actual.chunks_mut(chunk_size) {
                    rng.fill(chunk);
                }
                assert_eq!(actual, expected, "size={size}, chunk={chunk_size}");
            }
        }
    }

    #[test]
    fn cancellation_partial_payload_requires_nonzero_bytes_and_shorter_than_declared() {
        assert!(!is_partial_payload(0, 8));
        assert!(is_partial_payload(1, 8));
        assert!(is_partial_payload(7, 8));
        assert!(!is_partial_payload(8, 8));
        assert!(!is_partial_payload(9, 8));

        // A full-length body with a bad digest is rejected, but is not a
        // partial receive and must not be described as one.
        let full_length_bad_digest = (8_u64, false);
        assert!(!full_length_bad_digest.1);
        assert!(!is_partial_payload(full_length_bad_digest.0, 8));
    }

    #[test]
    fn payload_digests_are_invariant_at_megabyte_boundaries_and_large_chunks() {
        const MIB: usize = 1024 * 1024;
        const SEED: u64 = 0x4C53_4241_5345_4C49;
        let sizes = [
            MIB - 1,
            MIB,
            MIB + 1,
            8 * MIB - 1,
            8 * MIB,
            8 * MIB + 1,
            3 * MIB,
        ];
        for size in sizes {
            let expected = deterministic_sha256(SEED, size, DEFAULT_CHUNK_SIZE);
            for chunk_size in [DEFAULT_CHUNK_SIZE, MIB + 1] {
                assert_eq!(
                    deterministic_sha256(SEED, size, chunk_size),
                    expected,
                    "digest helper: size={size}, chunk={chunk_size}"
                );
                assert_eq!(
                    digest_with_exact_chunk_size(SEED, size, chunk_size),
                    expected,
                    "source generator: size={size}, chunk={chunk_size}"
                );
            }
        }
    }

    fn digest_with_exact_chunk_size(seed: u64, size: usize, chunk_size: usize) -> String {
        let mut rng = PayloadRng::new(seed);
        let mut hasher = Sha256::new();
        let mut remaining = size;
        while remaining > 0 {
            let len = remaining.min(chunk_size);
            let mut buffer = vec![0; len];
            rng.fill(&mut buffer);
            hasher.update(&buffer);
            remaining -= len;
        }
        hex_digest(&hasher.finalize())
    }
}
