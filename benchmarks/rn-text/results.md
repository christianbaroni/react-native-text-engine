# RN Text benchmark results

Latest native measurement, mounting, and drawing results for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 21, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.3.1, Release build.

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 69.383 ± 1.055 | 31.037 ± 0.320 | 0.447× |
| Native layout, mount, and first draw | 512 | 276.232 ± 6.715 | 233.230 ± 3.912 | 0.844× |
| Retained paragraph measurement | 16,384 | 8.751 ± 0.230 | 0.179 ± 0.008 | 0.021× |
| Short labels, natural line height | 512 | 11.641 ± 0.231 | 4.960 ± 0.021 | 0.426× |
| Plain text creation and layout | 512 | 67.908 ± 1.150 | 30.427 ± 0.494 | 0.448× |
| Manager queries, 768 keys | 98,304 | 31.220 ± 0.748 | 5.595 ± 0.139 | 0.179× |
| Manager queries, 768 keys, two-line limit | 98,304 | 31.564 ± 0.015 | 15.190 ± 0.099 | 0.481× |
| Styled text creation and layout | 384 | 66.415 ± 0.347 | 27.969 ± 0.114 | 0.421× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T01:30:49.565Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `3637c0e91c29c141c47f0f5d0c67fb66488487bb`
- Source checksum (SHA256): `e093b1312a2bc7b6ac9e795d355b27b64f9f967e396a1cdf89c589d921b7322a`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | Run | Samples (ms) |
| --- | --- | ---: | --- |
| Chat list layout | RN Text | 1 | 70.515625, 65.962291, 65.458167, 68.738833, 70.179833, 65.975375, 64.738833, 66.054459, 65.911959 |
| Chat list layout | RN Text | 2 | 68.497417, 69.090834, 68.862333, 69.484667, 69.026708, 69.636542, 69.383334, 69.731542, 69.479958 |
| Chat list layout | RN Text | 3 | 69.917417, 70.641458, 70.316542, 70.593459, 70.423708, 71.116958, 70.633292, 70.368792, 70.438500 |
| Chat list layout | TextView | 1 | 28.840458, 28.464333, 28.740000, 28.667083, 29.845083, 29.335292, 28.875209, 28.769542, 29.424375 |
| Chat list layout | TextView | 2 | 30.402417, 30.559542, 30.936000, 30.833583, 31.197666, 31.036917, 31.360209, 31.282292, 31.459708 |
| Chat list layout | TextView | 3 | 31.768125, 31.336041, 31.100000, 31.332958, 31.312125, 31.655084, 31.531125, 31.357125, 31.387875 |
| Native layout, mount, and first draw | RN Text | 1 | 264.350458, 264.853083, 262.941875, 262.420167, 268.877625, 267.230292, 266.200625, 264.492541, 266.366250 |
| Native layout, mount, and first draw | RN Text | 2 | 276.232209, 274.222084, 276.099916, 279.235417, 276.517500, 274.773375, 274.167542, 277.340459, 277.369833 |
| Native layout, mount, and first draw | RN Text | 3 | 288.521375, 280.463792, 282.947041, 283.374417, 283.143584, 282.296417, 280.289375, 283.224209, 279.129042 |
| Native layout, mount, and first draw | TextView | 1 | 221.349875, 221.410333, 220.882125, 222.568292, 225.390334, 225.130041, 220.712583, 222.394459, 223.474625 |
| Native layout, mount, and first draw | TextView | 2 | 230.839416, 232.727417, 233.338417, 233.230167, 232.889167, 234.120958, 231.903125, 234.851792, 239.266334 |
| Native layout, mount, and first draw | TextView | 3 | 235.446583, 237.797375, 243.145541, 238.902375, 236.083167, 236.898375, 236.142417, 237.142583, 239.977208 |
| Retained paragraph measurement | RN Text | 1 | 8.599750, 8.182708, 8.657125, 8.148459, 8.148583, 8.081500, 8.222708, 8.270125, 8.282666 |
| Retained paragraph measurement | RN Text | 2 | 9.010000, 8.582458, 8.941042, 8.701667, 8.751292, 9.088334, 8.619750, 8.995917, 8.642000 |
| Retained paragraph measurement | RN Text | 3 | 8.790916, 8.781625, 9.119459, 8.981250, 9.019416, 8.435334, 9.154292, 8.988917, 8.886750 |
| Retained paragraph measurement | TextView | 1 | 0.165083, 0.164667, 0.173375, 0.173125, 0.178042, 0.178000, 0.171000, 0.170709, 0.168750 |
| Retained paragraph measurement | TextView | 2 | 0.179500, 0.179458, 0.179458, 0.174375, 0.174417, 0.170459, 0.170166, 0.183709, 0.183875 |
| Retained paragraph measurement | TextView | 3 | 0.190542, 0.189584, 0.188666, 0.185208, 0.177375, 0.177041, 0.193291, 0.192625, 0.184875 |
| Short labels, natural line height | RN Text | 1 | 11.186708, 11.178750, 11.053042, 11.073416, 11.196083, 11.023542, 11.508750, 11.660750, 10.843666 |
| Short labels, natural line height | RN Text | 2 | 11.796542, 11.741666, 11.559667, 11.432334, 11.640791, 11.597333, 11.917917, 11.398709, 11.950208 |
| Short labels, natural line height | RN Text | 3 | 12.099042, 11.929916, 11.714416, 11.616542, 11.885500, 11.755458, 11.871583, 12.054667, 11.537417 |
| Short labels, natural line height | TextView | 1 | 4.878333, 4.671375, 4.875333, 4.683792, 4.952542, 5.089416, 4.694875, 4.721917, 4.981833 |
| Short labels, natural line height | TextView | 2 | 4.961750, 5.134292, 4.959792, 4.895917, 5.058292, 4.884875, 4.931791, 5.027459, 4.954709 |
| Short labels, natural line height | TextView | 3 | 4.932292, 4.848708, 5.191208, 4.965542, 5.077209, 5.215375, 4.905417, 4.980542, 5.186291 |
| Plain text creation and layout | RN Text | 1 | 65.483416, 63.933666, 64.172416, 65.513666, 65.562416, 64.198250, 64.335458, 64.748500, 64.365666 |
| Plain text creation and layout | RN Text | 2 | 68.485833, 66.759917, 66.868625, 68.564291, 66.686958, 66.397417, 69.086500, 68.841417, 67.907875 |
| Plain text creation and layout | RN Text | 3 | 69.057625, 69.183083, 68.749833, 69.205084, 68.933417, 67.959125, 68.945416, 69.374458, 69.177792 |
| Plain text creation and layout | TextView | 1 | 28.900958, 29.007042, 28.988583, 28.732792, 29.044375, 28.747500, 29.453083, 29.965291, 29.398459 |
| Plain text creation and layout | TextView | 2 | 30.841375, 30.245791, 29.742833, 31.347083, 30.314333, 31.576000, 30.968584, 30.427500, 30.356958 |
| Plain text creation and layout | TextView | 3 | 30.967541, 31.076333, 30.140375, 30.422625, 30.708084, 31.512209, 30.921125, 31.067625, 30.309250 |
| Manager queries, 768 keys | RN Text | 1 | 30.257292, 31.009584, 31.065958, 30.441500, 30.331750, 29.802292, 30.152166, 30.063958, 30.251250 |
| Manager queries, 768 keys | RN Text | 2 | 31.961125, 31.220459, 31.323792, 30.430625, 30.128208, 30.466375, 30.557541, 32.706334, 31.793208 |
| Manager queries, 768 keys | RN Text | 3 | 31.859208, 32.480791, 31.974167, 32.037292, 31.968709, 30.628542, 31.825916, 32.033291, 31.686750 |
| Manager queries, 768 keys | TextView | 1 | 5.483208, 5.455667, 5.554125, 5.694166, 5.400208, 5.455750, 5.408708, 5.402333, 5.373208 |
| Manager queries, 768 keys | TextView | 2 | 5.766042, 5.821625, 5.637250, 5.582333, 5.834667, 5.595000, 5.394542, 5.565167, 5.492125 |
| Manager queries, 768 keys | TextView | 3 | 6.069083, 5.826167, 5.677167, 5.957125, 5.582166, 5.563458, 6.263333, 5.766792, 5.798375 |
| Manager queries, 768 keys, two-line limit | RN Text | 1 | 30.334500, 30.119917, 31.458208, 29.686333, 29.807625, 30.072042, 30.486750, 30.645708, 30.294666 |
| Manager queries, 768 keys, two-line limit | RN Text | 2 | 31.405167, 31.112500, 33.266125, 33.601375, 31.992000, 31.563625, 31.342583, 31.260792, 31.649292 |
| Manager queries, 768 keys, two-line limit | RN Text | 3 | 31.881125, 32.086750, 31.667250, 30.462667, 30.826416, 31.461417, 31.609750, 31.578458, 31.432833 |
| Manager queries, 768 keys, two-line limit | TextView | 1 | 14.685417, 14.523916, 14.334458, 14.295042, 14.319958, 14.112541, 14.155667, 14.364500, 14.728875 |
| Manager queries, 768 keys, two-line limit | TextView | 2 | 15.118833, 15.821542, 16.371416, 16.038958, 15.811541, 15.031333, 15.190000, 15.022375, 14.791584 |
| Manager queries, 768 keys, two-line limit | TextView | 3 | 15.189292, 14.710375, 15.289042, 15.431625, 16.875542, 15.550042, 15.007958, 15.079208, 15.969500 |
| Styled text creation and layout | RN Text | 1 | 64.346583, 63.379959, 62.817875, 64.799708, 64.468375, 62.627833, 63.002625, 64.148667, 62.395250 |
| Styled text creation and layout | RN Text | 2 | 65.580417, 64.965334, 66.415292, 67.937959, 66.781084, 65.892125, 67.168500, 66.717916, 64.760000 |
| Styled text creation and layout | RN Text | 3 | 66.529416, 65.349625, 72.006375, 69.195167, 68.202750, 66.762667, 68.153292, 66.432708, 65.211416 |
| Styled text creation and layout | TextView | 1 | 27.848791, 27.519209, 27.018041, 27.425458, 26.510333, 26.552208, 27.085542, 27.978667, 26.934208 |
| Styled text creation and layout | TextView | 2 | 27.968958, 27.724791, 28.270500, 28.781375, 28.008875, 27.284791, 27.822708, 28.073250, 27.519041 |
| Styled text creation and layout | TextView | 3 | 28.083083, 27.940708, 29.304833, 29.148209, 27.999958, 27.958208, 28.111125, 27.988750, 28.373250 |

</details>

## Android

September 21, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.3.1, Release build.

### RN Text with default layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 153.820 ± 0.081 | 109.502 ± 0.053 | 0.712× |
| Native layout, mount, and first draw | 512 | 893.148 ± 5.879 | 421.532 ± 0.195 | 0.472× |
| Retained paragraph measurement | 16,384 | 19.116 ± 0.094 | 0.829 ± 0.003 | 0.043× |
| Short labels, natural line height | 512 | 54.017 ± 0.073 | 36.988 ± 0.103 | 0.685× |
| Plain text creation and layout | 512 | 141.847 ± 0.012 | 101.552 ± 0.156 | 0.716× |
| Manager queries, 768 keys | 6,144 | 3.925 ± 0.007 | 1.467 ± 0.003 | 0.374× |
| Manager queries, 768 keys, two-line limit | 6,144 | 3.928 ± 0.032 | 1.607 ± 0.033 | 0.409× |
| Styled text creation and layout | 384 | 320.832 ± 1.881 | 191.112 ± 0.213 | 0.596× |

### RN Text with prepared layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 159.526 ± 0.543 | 109.171 ± 0.184 | 0.684× |
| Native layout, mount, and first draw | 512 | 451.713 ± 1.105 | 422.220 ± 0.707 | 0.935× |
| Retained paragraph measurement | 16,384 | 0.241 ± 0.001 | 0.821 ± 0.002 | 3.406× |
| Short labels, natural line height | 512 | 58.431 ± 0.067 | 37.087 ± 0.066 | 0.635× |
| Plain text creation and layout | 512 | 146.352 ± 0.164 | 101.335 ± 0.073 | 0.692× |
| Manager queries, 768 keys | 6,144 | 1755.502 ± 4.013 | 1.481 ± 0.007 | 0.001× |
| Manager queries, 768 keys, two-line limit | 6,144 | 1841.434 ± 0.305 | 1.548 ± 0.013 | 0.001× |
| Styled text creation and layout | 384 | 299.639 ± 0.265 | 189.421 ± 0.466 | 0.632× |

The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T01:30:50.831Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `9b037a0ba178ff1926096a2a5a36168861314b79e1d9322209246d5c6759ffef`
- Git HEAD: `3637c0e91c29c141c47f0f5d0c67fb66488487bb`
- Source checksum (SHA256): `6e0f1ea3e9183c20a6a0fb4ef36d20abd8d3570d74df2674fc1cc25d315c8854`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | RN configuration | Run | Samples (ms) |
| --- | --- | --- | ---: | --- |
| Chat list layout | RN Text | Default | 1 | 153.632731, 153.176880, 153.386922, 157.104614, 153.901083, 154.177002, 153.688436, 154.236695, 157.434611 |
| Chat list layout | RN Text | Default | 2 | 153.895263, 153.820231, 153.281006, 153.576253, 154.770671, 154.140503, 153.618489, 153.691244, 157.300334 |
| Chat list layout | RN Text | Default | 3 | 152.137166, 153.201783, 153.178426, 154.690714, 154.551147, 153.270996, 153.136678, 153.081340, 153.889363 |
| Chat list layout | RN Text | Prepared | 1 | 157.195760, 159.859985, 156.264323, 157.570760, 158.895101, 157.902344, 159.967082, 159.267212, 158.733398 |
| Chat list layout | RN Text | Prepared | 2 | 159.105632, 164.771648, 158.897176, 161.467163, 159.029378, 161.025350, 164.271037, 158.044678, 160.068929 |
| Chat list layout | RN Text | Prepared | 3 | 158.498047, 161.942343, 159.387858, 159.526367, 158.818929, 160.517457, 161.760498, 159.579915, 159.505697 |
| Chat list layout | TextView | Default | 1 | 111.000733, 108.731283, 108.973145, 111.426595, 108.382039, 109.798869, 109.881673, 109.554687, 108.681804 |
| Chat list layout | TextView | Default | 2 | 108.889201, 109.942139, 109.242350, 110.197632, 109.161377, 109.493204, 109.501994, 110.009278, 110.036662 |
| Chat list layout | TextView | Default | 3 | 106.189454, 108.929606, 109.539347, 109.866740, 108.962240, 109.766887, 109.244955, 111.350504, 108.854859 |
| Chat list layout | TextView | Prepared | 1 | 108.151815, 108.785685, 108.989055, 109.240927, 108.705647, 109.956177, 107.807210, 108.956747, 109.090576 |
| Chat list layout | TextView | Prepared | 2 | 108.964152, 108.747355, 109.230753, 109.518596, 109.335205, 108.546183, 109.170939, 109.512370, 108.953939 |
| Chat list layout | TextView | Prepared | 3 | 108.535848, 109.413167, 109.354573, 109.602173, 110.338094, 110.983642, 109.023519, 109.016073, 109.224731 |
| Native layout, mount, and first draw | RN Text | Default | 1 | 814.307984, 832.985596, 851.123617, 923.293132, 868.491170, 886.802409, 913.674073, 1036.793213, 945.831869 |
| Native layout, mount, and first draw | RN Text | Default | 2 | 814.829672, 831.877564, 873.291220, 885.378948, 899.027059, 990.765829, 925.089194, 948.209188, 972.995687 |
| Native layout, mount, and first draw | RN Text | Default | 3 | 814.283814, 834.638062, 860.769207, 920.630575, 872.737712, 893.147827, 918.737223, 1014.916341, 950.620361 |
| Native layout, mount, and first draw | RN Text | Prepared | 1 | 449.896526, 449.709066, 451.659302, 452.020915, 449.371094, 449.461833, 452.122803, 449.816122, 450.077800 |
| Native layout, mount, and first draw | RN Text | Prepared | 2 | 450.916952, 451.713460, 452.462728, 450.663859, 450.731323, 454.463827, 453.853434, 452.150595, 450.812786 |
| Native layout, mount, and first draw | RN Text | Prepared | 3 | 450.537882, 455.589600, 455.599162, 452.818645, 450.643311, 454.399129, 451.115438, 452.213786, 457.161621 |
| Native layout, mount, and first draw | TextView | Default | 1 | 422.127278, 423.167236, 422.589274, 420.465495, 421.525147, 420.643026, 423.653362, 421.336792, 421.531901 |
| Native layout, mount, and first draw | TextView | Default | 2 | 422.265218, 425.440227, 422.023031, 422.300212, 421.236776, 423.766358, 424.629883, 422.420166, 421.934693 |
| Native layout, mount, and first draw | TextView | Default | 3 | 420.126099, 420.996257, 422.767334, 425.819905, 420.528808, 419.951742, 421.336629, 422.164632, 423.548746 |
| Native layout, mount, and first draw | TextView | Prepared | 1 | 420.015788, 421.860271, 421.922486, 423.437134, 427.146770, 423.135458, 425.084147, 422.927124, 421.716228 |
| Native layout, mount, and first draw | TextView | Prepared | 2 | 421.711060, 422.220012, 422.817831, 425.434530, 421.657959, 420.564372, 421.492921, 422.308675, 433.856689 |
| Native layout, mount, and first draw | TextView | Prepared | 3 | 420.045410, 419.724528, 422.292115, 425.217082, 419.748739, 420.465699, 420.408407, 420.451986, 422.718181 |
| Retained paragraph measurement | RN Text | Default | 1 | 19.115886, 19.068074, 19.073690, 19.098348, 19.138469, 19.289266, 19.381917, 19.132121, 19.052409 |
| Retained paragraph measurement | RN Text | Default | 2 | 19.559204, 19.563720, 19.599772, 19.633586, 19.611002, 19.656575, 19.923340, 20.906290, 19.571207 |
| Retained paragraph measurement | RN Text | Default | 3 | 18.997518, 19.040406, 18.912679, 18.993489, 18.995931, 19.136962, 19.078085, 19.022176, 19.037232 |
| Retained paragraph measurement | RN Text | Prepared | 1 | 0.297403, 0.246948, 0.246785, 0.246867, 0.246988, 0.246826, 0.246907, 0.246867, 0.246663 |
| Retained paragraph measurement | RN Text | Prepared | 2 | 0.240967, 0.241048, 0.240763, 0.241007, 0.240926, 0.240804, 0.252767, 0.240845, 0.240804 |
| Retained paragraph measurement | RN Text | Prepared | 3 | 0.296916, 0.240559, 0.239665, 0.239543, 0.239584, 0.239706, 0.239583, 0.239584, 0.239462 |
| Retained paragraph measurement | TextView | Default | 1 | 0.832845, 0.830688, 0.834961, 0.837036, 0.846924, 0.830444, 0.832682, 0.832561, 0.830363 |
| Retained paragraph measurement | TextView | Default | 2 | 0.831014, 0.930135, 0.829223, 0.829468, 0.829346, 0.871745, 0.827392, 0.854818, 0.826905 |
| Retained paragraph measurement | TextView | Default | 3 | 0.838176, 0.814494, 0.814128, 0.814006, 0.813355, 0.932698, 0.816813, 0.816814, 0.816732 |
| Retained paragraph measurement | TextView | Prepared | 1 | 0.818238, 0.819254, 0.836588, 0.846598, 0.818196, 0.818685, 0.818359, 0.851399, 0.817220 |
| Retained paragraph measurement | TextView | Prepared | 2 | 0.839762, 0.825276, 0.828328, 0.832275, 0.879476, 0.821696, 0.850139, 0.823730, 0.824992 |
| Retained paragraph measurement | TextView | Prepared | 3 | 0.820150, 0.820434, 0.820394, 0.936768, 0.821533, 0.820841, 0.820476, 0.820638, 0.858114 |
| Short labels, natural line height | RN Text | Default | 1 | 54.070597, 54.017212, 53.841227, 53.879639, 56.621460, 51.470459, 52.989014, 54.762654, 55.162150 |
| Short labels, natural line height | RN Text | Default | 2 | 52.353271, 54.240194, 54.054566, 55.704915, 56.418823, 53.991537, 56.716390, 53.846720, 54.090087 |
| Short labels, natural line height | RN Text | Default | 3 | 54.064047, 53.459879, 53.858032, 53.737386, 53.559408, 53.662964, 53.535075, 56.573934, 50.472330 |
| Short labels, natural line height | RN Text | Prepared | 1 | 58.318156, 58.434326, 58.494629, 58.364218, 61.108276, 54.867106, 58.175496, 58.298055, 58.417562 |
| Short labels, natural line height | RN Text | Prepared | 2 | 58.755575, 58.771891, 58.682414, 58.670206, 58.829590, 59.463379, 57.169230, 58.769979, 58.709310 |
| Short labels, natural line height | RN Text | Prepared | 3 | 58.418376, 58.472087, 58.148274, 58.307088, 59.121745, 60.798746, 58.301432, 58.541830, 58.431112 |
| Short labels, natural line height | TextView | Default | 1 | 36.914510, 36.885335, 37.197062, 37.462280, 40.157999, 36.601359, 36.816936, 36.856486, 36.866862 |
| Short labels, natural line height | TextView | Default | 2 | 37.227092, 37.139201, 37.100098, 37.168091, 37.135457, 37.291667, 37.347290, 39.297037, 35.148519 |
| Short labels, natural line height | TextView | Default | 3 | 36.988444, 36.977783, 37.032430, 39.053263, 39.695679, 35.366007, 34.847087, 36.620606, 37.080648 |
| Short labels, natural line height | TextView | Prepared | 1 | 35.684326, 37.015218, 36.947917, 36.850708, 36.861410, 36.903361, 36.922363, 37.126465, 38.398479 |
| Short labels, natural line height | TextView | Prepared | 2 | 37.213623, 37.153117, 37.191813, 37.004720, 37.294067, 38.378988, 34.335652, 36.746785, 36.983887 |
| Short labels, natural line height | TextView | Prepared | 3 | 36.144491, 37.087362, 37.037191, 38.707397, 37.015625, 37.079752, 37.099609, 37.989461, 38.717407 |
| Plain text creation and layout | RN Text | Default | 1 | 141.832031, 141.847087, 141.653443, 142.900554, 141.383830, 141.865031, 141.686524, 142.026448, 142.142212 |
| Plain text creation and layout | RN Text | Default | 2 | 141.871867, 142.249919, 141.799683, 141.736776, 144.407512, 141.049805, 142.229288, 141.932902, 141.762899 |
| Plain text creation and layout | RN Text | Default | 3 | 141.301392, 143.211385, 141.477662, 141.852173, 142.122437, 141.727824, 141.906576, 141.714397, 141.835124 |
| Plain text creation and layout | RN Text | Prepared | 1 | 146.311117, 146.198852, 145.655436, 145.548584, 147.581503, 143.230875, 142.947876, 144.338217, 145.694173 |
| Plain text creation and layout | RN Text | Prepared | 2 | 146.515218, 145.988607, 146.450196, 149.466512, 147.836222, 145.807455, 148.545491, 146.397909, 146.917643 |
| Plain text creation and layout | RN Text | Prepared | 3 | 146.877564, 146.191895, 147.872314, 145.411133, 145.907308, 146.351522, 146.433635, 147.327922, 145.451253 |
| Plain text creation and layout | TextView | Default | 1 | 98.506958, 101.694459, 101.552084, 101.527751, 101.331380, 101.480550, 101.590861, 102.159505, 101.595459 |
| Plain text creation and layout | TextView | Default | 2 | 101.551025, 101.507405, 101.226115, 101.221354, 100.895712, 100.762898, 101.660157, 101.396322, 101.563762 |
| Plain text creation and layout | TextView | Default | 3 | 103.453980, 102.069092, 102.144938, 102.372680, 104.676473, 101.671062, 102.134196, 102.400960, 101.792724 |
| Plain text creation and layout | TextView | Prepared | 1 | 101.163127, 101.276041, 101.539388, 101.335002, 101.245891, 100.732747, 102.885580, 101.584676, 101.357625 |
| Plain text creation and layout | TextView | Prepared | 2 | 101.367351, 101.353272, 101.274251, 102.345419, 101.632283, 101.676961, 101.645956, 101.744018, 101.545044 |
| Plain text creation and layout | TextView | Prepared | 3 | 101.685669, 101.222493, 101.323934, 103.015380, 101.125162, 100.102783, 101.349813, 101.262126, 101.171550 |
| Manager queries, 768 keys | RN Text | Default | 1 | 3.955607, 3.915243, 3.918417, 3.925049, 3.949992, 3.926880, 3.908732, 3.921265, 3.944254 |
| Manager queries, 768 keys | RN Text | Default | 2 | 3.919393, 3.932048, 3.943400, 3.934244, 3.939169, 3.916789, 3.945434, 3.915446, 3.924805 |
| Manager queries, 768 keys | RN Text | Default | 3 | 3.892334, 3.889242, 3.897786, 3.945069, 3.895874, 3.881144, 3.882284, 3.919718, 3.893148 |
| Manager queries, 768 keys | RN Text | Prepared | 1 | 1744.650636, 1746.315105, 1755.488526, 1754.465129, 1748.565064, 1751.489055, 1758.861898, 1754.658896, 1737.331503 |
| Manager queries, 768 keys | RN Text | Prepared | 2 | 1754.808269, 1758.481243, 1761.769736, 1755.962566, 1755.502443, 1755.996543, 1751.369670, 1752.366375, 1747.095093 |
| Manager queries, 768 keys | RN Text | Prepared | 3 | 1763.944499, 1762.999676, 1762.315227, 1760.427124, 1756.309816, 1760.702149, 1754.642131, 1750.755820, 1743.950643 |
| Manager queries, 768 keys | TextView | Default | 1 | 1.456136, 1.467814, 1.478027, 1.456258, 1.481445, 1.454793, 1.464152, 1.467814, 1.455729 |
| Manager queries, 768 keys | TextView | Default | 2 | 1.621338, 1.585653, 1.607707, 1.603068, 1.578410, 1.615031, 1.591187, 1.704834, 1.602742 |
| Manager queries, 768 keys | TextView | Default | 3 | 1.455282, 1.474488, 1.463664, 1.449951, 1.566325, 1.467285, 1.453247, 1.483114, 1.475057 |
| Manager queries, 768 keys | TextView | Prepared | 1 | 1.582031, 1.460571, 1.481690, 1.495157, 1.471557, 1.480509, 1.456747, 1.480998, 1.498169 |
| Manager queries, 768 keys | TextView | Prepared | 2 | 1.649577, 1.616171, 1.626953, 1.632121, 1.604045, 1.653768, 1.611002, 1.611898, 1.755330 |
| Manager queries, 768 keys | TextView | Prepared | 3 | 1.504110, 1.465169, 1.491903, 1.474487, 1.458414, 1.507650, 1.458740, 1.461588, 2.029745 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 1 | 3.967041, 3.918335, 3.928304, 3.918539, 3.954549, 3.927816, 3.927572, 3.928426, 3.963135 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 2 | 3.928751, 4.019857, 3.999674, 3.991821, 4.027873, 3.932536, 3.959839, 3.940673, 3.943359 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 3 | 3.654459, 3.651001, 3.660970, 3.712728, 3.669189, 3.794027, 3.877238, 3.905639, 3.897623 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 1 | 1827.077271, 1820.837322, 1831.228883, 1830.378215, 1825.944215, 1830.659710, 1827.933350, 1838.074464, 1832.747030 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 2 | 1836.817221, 1837.507203, 1841.344891, 1838.568564, 1841.738404, 1846.768678, 1842.371217, 1849.355306, 1847.921795 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 3 | 1841.433879, 1839.450481, 1843.021445, 1838.050294, 1830.110719, 1831.892619, 1849.931845, 1861.742636, 1852.378581 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 1 | 1.591187, 1.584188, 1.608968, 1.594930, 2.204386, 1.606608, 1.620443, 1.592203, 1.610473 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 2 | 1.626506, 1.736817, 1.642700, 1.628093, 1.680257, 1.622274, 1.650961, 1.649618, 1.624186 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 3 | 1.573812, 1.613078, 1.581502, 1.551555, 1.614054, 1.569743, 1.568889, 1.599731, 1.562663 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 1 | 1.524373, 1.534953, 1.515910, 1.522461, 1.666504, 1.526327, 1.578776, 1.536336, 1.546916 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 2 | 2.252482, 1.717530, 1.741536, 1.714233, 1.743042, 1.713663, 1.712483, 1.748373, 1.707967 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 3 | 1.585083, 1.523519, 1.560262, 1.528239, 1.539185, 1.554240, 1.537598, 1.547893, 1.550293 |
| Styled text creation and layout | RN Text | Default | 1 | 320.832316, 317.183716, 327.583455, 318.310221, 321.568319, 318.002360, 320.644816, 325.168213, 322.765259 |
| Styled text creation and layout | RN Text | Default | 2 | 316.802653, 319.847982, 316.983887, 319.468058, 317.412394, 319.376099, 317.008911, 319.124756, 317.185141 |
| Styled text creation and layout | RN Text | Default | 3 | 317.186768, 322.712891, 323.063762, 317.279867, 326.261435, 327.650635, 318.540364, 323.237671, 317.239868 |
| Styled text creation and layout | RN Text | Prepared | 1 | 302.847005, 299.639405, 301.784261, 297.554728, 302.429443, 302.864828, 297.579265, 299.388672, 296.947714 |
| Styled text creation and layout | RN Text | Prepared | 2 | 299.745768, 304.105794, 302.327597, 299.778850, 300.288900, 299.620484, 302.957642, 302.851278, 299.273397 |
| Styled text creation and layout | RN Text | Prepared | 3 | 297.935913, 299.827026, 301.480916, 297.737305, 299.171672, 301.938314, 296.949870, 301.688273, 299.374431 |
| Styled text creation and layout | TextView | Default | 1 | 193.982748, 191.112386, 189.623779, 189.364380, 191.364624, 194.491577, 190.439128, 189.886068, 191.278972 |
| Styled text creation and layout | TextView | Default | 2 | 189.830973, 189.340088, 188.892945, 189.002238, 189.138347, 188.662069, 188.848348, 188.122599, 190.120891 |
| Styled text creation and layout | TextView | Default | 3 | 190.087037, 196.299113, 191.325562, 192.362061, 190.667440, 191.351074, 190.026286, 191.432657, 189.897746 |
| Styled text creation and layout | TextView | Prepared | 1 | 190.325968, 187.973266, 187.929118, 187.001750, 191.426392, 189.272990, 188.955078, 188.764933, 189.409465 |
| Styled text creation and layout | TextView | Prepared | 2 | 189.527507, 191.488322, 189.663452, 189.709595, 189.408488, 189.420613, 188.924479, 188.129883, 187.922892 |
| Styled text creation and layout | TextView | Prepared | 3 | 189.305339, 188.963704, 188.584107, 191.964153, 190.750855, 190.384521, 189.863241, 190.103191, 191.542480 |

</details>
