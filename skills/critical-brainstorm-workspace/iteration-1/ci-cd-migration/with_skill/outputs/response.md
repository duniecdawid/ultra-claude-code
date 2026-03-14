# Critical Brainstorm: Migrating from GitHub Actions to Self-Hosted Buildkite

## Let me make sure I understand the proposal

You want to fully migrate 30 repositories from GitHub Actions to self-hosted Buildkite agents. The drivers are GHA rate limits and slow builds. You have a 5-person platform team to execute and maintain this.

I have concerns. Several of them. Let me lay them out.

---

## Risks & Failure Modes

### 1. You're solving a nail problem by buying a new house

GitHub Actions rate limits are real -- 1,000 requests/hour per repo for `GITHUB_TOKEN`, and secondary limits of 100 concurrent requests. But the question you need to answer first is: **why are you hitting them?** Rate limits in GHA are usually a symptom of workflows that make excessive API calls -- chatty scripts checking PR status in loops, mass label operations, or matrix builds that all hit the API simultaneously. Moving to Buildkite doesn't eliminate GitHub API calls; your pipelines will still clone from GitHub, check statuses, and interact with PRs. You might carry the exact same rate limit problems to a new platform.

As for slow builds -- GitHub's hosted runners are 2-vCPU machines with mediocre I/O. That's a known quantity. But "slow" needs diagnosis before treatment. Is it runner startup time (~45-60 seconds on GHA)? Is it dependency installation? Docker layer caching? Test parallelism? Each of these has a targeted fix that doesn't require a full platform migration.

### 2. You're taking on a massive operational burden with a 5-person team

Self-hosted Buildkite means **you own the compute**. That means:

- Provisioning and managing EC2 instances (or whatever infra you use)
- Auto-scaling configuration -- Buildkite's Elastic CI Stack for AWS helps, but it's a CloudFormation stack you need to understand, tune, and debug
- Agent updates and security patching
- Monitoring agent health, disk space, zombie processes
- Network configuration, VPC design, NAT gateways
- Handling spot instance interruptions if you use spot (and you should, for cost)
- Docker image caching and registry management
- Secrets management across your fleet

Multiple sources confirm that self-hosted CI infrastructure typically requires dedicated infrastructure expertise to maintain. Your 5-person platform team presumably has other responsibilities beyond CI. How much of their time can you realistically allocate to this? Industry experience suggests this is not a "set and forget" system -- it's ongoing, messy operational work that compounds over time.

### 3. The migration itself is 3-6 months of real work

You have 30 repos. Every single one needs its workflows rewritten from GitHub Actions YAML to Buildkite pipeline YAML. These are **not** compatible formats. Buildkite offers an AI-based migration tool, but the output requires manual adjustment for agent setup, plugins, and platform-specific features. Reddit's migration (much larger scale) was done by a lean 2-person core team, but they were working full-time on it, and they had Buildkite's professional migration services involved.

For your 30 repos, assume each repo takes 1-3 days of migration work depending on pipeline complexity, plus testing, plus the inevitable edge cases. You're looking at 30-90 engineering days -- conservatively 2-4 months of a single engineer's full-time effort. During migration, you'll be running both systems in parallel, which doubles the maintenance surface.

---

## Hidden Assumptions I Want to Challenge

**Assumption: "Buildkite will be faster."**
It will be... if you throw enough compute at it. Self-hosted agents are only as fast as the machines you provision. If you're cheap about instance sizes, you'll be right back where you started. The speed gains come from your infrastructure budget, not from Buildkite itself.

**Assumption: "Rate limits go away with Buildkite."**
They don't. If your pipelines interact with the GitHub API (and they will -- status checks, PR comments, artifact links), you're still subject to GitHub's API rate limits. Buildkite just changes who's orchestrating the jobs, not which APIs you call.

**Assumption: "Our team can handle the infrastructure."**
5 people is thin for maintaining self-hosted CI across 30 repos while presumably also handling whatever else a platform team handles. Buildkite's own documentation acknowledges that self-hosted requires "multiple infrastructure experts." You need to be honest about whether your team has deep AWS/infrastructure experience or whether this will be a learning exercise on production systems.

**Assumption: "This is a permanent solution."**
Buildkite's pricing is $35/user/month with a 30-user minimum. That's $1,050/month minimum before your AWS compute costs. As your org grows, this scales per-user. Plus your EC2 bill. Plus the engineering time. The total cost of ownership could easily exceed what you'd spend on faster GHA runners.

---

## The Alternative You Should Seriously Consider First

Before committing to a full platform migration, there's a middle path that solves your stated problems with about 5% of the effort:

### Drop-in faster GitHub Actions runners

Services like **Blacksmith**, **Depot**, and **RunsOn** let you keep your existing GitHub Actions workflows unchanged and just swap the runner. You change `runs-on: ubuntu-latest` to `runs-on: blacksmith-2vcpu` and you're done.

What you get:
- **Blacksmith**: 2x faster CPUs, 50% cheaper than GitHub runners, 3,000 free minutes/month, pay-as-you-go at ~$0.004/min. No infrastructure to manage.
- **Depot**: Cache speeds of 1,000 MiB/s (vs GitHub's 145 MiB/s), runner startup under 5 seconds. Purpose-built for Docker-heavy workflows.
- **RunsOn**: Self-hosted on your AWS account, flat license fee of EUR 300/year + AWS spot pricing. 7-17x cheaper than GitHub runners. You get the cost control of self-hosted without leaving the GHA ecosystem.

The critical advantage: **zero migration effort on your pipeline definitions.** All 30 repos keep their existing workflows. You change one line per workflow file. Your team spends a day, not 3 months.

For rate limits specifically: if the issue is GitHub API rate limits, you can fix this with GitHub App tokens (which get 5,000 requests/hour instead of 1,000), request batching, and caching API responses. This is a targeted fix, not a platform migration.

### When Buildkite actually makes sense

Buildkite is the right move when:
- You're at 75+ engineers and need sophisticated pipeline orchestration
- You have complex monorepo build graphs that benefit from dynamic pipelines
- You need deep test analytics and flaky test detection at scale
- You have dedicated CI/CD infrastructure engineers (not a shared platform team)
- GHA's feature set is genuinely limiting you, not just its runner speed

From what you've described -- 30 repos, 5-person team, speed and rate limit issues -- you're not in that category yet.

---

## Tradeoffs Summary

| Dimension | Full Buildkite Migration | Drop-in Runner Swap |
|---|---|---|
| Migration effort | 30-90 engineering days | 1-2 days |
| Ongoing maintenance | High (you own infra) | Low to none |
| Speed improvement | As fast as your budget allows | 2-7x faster immediately |
| Rate limit fix | No -- still hits GitHub API | No -- needs separate fix |
| Vendor lock-in | High (proprietary pipeline format) | Low (still standard GHA) |
| Cost | $1,050/mo minimum + AWS + eng time | $0-300/year + usage |
| Team expertise needed | Deep AWS/infra knowledge | Minimal |
| Reversibility | Painful (rewrite everything back) | Trivial (change one line) |

---

## My Honest Assessment

I think migrating to self-hosted Buildkite for your situation is over-engineering the solution. You're proposing 3-6 months of migration work and a permanent new operational burden to solve problems that have targeted, low-effort fixes. The rate limit problem likely has nothing to do with GHA as a platform, and the speed problem is solved by faster runners with zero workflow changes.

If you migrate and it doesn't solve the rate limits (and it won't, inherently), you'll have spent months of work and still need to fix the actual API call patterns. That's a bad outcome.

**My recommendation**: Start with a drop-in runner replacement (Blacksmith or RunsOn) this week, diagnose and fix the actual rate limit causes, and then in 6 months evaluate whether you've genuinely outgrown GitHub Actions. If you have, migrate to Buildkite from a position of understanding rather than frustration.

---

## Questions I'd Want You to Answer Before Proceeding

1. **Have you profiled where the build time actually goes?** Startup, dependency install, tests, Docker builds -- which phase is slow? This determines the right fix.

2. **What specific rate limits are you hitting?** Is it `GITHUB_TOKEN` limits, secondary rate limits, or the Actions API concurrency limits? Each has a different solution.

3. **What does your platform team actually spend time on today?** If they're already stretched, adding self-hosted CI infra is going to hurt.

4. **Have you tried GitHub's larger runners?** 4-vCPU and 8-vCPU hosted runners exist. More expensive per-minute, but zero operational overhead.

5. **What's your Docker usage like?** If builds are Docker-heavy, Depot specifically might cut your build times in half with zero migration.

6. **Is there a Buildkite champion on the team with real operational experience?** Running it at scale is meaningfully different from a proof of concept.

I'm not saying Buildkite is wrong forever -- I'm saying it's wrong *right now* for the problem as you've described it. Convince me otherwise: what am I missing about your situation that makes a full platform migration the right first move?

---

Sources:
- [Buildkite Migration from GitHub Actions](https://buildkite.com/docs/pipelines/migration/from-githubactions)
- [The Exodus from GitHub Actions to Buildkite (Blacksmith)](https://www.blacksmith.sh/blog/the-exodus-from-github-actions-to-buildkite)
- [GitHub Actions Rate Limits](https://docs.github.com/en/actions/reference/limits)
- [GitHub Actions Slow and Expensive -- Alternatives (RunsOn)](https://runs-on.com/blog/github-actions-slow-and-expensive-what-are-the-alternatives/)
- [Speeding Up GitHub Actions (WarpBuild)](https://www.warpbuild.com/blog/github-actions-speeding-up)
- [Rate Limit Cheatsheet for Self-Hosted Runners](https://www.warpbuild.com/blog/rate-limits-self-hosted-runners)
- [Buildkite Pricing](https://buildkite.com/pricing/)
- [Buildkite Self-Hosted Agents](https://buildkite.com/platform/pipelines/hosting-options/self-hosted-agents/)
- [Buildkite Elastic CI Stack for AWS](https://buildkite.com/docs/agent/self-hosted/aws/elastic-ci-stack/architecture)
- [Managed, Self-Hosted, or Hybrid CI/CD (Buildkite)](https://buildkite.com/resources/blog/managed-self-hosted-or-hybrid-ci-cd-understand-your-options/)
- [GitHub Actions Called 'Internet Explorer of CI'](https://winbuzzer.com/2026/02/06/github-actions-slowly-killing-engineering-teams-circleci-critique-xcxwbn/)
- [GitHub Actions Pricing Changes 2026](https://github.com/resources/insights/2026-pricing-changes-for-github-actions)
- [GitHub Self-Hosted Runners Cost Increase and Alternatives](https://northflank.com/blog/github-pricing-change-self-hosted-alternatives-github-actions)
- [Buildkite Migration Services](https://buildkite.com/resources/migrations/)
- [Blacksmith Pricing](https://www.blacksmith.sh/pricing)
- [RunsOn Pricing](https://runs-on.com/pricing/)
- [Fastest GitHub Actions Runners Benchmark (RunsOn)](https://runs-on.com/benchmarks/github-actions-cpu-performance/)
- [Buildkite vs GitHub Actions Comparison (PeerSpot)](https://www.peerspot.com/products/comparisons/buildkite_vs_github-actions)
- [Reddit Accelerates Innovation with Buildkite](https://buildkite.com/about/press/reddit-accelerates-innovation-and-slashes-build-times-with-buildkite/)
