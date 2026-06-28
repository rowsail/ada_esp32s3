# esp32s3_stack_usage

Runtime stack high-water-mark measurement with `ESP32S3.Stack_Usage` — the
*measured* companion to the static `./x stack` analysis.

```
./x stack stack_usage          # static: per-frame + worst-case call chains
./x stack stack_usage --run     # + flash and capture the runtime "stack:" line
./x mem   stack_usage           # section sizes + configured bounds
```

`Paint_Env_Stack` fills the unused environment-task stack with a sentinel; after a
workload, `Report` prints `stack: env used=.. free=.. total=.. (NN%)`. The same
`Paint`/`High_Water` primitives take explicit bounds so a task can measure its own
stack. See the book chapter *Static memory & stack bounding*.
