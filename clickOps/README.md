# ClickOps (Manual AWS Setup)

This documents the manual, click-through AWS setup completed *before* rebuilding
the same infrastructure with Terraform. 

## Step 1. ECR Repository
- **What it is:** a private storage locker in AWS specifically for Docker images — a warehouse shelf reserved just for app's packaged versions
- **Why it matters:** ECS needs to pull your container image from *somewhere* to run it — ECR is that source
- **How I did it:**
  - Created the repo via AWS CLI (`aws ecr create-repository`)
  - Authenticated Docker to it
  - Tagged the local image with the git commit SHA and pushed it
  - Verified with `aws ecr describe-images`

![ECR repository showing pushed image with its tag](/screenshots/ecrRepo.png)


## Step 2. ECS Cluster (Fargate)
- **What it is:** a logical grouping AWS uses to organise and run containers — "Fargate" means AWS manages the actual server underneath, never see or maintain it
- **Why it matters:** this is the "home" my app's container lives in on AWS — without a cluster, there's nowhere for a container to run
- **How I did it:**
  - ECS Console → Create cluster → Fargate (serverless, no EC2 instances to manage)
  - Left it in the default VPC

![ECS cluster](/screenshots/ecsCluster.png)


## Step 3. Task Definition
- **What it is:** a blueprint describing exactly how to run a container — which image, how much CPU/memory, which port
- **Why it matters:** ECS can't just "run a container" — it needs precise instructions, written once and reused every time the app starts
- **How I did it:**
  - Created a Fargate task definition pointing at the ECR image URI + tag
  - Set container port to 3000
  - Chose the smallest CPU/memory tier

![Task Definition](/screenshots/taskDefinition.png)


## Step 4. Application Load Balancer (ALB)
- **What it is:** the "front door" of the app — receives incoming web traffic and forwards it to the running container
- **Why it matters:** the container has no fixed public address of its own; the ALB gives one stable entry point, and can spread traffic across multiple copies if scaled up
- **How I did it:**
  - Created an internet-facing ALB across public subnets in the default VPC
  - Attached the security group
  - Created a target group (type IP, port 3000, health check path `/health`) in the same wizard
  - Fixed an Availability Zone mismatch — the task landed in a zone the ALB wasn't listening in
  - Fixed a security group gap — the ALB's SG didn't allow port 3000 through to the task; added a dedicated inbound rule allowing port 3000 from the ALB's SG


![Application Load Balancer](/screenshots/alb.png)

## Step 5. Security Group
- **What it is:** a firewall — rules controlling what traffic is allowed in and out
- **Why it matters:** without this, either nothing could reach an app (too locked down) or anything could (too open)
- **How I did it:**
  - Created `alb-sg`, allowing inbound 80/443 from anywhere
  - Reused alb-sg for the task too — added an inbound rule for port 3000 rather than creating a separate task-specific security group

![Security Group](/screenshots/alb-sg.png)


## Step 6. Route 53 Domain + Record
- **What it is:** AWS's DNS service — translates a human-readable address (`app.trackance.co.uk`) into the ALB's technical address
- **Why it matters:** without this, visitors would have to use a long, ugly auto-generated AWS address instead of a real, memorable domain
- **How I did it:**
  - Registered `trackance.co.uk` directly through Route 53
  - Once active, added an `A` record (alias) for `app.trackance.co.uk` pointing at the ALB

![Domain + A record](/screenshots/domain.png)

## Step 7. ACM Certificate (HTTPS)
- **What it is:** a digital certificate proving the site is genuinely yours, enabling the padlock icon and encrypted (HTTPS) traffic
- **Why it matters:** without it, browsers warn visitors the site isn't secure, and any data sent travels unencrypted — non-negotiable for a real production app
- **How I did it:**
  - Requested a public certificate for `app.trackance.co.uk` in ACM (same region as the ALB)
  - Chose DNS validation, used the "Create records in Route 53" auto-button
  - Waited for status: Issued
  - Added an HTTPS:443 listener on the ALB using the certificate

![ACM Cerificate](/screenshots/acmCert.png)


## Result
- This single screenshot proves every piece above (ECR → ECS → ALB → security group → domain → HTTPS) is correctly wired together into one working chain
- a browser window showing **`https://app.trackance.co.uk/health`** with a visible padlock icon and the `{"status":"ok"}` response

![Final Trackance Webpage showing '{"status":"ok"}'](/screenshots/trackanceWebpage.png)


