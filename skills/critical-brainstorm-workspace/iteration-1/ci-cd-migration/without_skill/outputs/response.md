# Migrating from GitHub Actions to Self-Hosted Buildkite

This is a solid move if you're hitting GHA rate limits consistently. Here's how I'd approach it with a 5-person team across 30 repos.

## Before You Start: Validate the Decision

Make sure the pain is actually GHA's fault and not something fixable in-place:

- **Rate limits**: Are these API rate limits (often caused by excessive `actions/checkout` or API calls in workflows) or concurrency limits? GHA Enterprise or larger runners might solve this cheaper than a migration.
- **Slow builds**: Is this from queued jobs waiting for runners, or from the builds themselves? If builds are slow due to bad caching or heavy Docker builds, those problems follow you to Buildkite.
- **Cost comparison**: Buildkite charges per-user ($15/user/month) but you run your own compute. Model out your AWS/GCP costs for self-hosted agents vs. GHA's included minutes + larger runner pricing.

If you've already done this analysis and self-hosted Buildkite is the answer, read on.

## Architecture Decisions to Make Upfront

### Agent Infrastructure

- **Where to run agents**: EC2 with an ASG (Auto Scaling Group) is the most common pattern. Use the [Buildkite Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws) -- it's a CloudFormation template that handles scaling, spot instances, and cleanup.
- **Agent sizing**: Start with a general-purpose instance type (e.g., `m6i.xlarge`) and profile from there. Don't over-optimize on day one.
- **Spot vs. On-Demand**: Spot saves 60-70% but jobs can get interrupted. Use spot for CI (tests, linting) and on-demand for CD (deploys). Buildkite's elastic stack handles this natively.
- **Queue design**: At minimum, have a `default` queue and a `deploy` queue. You can add more later (e.g., `gpu`, `large`, `macos`) but resist the urge to over-segment early.

### Pipeline Configuration

Buildkite pipelines are defined in `.buildkite/pipeline.yml` files (equivalent to `.github/workflows/`). Key differences from GHA:

- Buildkite has **dynamic pipelines** -- a step can emit more steps at runtime. This is extremely powerful for monorepos or conditional builds.
- Steps run on agents, not in ephemeral VMs by default. You need to handle isolation yourself (Docker, or use the elastic stack which boots fresh instances).
- There's no built-in marketplace of actions. You'll use plugins (Buildkite's equivalent) or shell scripts.

## Migration Plan

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Get Buildkite agents running and one repo fully migrated.

1. **Set up Buildkite org and agent infrastructure**
   - Deploy the Elastic CI Stack to your AWS account
   - Configure 2-3 agents to start (scale up later)
   - Set up agent hooks for shared setup (credentials, Docker login, etc.)

2. **Pick your simplest repo as a pilot**
   - Choose something with a straightforward CI pipeline (lint, test, build)
   - Translate the GHA workflow to a Buildkite pipeline
   - Run both in parallel for a week to validate parity

3. **Solve common infrastructure problems once**
   - **Secrets management**: Use Buildkite's agent hooks + AWS Secrets Manager or SSM Parameter Store. Don't put secrets in the Buildkite UI for 30 repos -- that doesn't scale.
   - **Artifact storage**: Buildkite has built-in artifact support backed by S3. Configure the bucket.
   - **Docker caching**: Set up an ECR registry if you don't have one. Use Buildkite's Docker Compose plugin or `docker buildx` with cache mounts.
   - **Notifications**: Buildkite integrates with Slack natively. Set up org-level notification rules.

### Phase 2: Template & Scale (Weeks 3-4)

**Goal**: Create reusable patterns and migrate 10 more repos.

1. **Build pipeline templates**
   - Most of your 30 repos probably share common patterns. Create a shared pipeline library (a dedicated repo with common step definitions).
   - Use Buildkite's `pipeline upload` pattern: a bootstrap script reads your pipeline template and customizes it per-repo.

2. **Batch migrate similar repos**
   - Group repos by type (libraries, services, frontends) and migrate one group at a time.
   - Write a script that generates the initial `.buildkite/pipeline.yml` from your existing `.github/workflows/` files. It won't be perfect, but it saves the boilerplate.

3. **Set up monitoring**
   - Buildkite has a GraphQL API and webhooks -- pipe build metrics to Datadog/Grafana.
   - Track: queue wait time, build duration, agent utilization, spot interruption rate.

### Phase 3: Remaining Repos + Optimization (Weeks 5-8)

**Goal**: Finish migration, optimize, decommission GHA.

1. **Migrate remaining 19 repos** in batches of 5-6 per week.
2. **Run dual pipelines** for at least one week per repo before cutting over.
3. **Optimize agent scaling**: Now you have real data. Tune your ASG min/max, instance types, and spot allocation.
4. **Disable GHA workflows** (don't delete them yet -- just add `if: false` or remove triggers) so you can roll back if needed.
5. **After 2 weeks of stable Buildkite-only operation**, delete the GHA workflow files.

## Common Gotchas

**Things that will bite you if you don't plan for them:**

- **GHA Actions have no Buildkite equivalent**: Anything from `actions/*` or third-party actions needs to be replaced. Common ones:
  - `actions/checkout` -- Buildkite checks out code automatically via the agent's bootstrap
  - `actions/cache` -- Use Docker layer caching or a shared EBS/EFS volume
  - `actions/upload-artifact` -- Use `buildkite-agent artifact upload`
  - `dorny/paths-filter` -- Use Buildkite's dynamic pipelines with a diff check script

- **Branch protection rules**: GHA status checks won't exist anymore. Update your GitHub branch protection to require Buildkite status checks instead (Buildkite reports back to GitHub via its GitHub integration).

- **GITHUB_TOKEN**: GHA injects this automatically. On Buildkite you'll need to create a GitHub App or PAT and distribute it via your secrets management.

- **Concurrency and cancellation**: GHA's `concurrency` groups have no direct equivalent. Use Buildkite's `concurrency` and `concurrency_group` keys on steps, but the semantics differ slightly.

- **Matrix builds**: GHA matrices need to be converted to Buildkite's `parallelism` or dynamic pipeline generation.

## Team Allocation Suggestion

With 5 people:

| Person | Role |
|--------|------|
| 1 | Agent infrastructure owner (AWS, scaling, monitoring) |
| 2 | Pipeline template architect (shared libraries, plugins) |
| 3-5 | Migration engineers (translate workflows, validate parity) |

Rotate the migration engineers so everyone learns the system. The infra and template roles should be dedicated for the first 2-3 weeks.

## What You'll Gain

- **No rate limits**: You own the compute, so no GitHub-imposed throttling.
- **Faster builds**: Self-hosted agents skip the GHA queue. With warm agents, jobs start in seconds instead of 30-60 seconds.
- **Better caching**: Persistent agents or shared volumes mean Docker layers and dependency caches survive between builds.
- **Dynamic pipelines**: Buildkite's `pipeline upload` pattern is genuinely better than GHA's static YAML for complex workflows.

## What You'll Lose

- **Zero-maintenance CI**: You now own servers. Agents need patching, scaling rules need tuning, and when AWS has an issue, your CI is down.
- **GHA marketplace**: The ecosystem of pre-built Actions is larger than Buildkite's plugin ecosystem. You'll write more shell scripts.
- **Simplicity**: GHA is "just YAML in the repo." Buildkite adds infrastructure, agent management, and a separate UI to your stack.

## Quick Example: GHA to Buildkite Translation

**GitHub Actions:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm test
      - run: npm run build
```

**Buildkite equivalent:**
```yaml
steps:
  - label: ":nodejs: Test"
    command:
      - npm ci
      - npm test
      - npm run build
    plugins:
      - docker#v5.11.0:
          image: "node:20"
          propagate-environment: true
```

The Buildkite version is shorter because checkout is automatic and Docker handles the runtime environment. Node caching would be handled at the Docker layer or via a mounted cache volume on the agent.

---

**Bottom line**: This is a 6-8 week project for your team size, not counting optimization. Start with one repo, build your templates, then go wide. The biggest risk isn't the migration itself -- it's underestimating the ongoing operational cost of running your own build infrastructure. Make sure someone on the team genuinely wants to own that.
