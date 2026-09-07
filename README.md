# Trackance - Client Project Status Tracker

A lightweight project status tracker for freelancers and small teams,
containerised with Docker, deployed to AWS ECS Fargate, and provisioned
entirely with Terraform, with HTTPS on a custom domain and a full CI/CD
pipeline behind it.

**Live:** [https://app.trackance.co.uk](https://app.trackance.co.uk)

## Live Demo

https://github.com/user-attachments/assets/da105d6b-e109-46f8-8c75-c2a29af07577

## Overview

I built this project specifically to take something from a manual, click-through
AWS setup through to a fully automated, infrastructure-as-code deployment end-to-end.

The app itself is a client project tracker built for freelancers or small teams.
It's deliberately minimal: no accounts, no database, one shared list, just 
enough to be real, without adding complexity that would compete with the actual
point of the build, which was the infrastructure and pipeline around it.

**Stack:** Node.js / Express backend, HTML/CSS/JS frontend, file-based
storage. Docker (multi-stage, distroless, non-root). Terraform. AWS (ECS
Fargate, ALB, ACM, Route 53, ECR, VPC). GitHub Actions with OIDC.

---

## AWS Components

- **ECS Fargate** — runs the app as a serverless container, no EC2 to manage
- **Application Load Balancer** — terminates HTTPS, redirects HTTP, routes to the target group
- **VPC** — 2 Availability Zones; public subnets hold the ALB and NAT Gateway, private subnets hold the ECS task
- **Internet Gateway** — internet access for the public subnets
- **NAT Gateway** — outbound-only internet access for the private-subnet task (single, shared across both AZs)
- **Route 53** — hosted zone and record for the custom domain
- **ACM** — TLS certificate, DNS-validated
- **ECR** — private image registry, immutable tags
- **CloudWatch Logs** — centralised logs from the ECS task
- **IAM** — OIDC-based least-privilege role for the pipelines, plus a task execution role for ECS
- **S3** — Terraform state, with native locking

## Architecture

![Architecture diagram](/screenshots/ECS-Architecture-Diagram.png)

Solid arrows = real traffic (what a user's request or the task's own outbound connection actually travels through)
Dashed arrows = configuration, permissions, or deployment relationships - nothing flows continuously through these

**How it all fits together:**
- A request starts with a DNS lookup against Route 53, resolving
  `app.trackance.co.uk` to the Application Load Balancer
- Real traffic enters through the Internet Gateway and hits the ALB, which
  sits across two public subnets (required for the ALB to function) and
  handles the HTTP→HTTPS redirect using a certificate issued and validated
  through ACM
- From there, traffic goes through a target group to the ECS Fargate task,
  which runs inside a private subnet with no direct route from the internet
  at all - the only way in is through the ALB
- The task ships its logs to CloudWatch and pulls its container image from
  ECR
- Since the task has no direct internet route, its outbound connections
  (pulling that image, DNS lookups) go out through a NAT Gateway sitting in
  one of the public subnets - the one thing giving a private-subnet resource
  a way out without ever being reachable from the outside
- Separately, GitHub Actions handles deployment: it authenticates to AWS
  using OIDC (no stored AWS keys), pushes built images to ECR, and runs
  Terraform against this whole setup
- The credentials for that OIDC connection live in their own, separate
  Terraform state (`bootstrap/`), so tearing down the application
  infrastructure can never accidentally remove the pipeline's own ability
  to authenticate
- Terraform's own state and locking live in S3

A few specific decisions worth explaining:

- **One shared NAT Gateway, not one per AZ.** A per-AZ setup is more resilient
  but roughly doubles the cost for redundancy this project doesn't need at
  its current scale.
- **No autoscaling.** Fixed at one task - this is a portfolio deployment, not
  expecting real production traffic.
- **ECR images are immutable.** Once a tag is pushed, it can never be
  reassigned to a different image meaning every deployment is traceable back to an
  exact, unchangeable build. The ECS task pulls by **digest**, not tag, so
  Terraform always deploys whatever was most recently pushed without needing
  a manually-maintained variable.
- **GitHub OIDC authentication lives in its own `bootstrap/` Terraform state**,
  separate from the application infrastructure in `infra/`. This means a
  `Terraform Destroy` on the app infrastructure can never accidentally remove
  the very credentials the pipeline needs to authenticate and rebuild it.
- **The GitHub Actions IAM role uses a hand-built least-privilege policy**,
  not `AdministratorAccess` - enumerated actions, resource ARNs scoped
  wherever AWS supports it.

Manual AWS setup (ClickOps) evidence and screenshots, from before this was
rebuilt in Terraform, are kept in [`/clickops`](./clickops).

---

## Project Structure

```
ECS-project/
├── app/                        # Application source
│   ├── server.js
│   ├── store.js
│   ├── data.json
│   ├── package.json
│   └── public/
│       └── index.html          # Frontend
├── infra/                      # Application Terraform (own state)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── modules/
│       ├── vpc/                # VPC, public + private subnets, IGW, NAT
│       ├── ecr/                # Image repo, immutable tags
│       ├── acm/                # Certificate, DNS validation
│       ├── alb/                # Load balancer, target group, listeners
│       └── ecs/                # Cluster, task definition, service
├── bootstrap/                  # GitHub OIDC + IAM (separate Terraform state)
│   ├── main.tf
│   ├── variables.tf
│   ├── provider.tf
│   └── outputs.tf
├── clickops/                   # Manual AWS setup evidence (pre-Terraform)
├── .github/workflows/          # CI/CD pipelines
│   ├── app-deploy.yml
│   ├── terraform-plan.yml
│   ├── terraform-deploy.yml
│   └── terraform-destroy.yml
├── Dockerfile
├── .dockerignore
├── .gitignore
├── bootstrap-ecr.sh             # One-time ECR bootstrap script
└── README.md
```

---

## CI/CD Pipelines

Four pipelines, each with a single responsibility:

| Pipeline | Trigger | What it does |
|---|---|---|
| **Build and Push** | Push to `app/`, `Dockerfile` | Builds the image, tags with the commit SHA, pushes to ECR |
| **Terraform Plan** | Pull request touching `infra/` | `fmt`, `validate`, `tflint`, `plan` — no `apply` |
| **Terraform Deploy** | After Build and Push succeeds, push to `infra/`, or manual | `plan` + `apply`, then a post-deploy health check against `/health` |
| **Terraform Destroy** | Manual only, requires typing `destroy` to confirm | Tears down the application infrastructure |

All four authenticate to AWS via GitHub OIDC — no long-lived AWS keys stored
anywhere in the repo or GitHub secrets.

![Build and Push](/screenshots/build-and-push.png)
![Terraform Plan](/screenshots/tf-plan.png)
![Terraform Deploy](/screenshots/tf-deploy.png)
![Terraform Destroy](/screenshots/tf-destroy.png)

---

## Local Setup

**Prerequisites:**
- AWS account, Terraform, AWS CLI (configured via `aws configure`), Docker, Node.js
- A domain you own, hosted in Route 53 — ACM and Route 53 both require real ownership
- A unique S3 bucket name in mind — bucket names are global across all of AWS, so `trackance-tfstate-sss3333` can't be reused as-is
Wherever the steps below reference my domain, bucket name, or GitHub repo, substitute your own — `domain_name` in `infra/variables.tf` and `github_org`/`github_repo` in `bootstrap/variables.tf` default to mine.
 
**Clone the repo:**
```bash
git clone https://github.com/sss-3333/ECS-project.git
cd ECS-project
```

**Run the app directly:**
```bash
cd app
npm install
npm start
# visit http://localhost:3000
```
 
**Run it containerised (matches production):**
```bash
docker build -t tracker-app .
docker run -p 80:3000 tracker-app
# visit http://localhost
```
 
**Reproduce the infrastructure:**
```bash
# One-time: create the S3 bucket Terraform will store its state in.
aws s3api create-bucket --bucket <your-bucket-name> --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2
aws s3api put-bucket-versioning --bucket <your-bucket-name> \
  --versioning-configuration Status=Enabled
 
# One-time: create the ECR repo before anything else exists
./bootstrap-ecr.sh
 
# Authenticate Docker to your new ECR repo
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.eu-west-2.amazonaws.com
 
# Build, tag, and push an image — Terraform needs at least one image
# in the repo before it can deploy anything
docker build -t tracker-app .
docker tag tracker-app:latest <your-account-id>.dkr.ecr.eu-west-2.amazonaws.com/ecs-project-tracker:latest
docker push <your-account-id>.dkr.ecr.eu-west-2.amazonaws.com/ecs-project-tracker:latest
 
# One-time: OIDC provider + IAM role (needs your own AWS credentials)
cd bootstrap
terraform init
terraform apply
 
# Application infrastructure
cd ../infra
terraform init
terraform plan
terraform apply
```
 
**Tearing it down:**
```bash
cd infra
terraform destroy
```

---

## Challenges & What I Learned

- **GitHub's OIDC token format changed underneath the standard trust policy pattern.**
   Every tutorial (and AWS's own docs) show a `sub` condition like
  `repo:org/repo:*`. My trust policy matched that exactly and still failed
  `AssumeRoleWithWebIdentity`. Decoding the actual token GitHub was sending
  showed why: it now includes immutable owner/repo IDs
  (`repo:org@id/repo@id:...`), not just the plain names. I fixed it with a
  wildcarded pattern that matches both forms - but only after choosing to
  verify the real token rather than trust the documented format.
- **A generic error hid the real missing permission.** After fixing the
  trust policy, the exact same `AssumeRoleWithWebIdentity` error persisted.
  The actual cause was `configure-aws-credentials@v4` attaching session tags
  by default, which needs `sts:TagSession` — a completely different
  permission than the error message implied.
- **Least-privilege IAM is genuinely hard to get right on paper.** Every
  Terraform action needs read permissions during `plan`'s state refresh, not
  just the create/update/delete actions you'd expect. I ended up testing the
  actual policy by locally assuming the real IAM role and iterating against
  real `AccessDenied` errors until `terraform plan` came back completely
  clean — a slower process than guessing, but the only way to be sure it was
  actually correct rather than just plausible.
- **A stale local variable silently rolled the app backward, three times.**
  Running `terraform plan` locally without passing the current image tag
  fell back to an old value in a leftover `terraform.tfvars` file, nearly
  redeploying an outdated image on separate occasions. The permanent fix was
  removing the manual variable entirely — Terraform now looks up the most
  recently pushed ECR image itself via a data source, so there's nothing
  left to go stale.
- **A working build doesn't mean a working image.** After adding the
  frontend, the app deployed successfully and passed every health check, but
  the site showed "Cannot GET /". The Dockerfile's multi-stage build copied
  files individually by name into the final image — a pattern written before
  the frontend existed — so the new `public/` folder was silently never
  included, despite existing in source and in the build stage.

---
## Features To Add Later

- User accounts, so multiple freelancers could each keep a private list
  rather than one shared one
- A client-facing read-only view
- Notifications when a project's been sitting in "Waiting on Client" too long
