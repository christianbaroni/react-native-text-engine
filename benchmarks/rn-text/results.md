# RN Text benchmark results

Latest native layout measurements for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 19, 2026. iPhone 17 Pro simulator, iOS 26.2. React Native 0.84.1, Text Engine 0.2.0, Release build.

| Test                            | Operations/sample |   RN Text (ms) |  TextView (ms) | TextView / RN |
| ------------------------------- | ----------------: | -------------: | -------------: | ------------: |
| Chat list layout                |               512 | 73.193 ± 1.715 | 26.300 ± 0.789 |        0.359× |
| Plain text creation and layout  |               512 | 66.558 ± 0.587 | 22.943 ± 0.021 |        0.345× |
| Cached layout                   |            98,304 | 32.418 ± 0.020 |  7.614 ± 0.023 |        0.235× |
| Cached layout, two-line limit   |            98,304 | 32.796 ± 0.151 | 20.715 ± 0.050 |        0.632× |
| Styled text creation and layout |               384 | 73.446 ± 1.923 | 28.240 ± 0.482 |        0.384× |

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

## Android

September 19, 2026. Pixel 6, Android 14 (API 34). React Native 0.84.1, Text Engine 0.2.0, Release build.

| Test                            | Operations/sample |    RN Text (ms) |   TextView (ms) | TextView / RN |
| ------------------------------- | ----------------: | --------------: | --------------: | ------------: |
| Chat list layout                |               512 | 159.643 ± 0.091 | 107.733 ± 0.120 |        0.675× |
| Plain text creation and layout  |               512 | 142.831 ± 0.118 |  95.856 ± 0.115 |        0.671× |
| Cached layout                   |            98,304 |  59.692 ± 0.168 |  48.736 ± 0.542 |        0.816× |
| Cached layout, two-line limit   |            98,304 |  59.721 ± 0.506 |  63.121 ± 0.016 |        1.057× |
| Styled text creation and layout |               384 | 307.031 ± 0.042 | 183.252 ± 0.087 |        0.597× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-19T19:56:38.434Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.0.0; Node v22.21.1
- APK SHA256: `b31ce9e1fc404b686096a2d65634704e0ee8204f392770275c1f8a544aa1f189`
- Git HEAD: `08ef2d85f521a584f438af9b96404a50435b005d`
- Source checksum (SHA256): `d54cc2c23030b296bbeb5b59c49f6f8dd33720222907b478eee11585ecf07359`
- Local logs: `benchmarks/.results/android-comparison-20260919T195638Z-hPGgXH`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                            | Implementation | Run | Samples (ms)                                                                                               |
| ------------------------------- | -------------- | --: | ---------------------------------------------------------------------------------------------------------- |
| Chat list layout                | RN Text        |   1 | 160.383464, 159.405965, 158.349366, 159.627075, 158.758179, 162.545573, 157.910888, 159.349284, 158.874227 |
| Chat list layout                | RN Text        |   2 | 163.248780, 159.734049, 159.364095, 159.041585, 160.013712, 159.116536, 159.703370, 161.396688, 159.872681 |
| Chat list layout                | RN Text        |   3 | 158.827067, 159.643311, 158.623413, 159.817708, 162.922566, 159.535441, 160.566569, 161.602051, 159.155517 |
| Chat list layout                | TextView       |   1 | 107.733073, 107.915731, 107.987712, 106.818116, 108.021362, 107.664063, 107.958944, 107.675211, 107.276327 |
| Chat list layout                | TextView       |   2 | 108.276937, 107.671225, 107.255087, 107.679565, 107.413615, 107.554728, 107.511190, 108.110393, 107.523193 |
| Chat list layout                | TextView       |   3 | 108.375569, 107.396159, 107.781006, 107.511352, 108.081828, 107.610149, 107.911255, 108.126424, 107.852824 |
| Plain text creation and layout  | RN Text        |   1 | 142.633301, 145.996908, 142.839843, 142.888794, 144.928141, 142.591553, 142.567912, 142.546102, 142.104655 |
| Plain text creation and layout  | RN Text        |   2 | 142.948852, 144.109497, 142.940430, 142.663004, 145.490845, 141.701253, 143.174683, 142.652100, 143.371378 |
| Plain text creation and layout  | RN Text        |   3 | 142.146607, 146.243571, 142.501221, 142.831259, 142.224203, 142.973714, 142.239339, 143.210084, 144.196411 |
| Plain text creation and layout  | TextView       |   1 | 95.926433, 96.520671, 95.982951, 95.939006, 95.637166, 96.031210, 95.998739, 95.971232, 95.872843          |
| Plain text creation and layout  | TextView       |   2 | 95.667114, 93.992960, 95.810506, 95.692871, 95.628092, 95.798584, 95.582031, 96.017049, 97.572306          |
| Plain text creation and layout  | TextView       |   3 | 95.730102, 95.878865, 95.867391, 95.855957, 96.983927, 95.134521, 95.769490, 95.744710, 95.993082          |
| Cached layout                   | RN Text        |   1 | 59.691529, 60.417766, 59.033855, 60.445801, 59.190227, 59.838379, 59.450561, 59.804932, 59.020630          |
| Cached layout                   | RN Text        |   2 | 60.251709, 59.113363, 59.859416, 59.323974, 60.820923, 59.557251, 60.050456, 59.317912, 60.094930          |
| Cached layout                   | RN Text        |   3 | 59.008586, 60.234619, 58.923381, 59.696736, 58.887207, 59.913289, 58.452637, 60.214925, 58.877523          |
| Cached layout                   | TextView       |   1 | 49.169678, 48.361939, 54.553142, 48.267700, 48.747803, 48.337280, 58.537395, 48.292155, 48.735514          |
| Cached layout                   | TextView       |   2 | 53.963175, 49.654094, 49.371134, 49.598836, 55.649251, 50.473551, 49.338663, 49.937174, 49.441243          |
| Cached layout                   | TextView       |   3 | 50.974488, 48.742024, 48.253337, 48.081055, 48.113932, 53.171061, 48.193237, 47.975830, 48.124878          |
| Cached layout, two-line limit   | RN Text        |   1 | 59.584676, 60.481079, 59.720906, 60.314819, 59.371948, 60.409423, 59.342895, 60.472209, 59.719075          |
| Cached layout, two-line limit   | RN Text        |   2 | 60.227254, 59.249553, 60.604248, 59.455485, 60.588461, 59.642863, 60.320149, 59.260050, 60.592123          |
| Cached layout, two-line limit   | RN Text        |   3 | 58.525350, 56.611735, 59.568155, 60.382324, 56.426229, 59.664348, 58.815145, 59.795532, 58.772339          |
| Cached layout, two-line limit   | TextView       |   1 | 63.097901, 62.628459, 63.926635, 67.535929, 63.120686, 62.780843, 63.911336, 62.758708, 63.494588          |
| Cached layout, two-line limit   | TextView       |   2 | 62.766886, 63.167644, 69.753581, 63.136596, 62.713298, 69.364055, 62.392863, 62.723063, 68.452922          |
| Cached layout, two-line limit   | TextView       |   3 | 66.891521, 63.993368, 62.419068, 66.566488, 61.455485, 61.395915, 68.271647, 62.048950, 62.344402          |
| Styled text creation and layout | RN Text        |   1 | 307.073243, 306.940471, 310.784505, 307.328573, 308.490601, 308.147258, 305.513876, 302.499471, 301.133626 |
| Styled text creation and layout | RN Text        |   2 | 306.137654, 305.084554, 305.012777, 309.082601, 306.870077, 305.132447, 301.449585, 298.934815, 299.841512 |
| Styled text creation and layout | RN Text        |   3 | 308.044067, 306.641276, 310.543457, 306.657186, 307.031210, 307.125326, 304.707397, 305.303671, 312.270915 |
| Styled text creation and layout | TextView       |   1 | 187.638224, 185.008464, 182.984904, 187.074707, 183.252320, 183.031454, 184.271607, 182.898356, 182.987874 |
| Styled text creation and layout | TextView       |   2 | 182.718831, 182.604655, 184.114014, 183.378214, 183.020996, 182.408447, 184.007324, 182.915568, 184.848145 |
| Styled text creation and layout | TextView       |   3 | 187.031047, 184.824829, 183.339600, 184.372884, 182.493530, 182.341024, 182.457723, 184.415405, 182.037638 |

</details>
