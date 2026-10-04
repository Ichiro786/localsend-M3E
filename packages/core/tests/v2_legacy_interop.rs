#![cfg(feature = "http")]

//! Protocol-v2 peers need not send a TLS client certificate. These requests
//! reproduce the legacy client's discovery and upload flow without mTLS.

use bytes::Bytes;
use localsend::crypto::cert::generate_self_signed;
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2};
use localsend::http::server::{start_with_loopback, ServerConfigV2, TlsConfig};
use localsend::http::state::ClientInfo;
use std::net::{Ipv4Addr, SocketAddr};
use std::time::Duration;
use tokio::sync::{mpsc, oneshot};

#[tokio::test]
async fn legacy_https_peer_can_register_and_upload_without_client_certificate() {
    let cert = generate_self_signed().unwrap();
    let (event_tx, mut events) = mpsc::channel(16);
    let (stop_tx, stop_rx) = oneshot::channel();
    let server = start_with_loopback(
        SocketAddr::from((Ipv4Addr::LOCALHOST, 0)),
        Some(TlsConfig { cert: cert.certificate_pem, private_key: cert.private_key_pem }),
        ClientInfo {
            alias: "M3E receiver".into(), version: "2.2".into(),
            device_model: None, device_type: None, token: cert.fingerprint,
        },
        None,
        Some(ServerConfigV2 { pin: None, verify_checksums: true, event_tx }),
        None,
        stop_rx,
    ).await.unwrap();
    let peer = localsend::reqwest::Client::builder()
        .use_rustls_tls().danger_accept_invalid_certs(true).no_proxy()
        .timeout(Duration::from_secs(3)).build().unwrap();
    let base = format!("https://127.0.0.1:{}/api/localsend", server.port());
    let info = serde_json::json!({
        "alias": "Legacy peer", "version": "2.1", "fingerprint": "legacy-fingerprint",
        "port": 53317, "protocol": "https", "download": false
    });
    let response = peer.post(format!("{base}/v2/register")).json(&info).send().await.unwrap();
    assert_eq!(response.status().as_u16(), 200);
    let event = tokio::time::timeout(Duration::from_secs(1), events.recv()).await.unwrap().unwrap();
    assert!(matches!(event, ServerEventV2::Register { info, .. } if info.alias == "Legacy peer"));
    // Older manual-IP discovery probes the v1 info route, then uses v2 transfers.
    assert_eq!(peer.get(format!("{base}/v1/info")).send().await.unwrap().status().as_u16(), 200);

    let content = b"legacy LocalSend transfer";
    let request = peer.post(format!("{base}/v2/prepare-upload")).json(&serde_json::json!({
        "info": info, "files": {"file": {
            "id": "file", "fileName": "legacy.txt", "size": content.len(), "fileType": "text/plain"
        }}
    })).send();
    let receiver = async {
        match events.recv().await.unwrap() {
            ServerEventV2::PrepareUpload { cert_fingerprint, decision_tx, .. } => {
                assert!(cert_fingerprint.is_none());
                decision_tx.send(PrepareUploadDecisionV2::Accept(["file".into()].into_iter().collect())).unwrap();
            }
            event => panic!("unexpected event: {event:?}"),
        }
    };
    let (response, ()) = tokio::join!(request, receiver);
    let response = response.unwrap();
    assert_eq!(response.status().as_u16(), 200);
    let session: serde_json::Value = response.json().await.unwrap();
    let upload = peer.post(format!(
        "{base}/v2/upload?sessionId={}&fileId=file&token={}",
        session["sessionId"].as_str().unwrap(), session["files"]["file"].as_str().unwrap()
    )).body(Bytes::from_static(content)).send();
    let receive = async {
        match events.recv().await.unwrap() {
            ServerEventV2::FileUpload { target_tx, .. } => {
                let (binary_tx, mut binary_rx) = mpsc::channel(16);
                let (result_tx, result_rx) = oneshot::channel();
                target_tx.send(FileUploadTarget::Stream { binary_tx, result_rx }).unwrap();
                let mut received = Vec::new();
                while let Some(chunk) = binary_rx.recv().await { received.extend_from_slice(&chunk); }
                assert_eq!(received, content);
                result_tx.send(Ok(())).unwrap();
            }
            event => panic!("unexpected event: {event:?}"),
        }
    };
    let (response, ()) = tokio::join!(upload, receive);
    assert_eq!(response.unwrap().status().as_u16(), 200);
    stop_tx.send(()).unwrap();
    server.wait_stopped().await;
}
