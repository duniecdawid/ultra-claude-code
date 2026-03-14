Let me make sure I understand what you're proposing: You want to use Redis — which you already run for caching — as the backbone for a job queue serving ~50 workers across three distinct job types (image resizing, email sending, webhook delivery). The appeal is simplicity and not adding another piece of infrastructure. You'd skip a dedicated message broker like RabbitMQ.

I did some research before forming an opinion here. I have real concerns about this, and I think you're underweighting the risk.

## The Core Problem: You're Mixing a Cache and a Queue in One Process

This is the thing that worries me most. You already use Redis for caching. Now you want it to also be your job queue. These two workloads have fundamentally conflicting requirements:

- **Caching** wants to evict data freely under memory pressure. That's the whole point.
- **Job queues** must *never* lose data. A dropped job means a user doesn't get their email, a webhook never fires, an image never gets resized.

When Redis hits its `maxmemory` limit, it starts evicting keys based on your eviction policy. If your cache grows (and caches always grow), it can start evicting queue data. Queueing 1 million simple jobs consumes roughly 1 GB of RAM. That's RAM your cache can't use, and vice versa. You'll end up in a situation where you either starve the cache or risk the queue.

**At minimum**, you'd need a dedicated Redis instance for the queue, separate from your caching instance. That already erodes the "we already run it" simplicity argument — you're now running two Redis instances.

## Reliability: Redis Will Lose Your Jobs

This is not theoretical. It's well-documented and has caused real production incidents.

**Worker crash = lost job.** If a worker process crashes, gets OOM-killed, or segfaults while processing a job, that job is gone by default. The UK Government's Email Alert API had a [real incident](https://docs.publishing.service.gov.uk/repos/email-alert-api/adr/adr-009-sidekiq-lost-job-recovery.html) where forcible worker restarts due to memory limits caused lost travel advisory notifications. With 50 workers, the probability that *some* worker crashes on any given day is not small.

**Redis restart = data loss window.** Even with AOF persistence enabled, Redis's default `appendfsync everysec` policy means you can lose up to 1 second of writes on a crash. With RDB snapshots alone, you lose everything since the last snapshot — potentially minutes of queued jobs. And even with `appendfsync always`, power failures and kernel panics can corrupt persistence files. RabbitMQ, by contrast, was designed from the ground up for durable message persistence with publisher confirms and consumer acknowledgments.

**No native acknowledgment protocol.** Redis lists (LPUSH/BRPOP) are fire-and-forget. You pop a message, it's gone from the queue. If your worker dies before finishing, the message is lost. Yes, you can use BRPOPLPUSH to move it to a processing list and implement your own ack/retry logic — but now you're building a message broker on top of Redis, which defeats the simplicity argument.

## BullMQ Helps, But Doesn't Close the Gap

If you're in Node.js, you're probably thinking of BullMQ. It's a solid library that adds retry logic, delayed jobs, and rate limiting on top of Redis. But here are the numbers:

- **BullMQ**: ~15,000 messages/sec, 5ms P50 latency, 25ms P99 latency
- **RabbitMQ**: ~25,000 messages/sec, 3ms P50 latency, 15ms P99 latency

RabbitMQ is faster *and* more reliable. BullMQ's own docs state it guarantees "at least once" delivery in the worst case — but that guarantee is only as strong as the Redis persistence underneath it. RabbitMQ's guarantees are baked into the protocol (AMQP), not bolted on top of a data structure store.

## Your Three Job Types Have Different Requirements

This is where I think you haven't fully mapped the problem:

1. **Image resizing** — Idempotent, retryable, latency-tolerant. This is the *one* workload where Redis-as-queue is genuinely fine. If you lose a job, you can re-enqueue it.

2. **Email sending** — Not safely retryable without deduplication. If you lose the ack but the email sent, you email the user twice. If you lose the job entirely, the user never gets their email. You need either exactly-once semantics or robust deduplication, neither of which Redis gives you natively.

3. **Webhook delivery** — This is the most demanding. Webhooks need reliable retry with exponential backoff, dead-letter handling for permanently failed endpoints, and delivery guarantees your customers depend on. A dropped webhook can cause downstream systems to fall out of sync. RabbitMQ's dead-letter exchanges and per-queue TTL were literally designed for this pattern.

Treating all three job types the same is a mistake. They have different reliability, ordering, and retry requirements.

## The "Simplicity" Argument Is Weaker Than It Looks

You're framing this as "Redis is simpler." Let's stress-test that:

| Concern | Redis + BullMQ | RabbitMQ |
|---|---|---|
| Deployment | Already running (but need dedicated instance) | New service to deploy and monitor |
| Reliability | You build it: ack logic, retry, dead-letter, persistence config | Built-in: acks, retries, DLX, persistence |
| Monitoring | Bolt-on (Bull Board, custom dashboards) | Built-in management UI, Prometheus metrics |
| Multi-language workers | Node.js only (BullMQ), or roll your own protocol | Any language via AMQP |
| Operational complexity | Tune maxmemory, persistence, eviction; manage two instances | Manage one broker with clustering |
| Failure recovery | Manual: find orphaned jobs, replay from backup | Automatic: unacked messages re-queue |

The operational tax of "simple Redis" accumulates. You'll spend weeks over the next year building and debugging the reliability features that RabbitMQ ships out of the box.

## What I'd Actually Recommend

**Use RabbitMQ for email and webhook delivery. Use Redis (BullMQ) for image resizing if you want.**

This isn't a compromise — it's the right tool for each job. Your image resizing pipeline is a great fit for a lightweight Redis queue. Your email and webhook pipelines need delivery guarantees that Redis fundamentally wasn't built to provide.

If you truly can't stomach adding RabbitMQ, the second-best option is a managed queue service like AWS SQS — zero operational overhead, built-in reliability, and you don't have to become a message broker expert.

## Questions I'd Push You On

1. **What happens when a webhook delivery job is permanently lost?** Do your customers have a way to detect and recover from missed webhooks? If not, you're building on a foundation that can silently drop data.

2. **Have you sized the memory budget?** With 50 workers and three job types, what's your expected queue depth during peak load? During a downstream outage (e.g., email provider down for 30 minutes), how many jobs will back up, and how much RAM will that consume?

3. **Are all 50 workers Node.js?** If you ever need workers in another language (say, a Python image processing pipeline), BullMQ won't help you. RabbitMQ's AMQP protocol is language-agnostic.

4. **What's your Redis HA story?** Are you running Redis Sentinel or Cluster? A single Redis instance is a single point of failure for your entire job processing pipeline. If Redis goes down, no images resize, no emails send, no webhooks fire — *and* your cache is gone too (unless you've already separated them).

I feel strongly that Redis-as-queue is the right call for maybe one of your three workloads, and a real risk for the other two. The simplicity you gain on day one will cost you in reliability incidents over the next year. I'd rather you spend a day setting up RabbitMQ now than spend a week debugging lost webhooks in three months.

What's your take? Am I overweighting the reliability concern for your use case, or does this change how you're thinking about it?

---

Sources:
- [AWS: RabbitMQ vs Redis](https://aws.amazon.com/compare/the-difference-between-rabbitmq-and-redis/)
- [BullMQ vs RabbitMQ Comparison](https://medium.com/@vetonkaso/bullmq-vs-rabbitmq-choosing-the-right-queue-system-for-your-backend-cbe4d4f6f7a5)
- [BullMQ vs Other Queue Systems (RabbitMQ, SQS)](https://oneuptime.com/blog/post/2026-01-21-bullmq-vs-other-queues/view)
- [Redis Persistence: RDB vs AOF](https://redis.io/tutorials/operate/redis-at-scale/persistence-and-durability/)
- [Sidekiq Reliability Wiki](https://github.com/sidekiq/sidekiq/wiki/Reliability)
- [GOV.UK: Sidekiq Lost Job Recovery ADR](https://docs.publishing.service.gov.uk/repos/email-alert-api/adr/adr-009-sidekiq-lost-job-recovery.html)
- [Redis vs RabbitMQ vs SQS Queue Decision](https://medium.com/@SmokeAndStrive/redis-vs-rabbitmq-vs-sqs-the-queue-decision-nobody-tells-you-about-588b5ea0a2fd)
- [Reliable Message Queues with Redis Streams](https://oneuptime.com/blog/post/2026-01-21-redis-streams-message-queues/view)
- [DragonflyDB: BullMQ vs RabbitMQ](https://www.dragonflydb.io/guides/bullmq-vs-rabbitmq)
