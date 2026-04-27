# Architecture & Infrastructure Documentation

This document outlines the architecture, deployment strategy, and operational considerations for the DevOps assignment. The application consists of a simple frontend and backend, deployed across two distinct cloud providers: **AWS** and **GCP**.

## 1. Cloud & Region Selection

### AWS (Amazon Web Services)
*   **Region:** `us-west-2` (Oregon)
*   **Justification:** `us-west-2` is one of AWS's most feature-rich regions, often receiving new services first. It boasts a lower cost profile compared to `us-east-1` or `us-west-1` and is powered heavily by renewable energy, aligning with modern sustainability goals. Latency is optimal for North American traffic.

### GCP (Google Cloud Platform)
*   **Region:** `us-central1` (Iowa)
*   **Justification:** `us-central1` provides an excellent balance of cost and central geographical placement, reducing latency uniformly across the United States. It is a low-CO2 region and supports all required serverless and networking products.

## 2. Compute & Runtime Decisions

**Philosophy:** Avoid Kubernetes unless absolutely necessary. For a simple 1-2 page frontend and a basic backend, K8s introduces severe operational overhead, complex state management, and unnecessary costs.

*   **AWS: Amazon ECS with AWS Fargate**
    *   *Choice:* Serverless containers instead of EC2 or EKS.
    *   *Justification:* Fargate removes the need to patch, scale, or manage underlying EC2 instances. It provides excellent isolation (each task runs in its own VM boundary) and scales linearly. It is significantly simpler to operate than EKS while providing all the networking controls of a VPC.
*   **GCP: Google Cloud Run**
    *   *Choice:* Fully managed serverless platform.
    *   *Justification:* Cloud Run is the industry gold standard for running stateless containers. It scales to zero (perfect for `dev` environments to save costs) and can scale to thousands of instances in seconds during traffic spikes. The operational complexity is near zero.

## 3. Networking & Traffic Flow

### AWS Networking
*   **Public vs Private:** The architecture utilizes a VPC with Public and Private subnets.
*   **Ingress:** An internet-facing Application Load Balancer (ALB) sits in the public subnet. It terminates TLS/SSL (in a real setup) and routes HTTP traffic to the Frontend ECS Service.
*   **Internal Communication:** The Frontend talks to the Backend via AWS CloudMap (Service Discovery). The Backend ECS service does not need a public IP or external ALB.
*   **Security:** Security Groups enforce least-privilege. The ALB only accepts traffic on Port 80/443. The Frontend tasks only accept traffic from the ALB. The Backend tasks only accept traffic from the Frontend tasks.

### GCP Networking
*   **Ingress:** A Global HTTP(S) Load Balancer routes external traffic to the Cloud Run services using Serverless Network Endpoint Groups (NEGs).
*   **Internal Communication:** The Frontend uses the Backend's internal Cloud Run URL. Access is controlled via IAM (`roles/run.invoker`), ensuring only the frontend service account can invoke the backend.

## 4. Environment Separation (Dev / Staging / Prod)

We utilize Git branch-based environments (`dev`, `staging`, `main`), triggering specific Terraform configurations.

*   **Dev:** Minimal resources. On GCP, Cloud Run scales to zero to cost absolutely nothing when not in use. On AWS, ECS desired count is 1 with the smallest Fargate sizing.
*   **Staging:** Mirrors production exactly but scaled down. Used for pre-release validation.
*   **Prod:** High availability limits. Requires explicit approval to deploy in CI/CD. Multi-AZ deployment is strictly enforced on AWS. On GCP, Cloud Run inherently spans multiple zones.
*   **Safety:** Each environment uses a distinct Terraform state file (AWS S3 prefix or GCP GCS prefix) to prevent cross-contamination.

## 5. Scalability & Availability

*   **What scales automatically?**
    *   *AWS:* ECS Service Auto Scaling is configured to track CPU/Memory. If CPU > 70%, Fargate spins up more tasks. The ALB automatically scales to handle incoming connection limits.
    *   *GCP:* Cloud Run handles request-based scaling automatically. It spins up new instances concurrently as requests queue up.
*   **What does not scale automatically?**
    *   VPC subnets (CIDR blocks are fixed).
    *   Database (if one existed, it would require vertical scaling or read-replicas, which are not instantaneous).
*   **Availability:** AWS is deployed across 2 Availability Zones minimum. GCP Cloud Run is inherently multi-zonal within `us-central1`. Minimum availability is guaranteed by the load balancers performing health checks and routing around failed containers.

## 6. Deployment Strategy

*   **Flow:** Code pushed -> GitHub Actions builds Docker image -> Pushes to Registry (ECR/Artifact Registry) -> Terraform applies updated task definition / Cloud Run revision.
*   **AWS (ECS):** Uses Rolling Updates. ECS starts new tasks. Once they pass the ALB health check, it drains connections from the old tasks and terminates them. Zero downtime.
*   **GCP (Cloud Run):** Traffic splitting. A new revision is deployed, and 100% of traffic is atomically switched to it once ready. Zero downtime.
*   **Rollback:** Revert the Git commit. CI/CD will redeploy the previous image hash. Alternatively, manually shift traffic back to the older Cloud Run revision via the GCP console during an incident.

## 7. Infrastructure as Code & State Management

*   **Tool:** Terraform.
*   **State Storage (AWS):** State is stored in a centralized AWS S3 Bucket.
*   **State Locking (AWS):** DynamoDB table is used to lock the state, preventing race conditions if two developers run `terraform apply` simultaneously.
*   **State Storage & Locking (GCP):** Google Cloud Storage (GCS) bucket is used, which inherently supports state locking.
*   **Isolation:** `terraform.tfstate` is partitioned by environment (e.g., `s3://bucket/dev/terraform.tfstate`).

## 8. Security & Identity

*   **Deployment Identity:** GitHub Actions uses Workload Identity Federation (OIDC) instead of static long-lived credentials. This allows CI to assume a temporary AWS IAM Role or GCP Service Account.
*   **Human Access:** Developers do not have SSH access to containers. Log access is granted via AWS CloudWatch / GCP Cloud Logging.
*   **Least Privilege:** ECS Task Roles and Cloud Run Service Accounts are explicitly defined. They only have permissions to do what is necessary (e.g., write logs).
*   **Secrets:** Secrets are stored in AWS Secrets Manager / GCP Secret Manager and injected at runtime as environment variables. They are never hardcoded or printed in CI logs.

## 9. Failure & Operational Thinking

*   **Smallest Failure Unit:** A single container (Frontend or Backend).
*   **What breaks first?** Under extreme, unexpected load (DDoS), the backend containers might OOM (Out of Memory) or CPU throttle before Auto-Scaling can catch up.
*   **Self-Recovery:** If a container crashes, ECS/Cloud Run will automatically kill it and spin up a new instance. The Load Balancers will route traffic away from the failing instance instantly due to health checks.
*   **Human Intervention:** Required if the deployment pushes a bad image (e.g., application code panic on startup). The orchestrator will go into a "CrashLoopBackOff" state. A human must rollback the deployment.
*   **Alerting Philosophy:** We do not alert on CPU usage (as auto-scaling handles it). We wake someone up at 2 AM only for:
    *   HTTP 5xx error rate > 5% for 5 minutes.
    *   P99 Latency > 2 seconds.
    *   Load Balancer Health Check failures across all zones.

## 10. Future Growth Scenario (10x Traffic & New Services)

If traffic increases 10x and a new service is added:
*   **What changes:**
    *   We would introduce an API Gateway or Service Mesh (like AWS App Mesh or Istio on GCP) to handle routing between multiple microservices efficiently.
    *   We would implement caching (Redis/Memcached) or CDNs (CloudFront/Cloud CDN) to offload the frontend and static assets from compute resources.
*   **What remains unchanged:** The core compute primitives. Fargate and Cloud Run easily handle 10x traffic. Our IaC structure (environment separation, state locking) scales infinitely.
*   **Early decisions that help:** Choosing serverless containers over Kubernetes means we don't have to worry about node group scaling, cluster upgrades, or K8s control plane limits when traffic 10x's.

## 11. "What We Did NOT Do" (Intentional Omissions)

To demonstrate engineering maturity and restraint, the following were intentionally omitted:
1.  **Kubernetes (EKS/GKE):** The application is 2 stateless tiers. K8s would introduce massive configuration sprawl, operational burden, and high baseline costs without providing tangible benefits for this specific workload.
2.  **Service Mesh:** Over-engineering. Native service discovery (CloudMap) and Cloud Run internal routing are sufficient for 2 services.
3.  **Complex CI/CD Deployment Strategies (Blue/Green or Canary):** For a simple application, standard rolling deployments are sufficient. Blue/Green requires duplicate infrastructure costs which is unwarranted at this stage.
4.  **Multi-Region Active-Active:** High complexity and data replication issues. Multi-zone is sufficient for this SLA.
