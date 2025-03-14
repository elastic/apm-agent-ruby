---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/metrics.html
---

# Metrics [metrics]

The Ruby agent tracks various system and application metrics. These metrics will be sent regularly to the APM Server and from there to Elasticsearch. You can adjust the interval by setting [`metrics_interval`](/reference/configuration.md#config-metrics-interval).

The metrics will be stored in the `apm-*` index and have the `processor.event` property set to `metric`.


## System metrics [metrics-system]

**Note:** Metrics from the Ruby agent are Linux only for now.


### `system.cpu.total.norm.pct` [metric-system.cpu.total.norm.pct]

* **Type:** Float
* **Format:** Percent

The percentage of CPU time in states other than Idle and IOWait, normalised by the number of cores.


### `system.memory.total` [metric-system.memory.total]

* **Type:** Long
* **Format:** Bytes

The total memory of the system in bytes.


### `system.memory.actual.free` [metric-system.memory.actual.free]

* **Type:** Long
* **Format:** Bytes

Free memory of the system in bytes.


### `system.process.cpu.total.norm.pct` [metric-system.process.cpu.total.norm.pct]

* **Type:** Float
* **Format:** Percent

The percentage of CPU time spent by the process since the last event. This value is normalized by the number of CPU cores and it ranges from 0 to 100%.


### `system.process.memory.size` [metric-system.process.memory.size]

* **Type:** Long
* **Format:** Bytes

The total virtual memory the process has.


### `system.process.memory.rss.bytes` [metric-system.process.memory.rss.bytes]

* **Type:** Long
* **Format:** Bytes

The Resident Set Size, the amount of memory the process occupies in main memory (RAM).


## Ruby Metrics [metrics-ruby]


### `ruby.gc.count` [metric-ruby.gc.counts]

* **Type:** Integer
* **Format:** Count

The number of Garbage Collection runs since the process started.


### `ruby.threads` [metric-ruby.threads]

* **Type:** Integer
* **Format:** Count

The number of threads belonging to the current process.


### `ruby.heap.slots.live` [metric-ruby.heap.slots.live]

* **Type:** Integer
* **Format:** Slots

Current amount of heap slots that are live.

**NB:** Not currently supported on JRuby.


### `ruby.heap.slots.free` [metric-ruby.heap.slots.free]

* **Type:** Integer
* **Format:** Slots

Current amount of heap slots that are free.

**NB:** Not currently supported on JRuby.


### `ruby.heap.allocations.total` [metrics-ruby.heap.allocations.total]

* **Type:** Integer
* **Format:** Objects

Current amount of allocated objects on the heap.

**NB:** Not currently supported on JRuby.


### `ruby.gc.time` [metrics-ruby.gc.time]

* **Type:** Float
* **Format:** Seconds

The total time spent in garbage collection.

**NB:** You need to enable Ruby’s GC Profiler for this to get reported. You can do this at any time when your application boots by calling `GC::Profiler.enable`.


## JVM Metrics [metrics-jvm-metrics]

The following metrics are available when using JRuby. They use the ruby java API to gather metrics via MXBean.


### `jvm.memory.heap.used` [metric-jvm.memory.heap.used]

* **Type:** Long
* **Format:** Bytes

The amount of used heap memory in bytes.


### `jvm.memory.heap.committed` [metric-jvm.memory.heap.committed]

* **Type:** Long
* **Format:** Bytes

The amount of heap memory in bytes that is committed for the Java virtual machine to use. This amount of memory is guaranteed for the Java virtual machine to use.


### `jvm.memory.heap.max` [metric-jvm.memory.heap.max]

* **Type:** Long
* **Format:** Bytes

The amount of heap memory in bytes that is committed for the Java virtual machine to use. This amount of memory is guaranteed for the Java virtual machine to use.


### `jvm.memory.non_heap.used` [metric-jvm.memory.non_heap.used]

* **Type:** Long
* **Format:** Bytes

The amount of used non-heap memory in bytes.


### `jvm.memory.non_heap.committed` [metric-jvm.memory.non_heap.committed]

* **Type:** Long
* **Format:** Bytes

The amount of non-heap memory in bytes that is committed for the Java virtual machine to use. This amount of memory is guaranteed for the Java virtual machine to use.


### `jvm.memory.non_heap.max` [metric-jvm.memory.non_heap.max]

* **Type:** Long
* **Format:** Bytes

The maximum amount of non-heap memory in bytes that can be used for memory management. If the maximum memory size is undefined, the value is -1.


### `jvm.memory.heap.pool.used` [metric-jvm.memory.heap.pool.used]

* **Type:** Long
* **Format:** Bytes

The amount of used memory in bytes of the memory pool.


### `jvm.memory.heap.pool.committed` [metric-jvm.memory.heap.pool.committed]

* **Type:** Long
* **Format:** Bytes

The amount of memory in bytes that is committed for the memory pool. This amount of memory is guaranteed for this specific pool.


### `jvm.memory.heap.pool.max` [metric-jvm.memory.heap.pool.max]

* **Type:** Long
* **Format:** Bytes

The maximum amount of memory in bytes that can be used for the memory pool.
