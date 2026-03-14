Redis is a reasonable choice for this, and honestly for the workloads you described -- image resizing, email sending, webhook delivery -- it will probably work fine. But there are some real trade-offs worth thinking through before you commit.

## Where Redis works well here

You already run it, your team knows it, and adding a new piece of infrastructure (RabbitMQ, plus its Erlang runtime, management UI, clustering config) has a real cost. For a job queue specifically, Redis with a library like BullMQ (Node), Celery (Python), or Sidekiq (Ruby) gives you solid primitives: delayed jobs, retries, priority queues, dead letter handling. These libraries have been battle-tested at significant scale.

50 workers is not a scary number. Redis can handle the throughput for this easily -- it's not the bottleneck.

## Where it gets uncomfortable

The concerns are less about performance and more about durability and operational behavior under failure:

**Message acknowledgment and redelivery.** RabbitMQ has proper consumer acknowledgments baked into the protocol. If a worker crashes mid-task, the message goes back to the queue automatically. Redis-based queues simulate this (typically using BRPOPLPUSH into a processing list, then cleanup), but the failure modes are more subtle. You need to understand how your chosen library handles visibility timeouts, stale locks, and crash recovery -- and test those paths.

**Persistence gaps.** Redis persistence (RDB snapshots, AOF) is designed for best-effort durability, not transactional guarantees. If Redis crashes between receiving a job and the next fsync, that job is gone. For email sending, that might mean a user never gets their password reset. For webhook delivery, that might mean a payment notification is silently dropped. RabbitMQ with publisher confirms and durable queues gives you stronger guarantees here.

**Backpressure and memory.** Redis holds everything in memory. If your webhook endpoint goes down and jobs start piling up, your queue grows unboundedly in RAM. RabbitMQ can page messages to disk. With Redis, a sustained spike in one queue can cause memory pressure that affects your caching layer too -- since they share the same instance. This is probably the most operationally dangerous overlap.

**Routing complexity.** Right now you have three job types. If that grows to 15, and you need things like fan-out (one event triggers multiple consumers), topic-based routing, or priority across queues, you are going to be rebuilding features that come out of the box with a message broker. Redis queues are point-to-point; anything more complex is application-level wiring.

## What I would actually do

Use Redis, but with guardrails:

1. **Run a separate Redis instance for queues.** Do not share it with your cache. This is the single most important thing. A cache eviction policy (like `allkeys-lru`) and a job queue are fundamentally incompatible on the same instance. It is also free isolation against memory pressure from queue backlog affecting cache hit rates.

2. **Pick a mature queue library** and learn its failure semantics. BullMQ, Sidekiq, and Celery all handle the ack/retry/dead-letter patterns well enough. Do not roll your own with raw LPUSH/BRPOP.

3. **Set memory limits and alerts.** Configure `maxmemory` on the queue instance and set alerts well before it is hit. If queues back up, you want to know before Redis starts rejecting writes.

4. **For webhook delivery specifically, consider idempotency carefully.** At-least-once delivery means your webhook consumers might process the same job twice after a crash recovery. Make sure the downstream effects are idempotent or you have deduplication in place.

5. **Revisit if requirements change.** If you later need guaranteed ordering across partitions, complex routing topologies, or multi-datacenter replication of your queue, that is when RabbitMQ (or Kafka, depending on the pattern) starts earning its operational overhead.

The "proper message broker" framing can be misleading. RabbitMQ is not inherently more correct -- it just gives you stronger defaults. Redis with a good library and careful operations can absolutely serve 50 workers processing async tasks. The teams that get burned are usually the ones who share the queue Redis with the cache Redis, or who do not think about what happens when consumers fall behind.
