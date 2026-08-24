# RN Text benchmark results

Native iOS layout measurements for TextView and React Native's `Text`. See the [benchmark guide](README.md) for the tests and run instructions.

<!-- BEGIN IOS TEXT COMPARISON -->

## September 19, 2026

iPhone 17 Pro simulator, iOS 26.2. React Native 0.84.1, Text Engine 0.2.0, Release build.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

| Test                            | Operations/sample |   RN Text (ms) |  TextView (ms) | TextView / RN |
| ------------------------------- | ----------------: | -------------: | -------------: | ------------: |
| Chat list layout                |               512 | 73.193 ± 1.715 | 26.300 ± 0.789 |        0.359× |
| Plain text creation and layout  |               512 | 66.558 ± 0.587 | 22.943 ± 0.021 |        0.345× |
| Cached layout                   |            98,304 | 32.418 ± 0.020 |  7.614 ± 0.023 |        0.235× |
| Cached layout, two-line limit   |            98,304 | 32.796 ± 0.151 | 20.715 ± 0.050 |        0.632× |
| Styled text creation and layout |               384 | 73.446 ± 1.923 | 28.240 ± 0.482 |        0.384× |

See the [method](README.md#method) for sample counts, timing, and layout checks.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-19T17:50:44.465Z
- Host: Apple M3 Max, macOS 15.7.1, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; simulator SDK 26.2; Node v22.21.1
- Git HEAD: `1f4789f29ef104f9d808840d295352ac9bb75a7a`
- Source checksum (SHA256): `c14e312194e74ca80a9becffe9022298a70baa8ecd32c0f854f57d04b66b4aae`
- Local logs: `benchmarks/.results/ios-comparison-20260919T175044Z-opNyKN`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                            | Implementation | Run | Samples (ms)                                                                                      |
| ------------------------------- | -------------- | --: | ------------------------------------------------------------------------------------------------- |
| Chat list layout                | RN Text        |   1 | 75.728542, 77.414375, 72.979750, 70.369291, 74.396208, 75.959250, 74.907917, 74.712500, 76.295417 |
| Chat list layout                | RN Text        |   2 | 74.922917, 70.319750, 70.660750, 72.136709, 77.266500, 75.393667, 73.193291, 74.448833, 70.092750 |
| Chat list layout                | RN Text        |   3 | 70.514083, 70.338375, 70.493250, 70.935500, 68.977083, 69.668458, 70.704875, 72.070083, 72.675750 |
| Chat list layout                | TextView       |   1 | 26.622959, 27.089583, 25.398750, 25.321667, 27.638708, 26.298375, 27.570916, 27.567250, 27.322833 |
| Chat list layout                | TextView       |   2 | 27.097250, 25.197791, 25.480875, 26.805875, 27.091791, 25.786500, 25.482500, 26.336916, 26.300292 |
| Chat list layout                | TextView       |   3 | 25.126208, 25.186791, 25.697875, 25.280084, 24.692000, 24.650292, 25.038541, 24.900625, 25.722500 |
| Plain text creation and layout  | RN Text        |   1 | 68.884291, 67.040958, 66.558208, 66.055417, 65.456583, 67.712917, 68.578625, 66.190041, 65.314166 |
| Plain text creation and layout  | RN Text        |   2 | 68.544083, 68.662458, 67.145083, 66.630041, 67.294042, 65.328750, 64.885667, 66.121250, 67.989375 |
| Plain text creation and layout  | RN Text        |   3 | 64.772709, 65.323625, 64.799875, 64.486625, 64.969417, 64.928833, 64.948000, 64.538250, 65.118875 |
| Plain text creation and layout  | TextView       |   1 | 22.699333, 22.535958, 22.116458, 22.146250, 23.263542, 23.099458, 23.038292, 23.378541, 22.963500 |
| Plain text creation and layout  | TextView       |   2 | 23.097375, 23.512500, 23.314209, 22.942625, 22.487167, 22.213459, 22.104000, 22.960000, 22.793750 |
| Plain text creation and layout  | TextView       |   3 | 22.372500, 22.123750, 22.130625, 22.172459, 22.433000, 22.181625, 22.218334, 22.040083, 22.830292 |
| Cached layout                   | RN Text        |   1 | 31.607292, 31.092708, 31.288083, 31.082125, 31.097000, 31.469875, 31.156375, 31.235500, 30.808125 |
| Cached layout                   | RN Text        |   2 | 32.185167, 32.275083, 32.048542, 32.345584, 32.532083, 32.417792, 33.114667, 33.821875, 34.266500 |
| Cached layout                   | RN Text        |   3 | 32.212542, 32.663458, 32.465875, 32.676584, 31.935208, 32.506500, 32.176791, 32.437667, 32.236125 |
| Cached layout                   | TextView       |   1 | 7.852208, 7.590708, 7.742791, 7.545417, 7.577083, 7.458125, 7.663916, 7.548125, 7.627667          |
| Cached layout                   | TextView       |   2 | 8.040583, 8.191583, 7.914333, 8.055292, 7.924667, 8.086542, 8.062333, 8.139750, 7.857167          |
| Cached layout                   | TextView       |   3 | 8.050416, 8.075584, 7.881500, 7.663666, 7.508084, 7.430208, 7.614042, 7.530875, 7.530791          |
| Cached layout, two-line limit   | RN Text        |   1 | 32.294500, 32.009167, 32.078208, 33.107458, 34.370167, 34.204917, 33.286125, 32.571958, 32.447333 |
| Cached layout, two-line limit   | RN Text        |   2 | 32.513500, 32.944958, 34.150542, 32.949791, 32.498000, 32.946750, 33.058042, 33.022959, 32.867000 |
| Cached layout, two-line limit   | RN Text        |   3 | 32.604750, 32.795917, 32.734791, 33.306250, 32.856167, 34.474167, 33.252167, 32.367500, 32.015167 |
| Cached layout, two-line limit   | TextView       |   1 | 20.643459, 20.670375, 20.592958, 20.988292, 20.771542, 21.579375, 21.168041, 21.453417, 21.363542 |
| Cached layout, two-line limit   | TextView       |   2 | 20.834625, 21.468584, 21.573708, 20.665208, 20.768834, 20.422209, 20.186625, 20.324916, 20.228334 |
| Cached layout, two-line limit   | TextView       |   3 | 20.318667, 20.266959, 20.767709, 20.715458, 21.199292, 20.982542, 20.473541, 21.235792, 19.875000 |
| Styled text creation and layout | RN Text        |   1 | 74.814250, 77.170625, 75.673916, 75.368625, 75.739500, 74.554208, 77.177333, 72.504833, 72.138250 |
| Styled text creation and layout | RN Text        |   2 | 73.445959, 71.386750, 78.829416, 76.021542, 73.695250, 74.125250, 70.356750, 69.482625, 69.408125 |
| Styled text creation and layout | RN Text        |   3 | 73.053208, 71.906541, 70.612625, 71.434375, 69.983333, 74.922917, 72.299500, 70.500209, 70.023416 |
| Styled text creation and layout | TextView       |   1 | 30.064917, 29.596750, 29.401792, 29.172208, 28.876625, 28.477166, 29.554417, 28.316500, 28.743292 |
| Styled text creation and layout | TextView       |   2 | 27.477083, 28.731708, 28.871209, 28.669167, 27.758042, 28.213584, 27.694292, 27.565042, 27.707708 |
| Styled text creation and layout | TextView       |   3 | 27.859708, 27.966042, 29.314167, 28.898792, 28.239916, 28.284125, 28.263625, 27.733041, 27.978959 |

</details>

<!-- END IOS TEXT COMPARISON -->

<details>
<summary>April 25, 2026: earlier benchmark</summary>

Measured on an iPhone 17 Pro simulator running iOS 26.2, in Release. Recorded at 2026-04-25T03:33:56.950Z from an uncommitted worktree at `928c8d26910423602ae5af5385f85645a0fcf224`. The log is saved locally at `benchmarks/.results/imported-20260425/xcodebuild.log`.

This version did not compare layout results. Its styled-text fixture later produced different heights: 182 pt for RN Text and 185 pt for TextView. It also used smaller batches, always timed RN first, and excluded autorelease-pool cleanup.

The original names below are preserved: “mount” measured shadow-tree layout, and “warm reflow” measured cache queries. All times are milliseconds.

| Scenario                   | Implementation | Operations |   Median |      Min |      Max | Samples                                                       |
| -------------------------- | -------------- | ---------: | -------: | -------: | -------: | ------------------------------------------------------------- |
| fabric_chat_mount_layout   | RN Text        |        128 | 17.76 ms | 17.10 ms | 19.13 ms | 18.50, 17.60, 17.27, 17.10, 17.44, 18.61, 17.76, 17.98, 19.13 |
| fabric_chat_mount_layout   | TextView       |        128 |  6.52 ms |  6.30 ms |  6.98 ms | 6.52, 6.65, 6.98, 6.74, 6.86, 6.33, 6.30, 6.42, 6.35          |
| cold_uniform_chat_layout   | RN Text        |        128 | 15.95 ms | 15.91 ms | 17.21 ms | 17.21, 16.22, 16.24, 15.94, 15.93, 15.95, 15.91, 16.26, 15.92 |
| cold_uniform_chat_layout   | TextView       |        128 |  5.40 ms |  5.39 ms |  5.43 ms | 5.40, 5.42, 5.40, 5.42, 5.43, 5.39, 5.39, 5.40, 5.41          |
| warm_uniform_chat_reflow   | RN Text        |        768 |  0.37 ms |  0.37 ms |  0.41 ms | 0.37, 0.39, 0.41, 0.37, 0.40, 0.37, 0.37, 0.38, 0.37          |
| warm_uniform_chat_reflow   | TextView       |        768 |  0.06 ms |  0.06 ms |  0.06 ms | 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06          |
| warm_truncated_chat_reflow | RN Text        |        768 |  0.36 ms |  0.35 ms |  0.37 ms | 0.37, 0.36, 0.36, 0.36, 0.35, 0.35, 0.36, 0.36, 0.35          |
| warm_truncated_chat_reflow | TextView       |        768 |  0.16 ms |  0.16 ms |  0.17 ms | 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.17, 0.16          |
| cold_rich_inline_layout    | RN Text        |         96 | 17.13 ms | 16.99 ms | 17.90 ms | 17.51, 17.90, 17.07, 17.06, 17.13, 17.13, 17.14, 16.99, 17.05 |
| cold_rich_inline_layout    | TextView       |         96 |  7.01 ms |  6.93 ms |  8.06 ms | 7.01, 6.93, 7.18, 6.95, 8.06, 7.00, 6.96, 7.06, 7.07          |

</details>
