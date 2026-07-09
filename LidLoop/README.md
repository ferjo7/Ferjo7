# LidLoop

LidLoop is an enterprise-grade, AI-powered visual search and contextual shopping assistant application engineered to bridge the gap between real-world visual data and digital commerce networks. By implementing localized hardware camera optimizations, asynchronous edge-to-cloud visual processing pipelines, and state-of-the-art vision-language models (VLMs), LidLoop delivers sub-second product identification, granular attribute tagging, and programmatic multi-merchant metadata mapping.

---

## 🚀 Core Features & Capabilities

* **Intelligent Vision Capture Pipeline:** Integrates a responsive, lifecycle-aware native camera controller optimized for high-resolution static frame ingestion and dynamic screenshot parsing.
* **Asynchronous Multi-Model Orchestration:** Dispatches raw image payloads to decoupled, serverless execution layers that utilize state-of-the-art Vision-Language Models (VLMs) for deep semantic analysis and granular object detection.
* **Dynamic Attribute Extraction:** Evaluates visual features—such as textures, brand emblems, and structural geometries—converting them into structured JSON metadata.
* **Programmatic Product Graph Matching:** Cross-references extracted vector signatures against relational merchant indexes to surface exact product matches, availability tracking, and monetization rails.
* **Decoupled State Management:** Leverages a strict model-view-viewmodel configuration ensuring responsive UI drawing, predictable error boundaries, and elegant offline caching states.

---

## 🛠️ System Architecture & Engineering

The application is architected around a modern, decoupled cloud-to-mobile infrastructure designed for maximum horizontal scalability and minimal compute latency.



### 1. The Mobile Ingestion Layer (Client)
The frontend client acts as an efficient data capture node. It isolates resource-heavy UI transitions from background I/O operations:
* **Camera Lifecycle Management:** Interceptors hook directly into platform hardware layers, ensuring that video buffers are cleanly detached when the view loses focus to mitigate memory leak vectors.
* **Payload Minimization:** Before transmission, heavy uncompressed images are downscaled, compressed, and stream-encoded asynchronously on a background isolate thread to conserve mobile bandwidth and reduce backend cold-start processing latency.

### 2. The Compute & Processing Pipeline (Cloud)
* **Serverless Execution Layer:** Serverless runtime environments isolate computation, running decoupled API gateways and cloud workflows to ingest the binary payload securely.
* **Semantic Object Labeling:** High-dimensional vector models process the unstructured binary frames to isolate regions of interest (RoIs) and parse complex visual data into structured data fields.
* **Data Lake Persistence:** Event-driven databases store real-time analytics, user execution trails, and search telemetry for downstream vector fine-tuning.

---

## 📁 Repository Structure

The codebase is structured under clean architecture paradigms, isolating multi-platform native runtime configs from core application state, business rules, and UI components:

```text
├── lib/                             # Core Flutter Application Codebase
│   ├── actions/                     # Global business operations and state side-effects
│   ├── backend/                     # Remote infrastructure abstractions & model serializations
│   │   ├── schema/                  # Firestore Document schemas and strongly-typed data objects
│   │   └── api_requests/            # Outbound REST/GraphQL network interceptors and payload blocks
│   ├── custom_code/                 # Native Dart integrations and platform channel bridges
│   ├── flutter_flow/                # Visual styling tokens, UI utilities, and basic component state
│   ├── index.dart                   # Centralized export hub for clean dependency resolution
│   └── main.dart                    # Application entrypoint and hardware configuration bootstrap
├── assets/                          # Static layout resources, iconography, and multi-lingual vectors
├── android/                         # Gradle build scripts and Android-specific native wrappers
├── ios/                             # Podfile, xcworkspace schemas, and native iOS targets (iOS 15.5+)
├── web/                             # Build configuration target for progressive web applications (PWA)
└── pubspec.yaml                     # Application package dependencies, assets, and environmental targets