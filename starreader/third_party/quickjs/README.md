<!-- coderabbit-ai-generated:v1 -->

# QuickJS source provenance

This directory contains the core QuickJS 2026-06-04 engine from the official release archive. `provenance.json` records the source URLs and SHA-256 hashes. `LICENSE` is the engine's MIT notice; `JAVA-BINDING-LICENSE` covers the Apache-2.0 Java/JNI binding adapted from zhanghai/quickjs-java revision 547f5b1597.

The Java API is in `android/app/src/main/java/app/cash/quickjs/`; its JNI binding and CMake build are in `android/app/src/main/cpp/`. Original copyright headers are retained. StarReader adds a 64 MiB heap limit, 1 MiB stack limit, 20-second execution deadline, evaluation input bound, native allocation cleanup guards and 16 KiB Android ELF alignment. Only the core engine is built; the upstream `std`/`os` filesystem/network modules are not exposed.

Host JNI tests exercise actual engine evaluation, Unicode, modern JavaScript, compilation, Java callbacks, memory exhaustion and timeout recovery. Android ABI/signature checks are separate from device execution. The runtime does not sandbox the Kotlin extension that invokes it.
