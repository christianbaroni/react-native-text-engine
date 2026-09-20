# RN Text benchmark results

Latest native layout measurements for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 20, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.2.0, Release build.

| Test                            | Operations/sample |   RN Text (ms) |  TextView (ms) | TextView / RN |
| ------------------------------- | ----------------: | -------------: | -------------: | ------------: |
| Chat list layout                |               512 | 66.029 ± 0.772 | 29.424 ± 0.648 |        0.446× |
| Plain text creation and layout  |               512 | 63.934 ± 0.502 | 28.627 ± 0.546 |        0.448× |
| Cached layout                   |            98,304 | 29.678 ± 0.199 |  5.439 ± 0.176 |        0.183× |
| Cached layout, two-line limit   |            98,304 | 29.713 ± 0.162 | 14.005 ± 0.278 |        0.471× |
| Styled text creation and layout |               384 | 62.663 ± 0.578 | 27.600 ± 0.529 |        0.440× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T01:33:11.124Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `6a0896b92d03daf0f592e7317438dc5be2d0da34`
- Source checksum (SHA256): `47ff9fd6b241820c783dd528b950d8192ec4096143bc30e37a5cb0da819d2e1f`
- Local logs: `benchmarks/.results/ios-comparison-20260920T013311Z-cMr4wd`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                            | Implementation | Run | Samples (ms)                                                                                      |
| ------------------------------- | -------------- | --: | ------------------------------------------------------------------------------------------------- |
| Chat list layout                | RN Text        |   1 | 67.528375, 65.337209, 65.200458, 65.188750, 65.121667, 64.972000, 64.816458, 64.953416, 64.852959 |
| Chat list layout                | RN Text        |   2 | 65.085750, 66.029333, 65.637000, 65.597417, 66.214875, 66.081917, 66.114583, 65.747041, 66.908167 |
| Chat list layout                | RN Text        |   3 | 66.801084, 66.068125, 67.095958, 67.364709, 65.689042, 67.518084, 67.187125, 66.166458, 66.324041 |
| Chat list layout                | TextView       |   1 | 29.119667, 29.025625, 28.935500, 28.708750, 28.763959, 28.685125, 28.693792, 28.776875, 28.940084 |
| Chat list layout                | TextView       |   2 | 29.329333, 29.296875, 29.799208, 29.160375, 29.512375, 29.424375, 29.976791, 29.299708, 29.828875 |
| Chat list layout                | TextView       |   3 | 29.697917, 29.126625, 30.353000, 30.111291, 29.924875, 30.074375, 30.077792, 30.400833, 30.639667 |
| Plain text creation and layout  | RN Text        |   1 | 62.519542, 62.577500, 62.270542, 62.446667, 62.258541, 62.460500, 62.380000, 62.610833, 62.411250 |
| Plain text creation and layout  | RN Text        |   2 | 64.147291, 63.933958, 64.332292, 63.577792, 63.835542, 63.863458, 65.452709, 63.635250, 64.366750 |
| Plain text creation and layout  | RN Text        |   3 | 63.136667, 64.915834, 64.300458, 63.825458, 64.436125, 64.458375, 63.888750, 64.931708, 64.728000 |
| Plain text creation and layout  | TextView       |   1 | 27.526875, 27.454666, 27.556834, 27.622916, 27.498375, 27.445459, 27.682583, 27.661541, 27.616459 |
| Plain text creation and layout  | TextView       |   2 | 28.067959, 28.444625, 28.764333, 28.157166, 28.978875, 28.781125, 28.454584, 28.829833, 28.627042 |
| Plain text creation and layout  | TextView       |   3 | 29.215959, 29.145000, 29.173541, 28.352667, 29.466625, 28.972125, 27.974750, 29.982750, 29.998875 |
| Cached layout                   | RN Text        |   1 | 28.077167, 28.028625, 28.478833, 28.291208, 28.165125, 28.414125, 28.242333, 28.222666, 28.555667 |
| Cached layout                   | RN Text        |   2 | 30.343708, 30.011917, 29.877250, 29.767083, 29.852875, 29.877375, 29.922166, 29.878959, 29.873584 |
| Cached layout                   | RN Text        |   3 | 29.998292, 28.930167, 29.678125, 29.929625, 29.373958, 28.503708, 29.654833, 30.902500, 29.820000 |
| Cached layout                   | TextView       |   1 | 5.277625, 5.282625, 5.263833, 5.228750, 4.978709, 5.319417, 5.504333, 5.191875, 5.098083          |
| Cached layout                   | TextView       |   2 | 5.339875, 5.439416, 5.737334, 5.906542, 5.314000, 5.340750, 5.629750, 5.467666, 5.327875          |
| Cached layout                   | TextView       |   3 | 5.661541, 5.887167, 5.587375, 5.386708, 5.792750, 5.988583, 5.474625, 6.605042, 5.751334          |
| Cached layout, two-line limit   | RN Text        |   1 | 28.199208, 27.906708, 28.631791, 28.202750, 28.739167, 28.401625, 28.542833, 28.998209, 28.220542 |
| Cached layout, two-line limit   | RN Text        |   2 | 29.795000, 30.080333, 29.914333, 29.313583, 29.652250, 29.907125, 29.297459, 29.238750, 29.712625 |
| Cached layout, two-line limit   | RN Text        |   3 | 30.326250, 29.684250, 30.026625, 29.211709, 29.874750, 29.715375, 30.294833, 29.803000, 30.059542 |
| Cached layout, two-line limit   | TextView       |   1 | 13.726542, 13.844542, 13.328083, 13.824500, 13.208416, 13.575083, 13.741708, 13.358792, 13.772333 |
| Cached layout, two-line limit   | TextView       |   2 | 14.004958, 13.930250, 13.966542, 14.336583, 13.882042, 13.779041, 14.294917, 14.257792, 14.132250 |
| Cached layout, two-line limit   | TextView       |   3 | 14.870125, 14.328417, 14.557917, 14.679834, 14.675667, 14.692750, 14.853333, 14.800166, 15.097625 |
| Styled text creation and layout | RN Text        |   1 | 60.953041, 61.116709, 60.837375, 60.902334, 60.896334, 61.126542, 61.004542, 61.201792, 61.311084 |
| Styled text creation and layout | RN Text        |   2 | 62.211250, 62.977916, 62.903917, 61.836875, 62.986250, 62.859750, 62.602417, 62.110208, 62.663333 |
| Styled text creation and layout | RN Text        |   3 | 66.699041, 65.026500, 63.241084, 63.068834, 63.148208, 62.015166, 63.731750, 63.641583, 63.148917 |
| Styled text creation and layout | TextView       |   1 | 26.904291, 27.143750, 26.959458, 26.846417, 27.047084, 26.940708, 27.120250, 26.862542, 26.900000 |
| Styled text creation and layout | TextView       |   2 | 26.795458, 27.778958, 27.518875, 27.757125, 27.652083, 27.596208, 27.562458, 27.600250, 27.683750 |
| Styled text creation and layout | TextView       |   3 | 28.609500, 28.637541, 28.099959, 28.129000, 28.428417, 27.721250, 28.503209, 27.796667, 27.639584 |

</details>

## Android

September 20, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.2.0, Release build.

### RN Text with default layout

| Test                                     | Operations/sample |    RN Text (ms) |   TextView (ms) | TextView / RN |
| ---------------------------------------- | ----------------: | --------------: | --------------: | ------------: |
| Chat list layout                         |               512 | 156.044 ± 0.155 | 103.555 ± 0.927 |        0.664× |
| Plain text creation and layout           |               512 | 141.442 ± 1.777 |  95.037 ± 0.111 |        0.672× |
| Repeated manager queries                 |             6,144 |   4.088 ± 0.010 |   3.110 ± 0.029 |        0.761× |
| Repeated manager queries, two-line limit |             6,144 |   4.088 ± 0.012 |   4.149 ± 0.128 |        1.015× |
| Styled text creation and layout          |               384 | 317.921 ± 0.684 | 189.335 ± 0.701 |        0.596× |

### RN Text with prepared layout

| Test                                     | Operations/sample |      RN Text (ms) |   TextView (ms) | TextView / RN |
| ---------------------------------------- | ----------------: | ----------------: | --------------: | ------------: |
| Chat list layout                         |               512 |   158.804 ± 0.377 | 101.990 ± 0.092 |        0.642× |
| Plain text creation and layout           |               512 |   144.779 ± 0.380 |  95.116 ± 0.108 |        0.657× |
| Repeated manager queries                 |             6,144 | 1731.496 ± 10.104 |   3.005 ± 0.004 |        0.002× |
| Repeated manager queries, two-line limit |             6,144 |  1805.019 ± 1.903 |   3.915 ± 0.003 |        0.002× |
| Styled text creation and layout          |               384 |   297.870 ± 0.029 | 175.140 ± 0.664 |        0.588× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T01:24:51.099Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `f1bd09d7c84848a25db4ebb8bd9c575679890eb76dde600600ebd7eb718054cf`
- Git HEAD: `6a0896b92d03daf0f592e7317438dc5be2d0da34`
- Source checksum (SHA256): `6ba191265860ee5723edecc8bbf794e3c0884dd88df5dab4caac1c2dc393ada2`
- Local logs: `benchmarks/.results/android-comparison-20260920T012451Z-JTN5m7`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                                     | Implementation | RN configuration | Run | Samples (ms)                                                                                                        |
| ---------------------------------------- | -------------- | ---------------- | --: | ------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                         | RN Text        | Default          |   1 | 185.553671, 156.085693, 157.427897, 378.704305, 402.731445, 234.617879, 157.292033, 156.472331, 156.443359          |
| Chat list layout                         | RN Text        | Default          |   2 | 147.038086, 152.541097, 155.105184, 153.630453, 167.122802, 156.044434, 156.986450, 156.226318, 157.832601          |
| Chat list layout                         | RN Text        | Default          |   3 | 156.361369, 154.374512, 153.244751, 155.844564, 155.889811, 160.150187, 157.145427, 153.327637, 156.186117          |
| Chat list layout                         | RN Text        | Prepared         |   1 | 158.803630, 164.394734, 159.942709, 160.052205, 157.355673, 158.409912, 158.082316, 161.814087, 157.107137          |
| Chat list layout                         | RN Text        | Prepared         |   2 | 157.658691, 159.461670, 159.895711, 158.785197, 159.619345, 162.864380, 159.873251, 159.384196, 167.938884          |
| Chat list layout                         | RN Text        | Prepared         |   3 | 157.987589, 158.426880, 157.423665, 159.288900, 159.101359, 157.758789, 158.532389, 157.885010, 159.044271          |
| Chat list layout                         | TextView       | Default          |   1 | 102.942058, 103.882161, 140.391399, 270.024903, 263.723023, 262.865438, 104.170207, 104.044393, 104.481975          |
| Chat list layout                         | TextView       | Default          |   2 | 98.066854, 103.111247, 103.321899, 102.312296, 102.982707, 101.865234, 102.508789, 103.884928, 100.444173           |
| Chat list layout                         | TextView       | Default          |   3 | 102.417562, 103.871745, 103.986694, 104.256389, 101.304525, 102.191406, 103.739502, 102.863281, 103.554687          |
| Chat list layout                         | TextView       | Prepared         |   1 | 102.319865, 101.876262, 102.081950, 102.044068, 102.949056, 101.614380, 101.972494, 105.288575, 103.831136          |
| Chat list layout                         | TextView       | Prepared         |   2 | 101.454183, 101.989909, 102.131267, 102.308594, 101.704793, 102.454101, 101.914714, 102.283244, 101.969320          |
| Chat list layout                         | TextView       | Prepared         |   3 | 101.307210, 102.927816, 101.427165, 101.337728, 101.700724, 101.628703, 103.633951, 101.875814, 101.479045          |
| Plain text creation and layout           | RN Text        | Default          |   1 | 134.512817, 134.977580, 134.491251, 134.805624, 136.835856, 135.318481, 134.453979, 135.237020, 137.239909          |
| Plain text creation and layout           | RN Text        | Default          |   2 | 141.442220, 140.112142, 141.454631, 143.612915, 140.422241, 142.138347, 141.294840, 143.628296, 141.416300          |
| Plain text creation and layout           | RN Text        | Default          |   3 | 141.976278, 144.229370, 143.152588, 141.419312, 144.268636, 144.608195, 145.192586, 143.219604, 141.033488          |
| Plain text creation and layout           | RN Text        | Prepared         |   1 | 145.606405, 143.711345, 145.364665, 144.570842, 144.778971, 144.542928, 144.362915, 144.861125, 145.941650          |
| Plain text creation and layout           | RN Text        | Prepared         |   2 | 146.706502, 145.159058, 148.509602, 143.972209, 144.627930, 145.379314, 144.688110, 144.438029, 145.274495          |
| Plain text creation and layout           | RN Text        | Prepared         |   3 | 143.768554, 144.551269, 146.198324, 144.071819, 143.552775, 144.310710, 143.809163, 145.293782, 142.972616          |
| Plain text creation and layout           | TextView       | Default          |   1 | 91.829387, 93.589804, 91.310669, 91.382162, 91.421102, 91.189942, 91.411092, 92.895060, 95.867839                   |
| Plain text creation and layout           | TextView       | Default          |   2 | 95.134807, 93.055868, 94.947063, 95.111369, 92.885864, 95.261678, 104.856405, 95.037435, 94.944743                  |
| Plain text creation and layout           | TextView       | Default          |   3 | 95.148438, 95.128663, 94.800171, 95.179810, 94.062174, 94.958577, 95.272990, 99.357707, 95.508992                   |
| Plain text creation and layout           | TextView       | Prepared         |   1 | 97.014201, 96.252767, 94.091716, 95.207520, 95.008952, 95.200928, 94.421550, 94.858318, 95.116333                   |
| Plain text creation and layout           | TextView       | Prepared         |   2 | 97.371867, 95.224283, 95.228027, 94.968669, 95.084025, 94.789958, 96.870483, 94.958903, 95.497681                   |
| Plain text creation and layout           | TextView       | Prepared         |   3 | 94.626872, 94.506999, 94.998210, 94.832072, 94.570109, 93.607137, 94.616333, 94.713216, 94.596558                   |
| Repeated manager queries                 | RN Text        | Default          |   1 | 4.076579, 4.722575, 4.078247, 4.403972, 4.039510, 4.440104, 4.048788, 4.573608, 4.042358                            |
| Repeated manager queries                 | RN Text        | Default          |   2 | 4.427327, 3.959269, 4.414062, 3.947021, 4.390787, 3.939901, 4.340983, 4.016357, 4.349080                            |
| Repeated manager queries                 | RN Text        | Default          |   3 | 4.080851, 4.474610, 4.087321, 4.493774, 4.055990, 4.533447, 4.071655, 4.521688, 4.087890                            |
| Repeated manager queries                 | RN Text        | Prepared         |   1 | 1736.919231, 1730.806804, 1717.235922, 2677.476767, 1744.776205, 2517.862591, 1746.791587, 1757.072673, 1723.184774 |
| Repeated manager queries                 | RN Text        | Prepared         |   2 | 1731.531617, 1732.135092, 1729.449260, 1727.361492, 1709.675782, 1816.917115, 2477.031861, 1731.496176, 1709.527996 |
| Repeated manager queries                 | RN Text        | Prepared         |   3 | 1725.157268, 1720.662884, 1713.997478, 1721.392619, 1715.636313, 1727.084108, 1725.578940, 1720.774252, 1725.081218 |
| Repeated manager queries                 | TextView       | Default          |   1 | 3.225585, 3.024659, 3.202515, 3.060913, 3.257121, 3.064942, 3.380615, 3.073445, 3.275798                            |
| Repeated manager queries                 | TextView       | Default          |   2 | 3.078735, 3.196208, 3.072470, 3.196981, 3.075154, 3.156413, 3.081583, 3.186565, 3.069703                            |
| Repeated manager queries                 | TextView       | Default          |   3 | 3.125325, 3.091838, 3.130696, 3.064534, 3.110189, 3.022746, 3.122639, 3.033488, 3.128540                            |
| Repeated manager queries                 | TextView       | Prepared         |   1 | 3.016927, 2.991536, 2.973714, 2.889567, 2.978394, 2.915812, 2.939087, 2.914592, 3.028646                            |
| Repeated manager queries                 | TextView       | Prepared         |   2 | 2.979492, 3.023641, 3.005453, 3.019124, 2.980184, 9.884399, 9.908691, 2.976563, 2.999227                            |
| Repeated manager queries                 | TextView       | Prepared         |   3 | 3.024659, 2.954875, 3.015544, 2.968709, 3.030558, 2.963786, 3.009196, 2.981242, 3.108114                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   1 | 4.003133, 4.566162, 4.047851, 4.659098, 3.996298, 4.511556, 4.009765, 4.514730, 4.028849                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   2 | 4.134481, 3.928304, 4.313436, 3.973226, 4.509603, 3.916788, 4.211100, 3.903728, 4.100057                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   3 | 4.087850, 4.331340, 3.885376, 4.347005, 3.893921, 4.398763, 3.875203, 4.429891, 3.937378                            |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   1 | 1809.498902, 1825.071534, 1804.291383, 1799.641114, 1815.364991, 1822.254558, 1807.126099, 1808.880982, 1820.940715 |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   2 | 1805.019451, 1808.227093, 1815.780763, 1804.021811, 1807.861329, 1798.223389, 1801.860678, 1800.812623, 1806.158529 |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   3 | 1820.853028, 1810.653729, 1803.116008, 1800.077516, 1797.513063, 1806.217815, 1814.641074, 1802.376913, 1792.319743 |
| Repeated manager queries, two-line limit | TextView       | Default          |   1 | 4.410156, 4.187053, 4.381836, 4.202311, 4.440592, 4.212484, 4.412028, 4.212891, 4.522217                            |
| Repeated manager queries, two-line limit | TextView       | Default          |   2 | 3.961914, 4.004110, 4.086263, 5.494914, 3.872030, 4.020345, 4.038167, 3.979533, 4.021077                            |
| Repeated manager queries, two-line limit | TextView       | Default          |   3 | 4.184855, 4.006144, 4.180949, 4.016194, 4.197550, 4.035360, 4.265991, 3.969808, 4.148559                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   1 | 3.921265, 3.872600, 3.914754, 3.852743, 3.947509, 3.911133, 3.931600, 3.871297, 8.448364                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   2 | 3.874390, 3.955485, 3.834270, 3.924764, 3.911296, 3.970459, 3.864624, 3.949992, 3.887248                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   3 | 4.014404, 4.353963, 3.956340, 3.918335, 4.013794, 3.922974, 3.975301, 3.917521, 3.964111                            |
| Styled text creation and layout          | RN Text        | Default          |   1 | 316.207357, 317.038859, 321.602458, 332.719808, 325.560506, 321.538168, 317.920614, 311.928548, 314.651937          |
| Styled text creation and layout          | RN Text        | Default          |   2 | 318.911133, 316.889974, 316.359986, 317.236654, 318.541992, 319.457519, 318.159384, 315.566040, 315.972941          |
| Styled text creation and layout          | RN Text        | Default          |   3 | 319.403890, 320.569743, 322.465291, 320.606771, 313.558838, 312.277426, 318.703573, 311.033081, 312.309855          |
| Styled text creation and layout          | RN Text        | Prepared         |   1 | 296.172607, 296.130046, 298.486003, 296.637492, 302.113851, 297.082397, 305.909505, 301.115600, 296.878337          |
| Styled text creation and layout          | RN Text        | Prepared         |   2 | 299.379354, 298.202270, 297.297771, 298.994100, 296.479452, 297.898030, 298.405477, 294.313110, 296.537435          |
| Styled text creation and layout          | RN Text        | Prepared         |   3 | 302.535319, 307.836874, 297.077596, 297.869507, 302.031779, 297.133260, 294.895508, 300.659505, 297.833212          |
| Styled text creation and layout          | TextView       | Default          |   1 | 192.442017, 192.198527, 191.269246, 194.572550, 186.761312, 188.634481, 188.238077, 187.760783, 185.530111          |
| Styled text creation and layout          | TextView       | Default          |   2 | 190.099609, 192.196818, 190.386679, 190.330241, 190.266602, 189.710043, 190.964275, 189.918050, 192.031331          |
| Styled text creation and layout          | TextView       | Default          |   3 | 192.278890, 191.505534, 189.335286, 192.618734, 187.782023, 191.124634, 187.010620, 185.518026, 182.208292          |
| Styled text creation and layout          | TextView       | Prepared         |   1 | 176.462280, 175.140381, 174.684408, 176.478190, 174.988729, 177.975790, 175.669637, 174.431112, 174.976440          |
| Styled text creation and layout          | TextView       | Prepared         |   2 | 175.523112, 175.728475, 175.045899, 174.475953, 176.758138, 171.968628, 171.347900, 172.015503, 171.577352          |
| Styled text creation and layout          | TextView       | Prepared         |   3 | 176.006103, 171.299113, 176.843262, 177.022501, 176.715617, 178.602295, 177.082072, 176.825521, 180.559326          |

</details>
