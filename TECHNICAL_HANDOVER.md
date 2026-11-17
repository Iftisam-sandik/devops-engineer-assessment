# টেকনিক্যাল হ্যান্ডওভার — সহজ বাংলায়

এই প্রজেক্টে একটি ছোট Node.js অ্যাপকে পরীক্ষা, Docker image তৈরি, নিরাপত্তা যাচাই, Kubernetes deployment এবং monitoring পর্যন্ত নিয়ে যাওয়া হয়েছে। বাস্তব GitHub CI-তে এই অংশগুলো চালানো হয়েছে; তিনটি Grafana screenshot-ও বাস্তব চলমান dashboard থেকে নেওয়া। **AWS-এ infrastructure তৈরি বা EC2 deployment এখনো হয়নি**, কারণ মালিকের স্পষ্ট অনুমতি এবং temporary AWS identity পাওয়া যায়নি। তাই পুরো assessment সম্পূর্ণ হয়েছে বলা যাবে না। কোন কাজ কোথায় যাচাই হয়েছে, তা [compliance matrix](docs/COMPLIANCE_MATRIX.md) ও [final report](docs/FINAL_REPORT.md)-এ আছে।

## ১. পুরো সিস্টেমের কাজ কী

ধরুন আপনি অ্যাপের কোড পরিবর্তন করে GitHub-এ Pull Request দিলেন। CI প্রথমে কোডের ভুল, endpoint-এর আচরণ, Dockerfile, Bash script এবং image-এর vulnerability পরীক্ষা করে। পাশাপাশি একটি আসল kind cluster বানিয়ে Kubernetes update/rollback চালায়। আরেকটি job পুরো monitoring stack চালিয়ে metrics, logs, alert এবং dashboard যাচাই করে। সব ঠিক থাকলে main branch-এর release workflow দুই ধরনের CPU architecture-এর image registry-তে পাঠায়।

AWS অনুমোদিতভাবে প্রস্তুত হলে একই release workflow GitHub OIDC দিয়ে অল্প সময়ের AWS access নেয়। SSM ব্যবহার করে EC2-তে নতুন container চালায়। `/health` ঠিক না থাকলে আগের container ফিরিয়ে আনে। এখানে SSH key বা স্থায়ী AWS access key দরকার হয় না।

তিনটি deployment পরিবেশ আলাদা করে বুঝতে হবে:

- **Docker Compose:** নিজের কম্পিউটারে app ও monitoring চালানোর সহজ ব্যবস্থা।
- **kind/Kubernetes:** একাধিক replica, rolling update, rollback এবং autoscaling শেখানো ও যাচাই করার ব্যবস্থা।
- **AWS EC2:** assessment-এ চাওয়া cloud deployment target। Terraform code প্রস্তুত, কিন্তু বাস্তব execution অনুমোদনের অপেক্ষায়।

README-র architecture diagram-এ delivery pipeline এবং metrics/logs-এর পথ একসঙ্গে দেখানো আছে।

## ২. অ্যাপ্লিকেশন ও তার endpoint

কোড দেখুন [src/app.js](src/app.js), [src/config.js](src/config.js) ও [src/server.js](src/server.js)। Express HTTP request গ্রহণ করে।

| Endpoint | কাজ |
| --- | --- |
| `GET /` | নির্দিষ্ট message, running status এবং app version ফেরত দেয় |
| `GET /health` | অ্যাপ request গ্রহণ করার অবস্থায় আছে কি না জানায় |
| `GET /metrics` | Prometheus-এর পড়ার উপযোগী সংখ্যাভিত্তিক তথ্য দেয় |

Root response-এর message ঠিক `Hello from DevOps Task!`। Version environment variable থেকে আসে। Port, log level ও environment-ও environment variable দিয়ে বদলানো যায়; source edit করতে হয় না। ভুল port বা log level দিলে startup ব্যর্থ হয়, যাতে ভুল configuration লুকিয়ে না থাকে।

Log হলো কোনো ঘটনার বিস্তারিত লেখা। এখানে Pino JSON log stdout-এ লেখে। যেমন request-এর method, normalized route, HTTP status এবং সময় থাকে। Authorization header বা query string রাখা হয় না। অজানা path-এর label `unmatched` হয়; প্রতিটি আলাদা URL দিয়ে নতুন label তৈরি হয় না।

SIGTERM এলে অ্যাপ আগে readiness বন্ধ করে, নতুন connection নেওয়া বন্ধ করে এবং চলমান request শেষ করার সুযোগ দেয়। দশ সেকেন্ডেও শেষ না হলে connection বন্ধ করে। Docker পনেরো সেকেন্ড সময় দেয়, তাই অ্যাপের নিজস্ব shutdown deadline আগে কাজ করতে পারে। সঙ্গে সঙ্গে process মেরে দিলে চলমান request ব্যর্থ হতে পারত।

Test-এ সঠিক response ছাড়াও 404, 500, metrics, token protection, invalid configuration এবং graceful/forced shutdown যাচাই করা হয়। `/metrics`-এ optional bearer token দেওয়া যায়; Kubernetes-এ এই token Secret থেকে আসে। `/health` token ছাড়াই চলে, যাতে probe কাজ করতে পারে।

## ৩. Docker কীভাবে সাজানো হয়েছে

Docker image হলো অ্যাপ চালানোর প্রয়োজনীয় runtime ও file-এর প্যাকেট। Container হলো সেই image থেকে চলমান process। একই image অন্য মেশিনে চালালে পরিবেশের পার্থক্য কমে।

[Dockerfile](Dockerfile)-এ দুটি stage আছে। প্রথম stage `npm ci --omit=dev` দিয়ে lock file অনুযায়ী production dependency বসায়। শেষ stage কেবল runtime, app code এবং production dependency নেয়। Test framework ও lint tool শেষ image-এ যায় না। Base image-এর Node ও Alpine version নির্দিষ্ট করা আছে।

Container root হিসেবে চলে না। Compose-এ root filesystem read-only, সব Linux capability বাদ, privilege বাড়ানো নিষিদ্ধ, এবং CPU/memory/PID limit দেওয়া আছে। Health check Node দিয়েই `/health` call করে, বাড়তি curl package লাগে না। OCI labels থেকে source, version ও revision শনাক্ত করা যায়। `.dockerignore` secret, test output, Terraform ও অপ্রয়োজনীয় file build context থেকে বাদ দেয়।

যাচাই করা amd64 image-এর uncompressed size প্রায় **146.33 MiB**। Registry থেকে download হওয়ার compressed size এর সমান নয়। সঠিক byte count ও image identity evidence file-এ আছে।

শুরু করার command:

```bash
npm ci --ignore-scripts
npm run test:coverage
docker compose up -d --build
curl -fsS http://127.0.0.1:8080/health
docker compose logs -f app
```

Proxy certificate-এর কারণে build ব্যর্থ হলে TLS verification বন্ধ করবেন না। README-তে BuildKit secret দিয়ে trusted CA দেওয়ার command আছে। Certificate শেষ image-এ কপি হয় না।

## ৪. CI/CD workflow বোঝা

[ci.yml](.github/workflows/ci.yml) ও [release.yml](.github/workflows/release.yml) পড়ুন।

CI-র lint code style ও সম্ভাব্য programming mistake ধরে। Unit test নির্দিষ্ট আচরণ যাচাই করে। Coverage বলে test চলার সময় code-এর কত অংশ execute হয়েছে; বেশি coverage একাই bug-free হওয়ার প্রমাণ নয়। Hadolint Dockerfile এবং ShellCheck Bash-এর ভুল ধরে। Trivy final application image-এর OS ও package vulnerability পরীক্ষা করে। কোনো CRITICAL finding থাকলে pipeline ব্যর্থ হয়, fix পাওয়া যায়নি বলেও সেটি উপেক্ষা করা হয় না।

CI শুধু YAML যাচাই করে থামে না। আলাদা job সত্যিকারের kind cluster, monitoring container এবং systemd timer চালায়। Output artifact হিসেবে রাখা হয়। Repository-র evidence ও screenshot সেই actual execution থেকে এসেছে।

Main branch-এ Buildx/QEMU দিয়ে `linux/amd64` এবং `linux/arm64` image বানানো হয়। Cache থাকলে অপরিবর্তিত layer আবার বানাতে হয় না। Full Git SHA code-এর পরিচয়, semantic version মানুষের বোঝার মতো release পরিচয়। Run/attempt suffix একই workflow আবার চালানোর সময় immutable ECR tag-এর সংঘর্ষ এড়ায়। Deployment digest ব্যবহার করে; tag পরে বদলালেও digest-এর content বদলায় না।

GitHub-এর automatic `GITHUB_TOKEN` GHCR-এ publish করে। AWS-এর জন্য OIDC role ব্যবহার করার code আছে; long-lived access key নেই। `AWS_DEPLOY_ENABLED` অনুমোদিত setup শেষ হওয়ার আগে unset থাকবে। Variable চালু করলেই AWS প্রস্তুত হয়ে যায় না।

## ৫. Terraform ও AWS-এর অংশ

Terraform দিয়ে infrastructure-এর কাঙ্ক্ষিত অবস্থা code-এ লেখা হয়। `plan` দেখায় কী তৈরি/বদলাবে, `apply` সত্যি কাজটি করে। `validate` শুধু configuration সঠিক কি না পরীক্ষা করে; cloud-এ resource আছে বা permission কাজ করে, তা প্রমাণ করে না।

এই প্রজেক্টের প্রধান resource:

- VPC/subnet/route/Internet Gateway: EC2-এর network। NAT Gateway যোগ করা হয়নি, যাতে অপ্রয়োজনীয় খরচ না হয়।
- Security Group: default অবস্থায় inbound বন্ধ; অনুমোদিত source CIDR-এর জন্য কেবল app-এর 8080 খোলা যায়। SSH port নেই।
- EC2 ও encrypted gp3 disk: Docker container চালায়; IMDSv2 বাধ্যতামূলক।
- IAM instance profile: EC2 নিজের পরিচয়ে ECR থেকে image টানে, CloudWatch-এ log পাঠায় ও SSM-এর সঙ্গে কথা বলে।
- ECR: private image registry, immutable tag।
- CloudWatch Logs: staging-এ সাত দিন, production-এ চৌদ্দ দিন log রাখে।
- GitHub OIDC role: নির্দিষ্ট repository/environment থেকে সীমিত ECR/SSM operation করতে পারে; Terraform apply বা IAM পরিবর্তন করতে পারে না।

State file-এ Terraform কোন resource পরিচালনা করছে তার পরিচয় থাকে। এটি হারালে বা একসঙ্গে দুজন লিখলে সমস্যা হতে পারে। তাই encrypted, versioned, public-blocked S3 bucket এবং native S3 lock file ব্যবহার করা হয়েছে। Lock একই state-এ concurrent write আটকায়। Staging ও production-এর state key আলাদা।

Bucket তৈরির bootstrap প্রথমে local state দিয়ে চলে। Bucket তৈরি হওয়ার পরে example backend configuration কপি করে bootstrap state-ও S3-তে migrate করতে হবে। পুরো command sequence README-তে আছে। আগে থেকে থাকা shared bucket বা OIDC provider মুছে ফেলা যাবে না।

প্রথম app image আগে registry-তে থাকতে হবে। Private ECR-এর ক্ষেত্রে অনুমোদিত temporary identity দিয়ে আগে শুধু assessment repository তৈরি ও bootstrap image push করতে হবে; তারপর digest দিয়ে পূর্ণ Terraform plan/apply। GitHub repository public হলেও GHCR package public ধরে নেওয়া যাবে না।

বর্তমান সীমা মনে রাখবেন: **local init/validate সফল, কিন্তু authenticated AWS plan/apply, EC2 health check, CloudWatch delivery ও cloud cleanup যাচাই হয়নি।** [AWS scope](docs/AWS_APPROVAL_SCOPE.md)-এ অনুমোদনের প্রস্তাব আছে। Raw credential chat বা source-এ দেওয়া যাবে না। আনুমানিক ছোট production setup মাসে প্রায় US$16; এটি billing guarantee নয়।

## ৬. Deployment ব্যর্থ হলে rollback

[scripts/deploy.sh](scripts/deploy.sh) একই সময়ে দুটি deployment হতে না দিতে `flock` নেয়। নতুন image pull সফল হওয়ার আগে পুরোনো container থামায় না। পুরোনোটিকে previous নামে রেখে নতুনটি চালায়। নতুন container-এও non-root image, read-only filesystem ও limit থাকে।

নতুন `/health` সফল না হলে candidate সরিয়ে previous container-এর পুরোনো image এবং configuration ফেরত আনে। Rollback সফল হলেও deployment job fail করে, যাতে খারাপ release চাপা না পড়ে। একেবারে প্রথম deployment-এ previous container নেই, তাই তখন ফিরিয়ে আনার মতো সংস্করণ নেই।

এটি আসল local Docker container ও registry দিয়ে পরীক্ষা করা হয়েছে। ভুল port-এর candidate health check-এ ব্যর্থ হয়েছে, `ROLLBACK_SUCCEEDED` এসেছে এবং পুরোনো version 1.0.0 সুস্থ response দিয়েছে। **এটি AWS deployment evidence নয়।** এক EC2-তে container বদলানোর সময় সামান্য interruption হয়; EC2-তে zero downtime চাইলে load balancer ও অন্তত দুই target লাগবে।

## ৭. Kubernetes-এর গুরুত্বপূর্ণ বিষয়

Pod-এর মধ্যে container চলে। Deployment replica সংখ্যা এবং image update পরিচালনা করে। এখানে কমপক্ষে দুই replica থাকে। Service স্থির ঠিকানা দিয়ে ready Pod-এ request পাঠায়। Pod বদলে গেলেও client-এর Service address বদলাতে হয় না।

Readiness probe বলে Pod request নিতে পারছে কি না; ব্যর্থ হলে Service তাকে traffic দেয় না। Liveness probe বারবার ব্যর্থ হলে Kubernetes container restart করতে পারে। Startup probe ধীর startup-এর জন্য সময় দেয়। CPU/memory request scheduler-এর হিসাব, limit process-এর ব্যবহার সীমিত করার ব্যবস্থা।

ConfigMap-এ port/log level-এর মতো non-secret configuration আছে। Generated Secret-এর token metrics endpoint রক্ষা করে। Secret-এর base64 encoding encryption নয়; production-এ encrypted etcd ও external secret manager দরকার। এখানে secret value repository-তে রাখা হয়নি।

Rolling update-এ `maxUnavailable: 0` এবং `maxSurge: 1`। অর্থাৎ update-এর জন্য ready replica কমানো যাবে না এবং অতিরিক্ত একটি Pod চালানো যায়। Readiness ও কিছু minimum ready time পার হলে পুরোনো Pod সরানো হয়। HPA CPU utilization 70% target করে দুই থেকে চার replica রাখতে পারে; metrics-server ছাড়া এই CPU তথ্য পাওয়া যায় না।

```bash
bash scripts/k8s-secret.sh
kubectl apply -k k8s/overlays/local
kubectl -n devops-assessment get pods,svc,hpa
bash scripts/k8s-rollout.sh devops-assessment:1.0.1
```

Rollout script cluster-এর ভিতর থেকে Service-এ এক সেকেন্ড পরপর request করে। Update এবং `kubectl rollout undo` চলার সময় HTTP 200 sample সংরক্ষণ করে। নির্দিষ্ট Pod-এ port-forward দিয়ে পরীক্ষা করলে সেই Pod সরানোর কারণে ভুল failure দেখা যেতে পারত। Actual rollout output, availability sample এবং HPA metrics evidence directory-তে আছে।

Production EKS-এ multi-AZ node, replica spreading, disruption budget, real ingress/ALB, TLS, Pod Identity/IRSA, Secrets Manager ও node autoscaling লাগবে। Local kind-এর self-signed certificate exception production-এ ব্যবহার করা যাবে না।

## ৮. ছয়টি monitoring component-এর ভূমিকা

| Component | সহজ ব্যাখ্যা |
| --- | --- |
| Prometheus | নির্দিষ্ট interval-এ endpoint থেকে সংখ্যাভিত্তিক metrics সংগ্রহ করে |
| Grafana | metrics ও logs query করে dashboard দেখায় |
| Loki | log জমা রাখে ও query করতে দেয় |
| Grafana Alloy | Docker container খুঁজে log পড়ে, JSON parse করে Loki-তে পাঠায় |
| Node Exporter | host CPU, memory, disk ও network metrics দেয় |
| cAdvisor | container CPU, memory এবং configured limit-এর তথ্য দেয় |

Counter মোট সংখ্যা গুনে। `rate()` দিয়ে counter কত দ্রুত বাড়ছে জানা যায়। Histogram request কত সময় নিয়েছে তা bucket-এ জমা করে। p95 latency মানে আনুমানিক 95% request ওই সময়ের মধ্যে শেষ হয়েছে; bucket থেকে হিসাব হওয়ায় এটি approximation।

Application dashboard-এ request/error rate ও p50/p95/p99 আছে, পাশে log panel। Host dashboard machine-এর চাপ দেখায়। Containers dashboard নির্দিষ্ট container-এর CPU/memory ও limit-এর অনুপাত দেখায়। একই incident-এর সময় range নির্বাচন করে তিনটি view মিলিয়ে কারণ খুঁজতে হয়।

Error spike দেখলে প্রথমে 4xx না 5xx এবং কোন সময়ে বেড়েছে দেখুন। তারপর Loki-তে:

```logql
{service="app"} | json | status_code >= 500
```

প্রয়োজনে normalized route দিয়ে filter করুন। Error message, duration এবং recent release মিলিয়ে দেখুন। Container memory limit-এর কাছাকাছি কি না, host disk পূর্ণ কি না, CPU চাপ আছে কি না যাচাই করুন। Dashboard-এর error panel 4xx ও 5xx দেখালেও high-error alert শুধু 5xx ধরে।

Label বেশি ধরনের value নিলে আলাদা time series/log stream খুব বেড়ে যায়। তাই request ID বা user ID label নয়; finite level, service ও container label ব্যবহার করা হয়েছে। Route/status JSON field বা structured metadata হিসেবে filter করা যায়।

চারটি alert-এর threshold ও `for` সময় README-তে আছে। `for` মানে condition একটানা কতক্ষণ সত্য হলে firing হবে। Promtool test দিয়ে threshold/duration পরীক্ষা হয়েছে; আলাদাভাবে আসল app থামিয়ে AppDown firing এবং restart করে recovery যাচাই হয়েছে। Slack/Discord notification পাঠানোর optional অংশ করা হয়নি।

## ৯. নিরাপত্তার trade-off

শুধু monitoring-এর Grafana port host-এ প্রকাশ করা হয়েছে; অন্য monitoring API internal network-এ। Grafana admin password environment/runtime secret থেকে আসে। Loki-এর নিজের authentication বন্ধ থাকলেও তার port host-এ প্রকাশিত নয়। Public production setup হলে আলাদা authentication ও network policy দরকার।

Node Exporter host file system read-only পড়ে। cAdvisor privileged mode, host cgroup ও sensitive host mount ব্যবহার করে। Alloy Docker socket পড়ে। **Socket read-only mount হলেই API read-only হয় না**; socket দিয়ে writable API request করা সম্ভব। তাই এগুলো trusted monitoring agent, সাধারণ untrusted application নয়। Production-এ socket proxy ও আরও isolation ভালো উন্নতি হবে।

Application container এই host privilege পায় না। Kubernetes-এ non-root, read-only rootfs, dropped capabilities, seccomp এবং service-account token বন্ধ রাখা আছে।

## ১০. Linux health script ও scheduled execution

[system_health.sh](system_health.sh) CPU sample, memory, সব mounted filesystem-এর usage, load average ও top পাঁচ memory process নেয়। JSON চাইলে `--json` দিন। Warning stderr-এ যায়; তাই stdout JSON ভাঙে না। Threshold flags দিয়ে warning level এবং `--critical` দিয়ে critical level বদলানো যায়।

| Exit code | অর্থ |
| --- | --- |
| 0 | Healthy |
| 1 | Warning threshold ছাড়িয়েছে |
| 2 | Critical threshold ছাড়িয়েছে, argument ভুল বা collection failure |

Read-only squashfs/ISO সবসময় 100% হতে পারে; এগুলো list-এ থাকে, কিন্তু নতুন data রাখার capacity নেই বলে capacity alert থেকে বাদ। Zero-size virtual filesystem-ও বাদ। Writable filesystem-এর আসল usage পরীক্ষা হয়।

Log timestamp-সহ append হয়, size বাড়লে backup rotate হয়। `flock` একসঙ্গে log rotation/write-এর সংঘর্ষ আটকায়। `umask 077` report private রাখে। Service কম privilege-এর user দিয়ে চলে। Timer পাঁচ মিনিট পরপর চলে, সর্বোচ্চ দশ সেকেন্ড jitter থাকে। CI-তে timer-এর নির্ধারিত সময়ের run সত্যি execute হয়ে exit 0 দিয়েছে; শুধু manual command চালিয়ে scheduled success দাবি করা হয়নি।

```bash
bash system_health.sh --help
bash system_health.sh --json --log /tmp/health_log.txt
python3 scripts/test-health.py
systemctl list-timers system-health.timer
journalctl -u system-health.service
```

## ১১. Troubleshooting-এর কার্যকর ক্রম

প্রথমে সমস্যার স্তর নির্ধারণ করুন: app, container, network, Kubernetes না cloud identity। তারপর ওই স্তরের evidence দেখুন। App response না এলে `/health`, container status এবং JSON logs দেখুন। Container বারবার restart হলে exit reason ও resource limit দেখুন। Pod ready না হলে `kubectl describe pod`, events ও probe failure দেখুন। HPA-তে unknown হলে metrics-server ও `kubectl top pods` পরীক্ষা করুন।

Grafana-তে data না এলে datasource provisioning, Prometheus target `up`, Alloy discovery এবং Loki query দেখুন। Proxy-যুক্ত environment-এ internal service name ভুল করে external proxy-তে যাচ্ছে কি না দেখুন। cAdvisor শুধু root metrics দিলে host cgroup delegation পরীক্ষা করুন। এই coding environment-এ ওই সীমাবদ্ধতা বাস্তবে পাওয়া গেছে; GitHub runner-এ একই stack সফল হয়েছে।

AWS সমস্যায় temporary identity, role trust, target tag, SSM agent, bootstrap/cloud-init এবং CloudWatch permission দেখার পরিকল্পনা আছে। কিন্তু এই repository-র বর্তমান AWS execution status না দেখে এগুলো আগে পরীক্ষা হয়েছে বলবেন না।

## ১২. Interview-এর আগে নিজের প্রস্তুতি

নিজে repository clone করে tests, Compose এবং health script চালান। প্রতিটি YAML/HCL field মুখস্থ করার চেয়ে কেন আছে বোঝার চেষ্টা করুন: readiness কেন traffic বন্ধ করে, digest কেন tag-এর চেয়ে নির্দিষ্ট, state lock কেন দরকার, HPA কেন CPU request-এর ওপর নির্ভর করে, log label কেন সীমিত রাখা হয়েছে এবং rollback-এ আগের configuration কেন রাখতে হয়।

Trade-off স্পষ্ট করে বলতে পারবেন: ছোট EC2 সস্তা কিন্তু single point of failure; local Loki সহজ কিন্তু production durability নয়; privileged exporter কার্যকর কিন্তু sensitive; দুই replica rolling update নিরাপদ করতে সাহায্য করে, তবে production-এ আলাদা node/AZ দরকার।

AI ব্যবহার গোপন করবেন না। Code, tests ও documentation তৈরিতে OpenAI Codex সাহায্য করেছে, তারপর actual commands ও CI দিয়ে যাচাই করা হয়েছে। আপনি যা নিজে বুঝেছেন বা চালিয়েছেন শুধু সেটাই নিজের অভিজ্ঞতা হিসেবে বলবেন। AWS approval/identity না থাকায় cloud অংশ এখনও অসম্পূর্ণ—এই সীমাও খোলাখুলি বোঝাতে হবে।
