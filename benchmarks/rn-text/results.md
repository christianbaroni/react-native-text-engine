# RN Text benchmark results

Latest native measurement, mounting, and drawing results for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 20, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.3.0, Release build.

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 67.028 ± 0.614 | 29.670 ± 0.649 | 0.443× |
| Native layout, mount, and first draw | 512 | 269.997 ± 5.920 | 234.254 ± 5.872 | 0.868× |
| Retained paragraph measurement | 16,384 | 8.410 ± 0.237 | 0.181 ± 0.008 | 0.021× |
| Short labels, natural line height | 512 | 11.248 ± 0.231 | 4.900 ± 0.013 | 0.436× |
| Plain text creation and layout | 512 | 65.972 ± 1.782 | 29.792 ± 0.932 | 0.452× |
| Manager queries, 768 keys | 98,304 | 30.612 ± 0.722 | 5.569 ± 0.020 | 0.182× |
| Manager queries, 768 keys, two-line limit | 98,304 | 30.870 ± 0.350 | 14.578 ± 0.358 | 0.472× |
| Styled text creation and layout | 384 | 64.604 ± 0.990 | 27.918 ± 0.205 | 0.432× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T20:04:30.851Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `f6388ed66e66da7c4763294548373dd7780b72ff`
- Source checksum (SHA256): `efed2b6b664ef294506a6899924f224ca408d46456b18f162ef6e02d68e496bf`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | Run | Samples (ms) |
| --- | --- | ---: | --- |
| Chat list layout | RN Text | 1 | 67.525625, 65.413292, 65.356750, 65.366667, 67.892833, 65.866125, 65.416666, 65.482792, 65.480292 |
| Chat list layout | RN Text | 2 | 66.972959, 66.494167, 67.061541, 67.321416, 67.028208, 66.850125, 67.209375, 66.635334, 67.072125 |
| Chat list layout | RN Text | 3 | 66.388333, 66.880791, 66.664250, 67.147250, 68.005375, 67.731708, 67.642500, 68.714416, 74.479041 |
| Chat list layout | TextView | 1 | 28.947583, 28.771500, 28.551042, 28.566334, 28.875959, 28.922000, 28.573000, 28.382125, 28.625375 |
| Chat list layout | TextView | 2 | 29.380333, 29.669667, 29.657500, 29.578125, 30.031625, 29.828292, 29.821500, 29.903250, 29.577208 |
| Chat list layout | TextView | 3 | 30.007792, 30.642125, 30.130500, 30.237167, 30.468458, 30.142042, 30.477833, 30.318583, 30.885916 |
| Native layout, mount, and first draw | RN Text | 1 | 261.788625, 262.454667, 262.561667, 263.268667, 263.278458, 263.005875, 261.847792, 263.768041, 261.961750 |
| Native layout, mount, and first draw | RN Text | 2 | 267.894583, 267.898708, 269.594042, 269.447625, 270.204750, 270.657209, 270.306458, 269.997416, 277.294250 |
| Native layout, mount, and first draw | RN Text | 3 | 275.917083, 272.927042, 272.160250, 278.654042, 283.322291, 275.510042, 275.720209, 276.308292, 279.678625 |
| Native layout, mount, and first draw | TextView | 1 | 227.392333, 226.174417, 227.724875, 227.273583, 228.384041, 227.431833, 227.998500, 226.958250, 229.129917 |
| Native layout, mount, and first draw | TextView | 2 | 234.483667, 231.639834, 234.254208, 233.082834, 232.516083, 239.743167, 234.577334, 233.762750, 236.297833 |
| Native layout, mount, and first draw | TextView | 3 | 240.749959, 239.976792, 239.537125, 240.462625, 239.276584, 237.325875, 251.752083, 240.126583, 241.264791 |
| Retained paragraph measurement | RN Text | 1 | 8.088916, 8.191583, 8.173042, 7.827083, 8.184084, 8.474083, 7.820417, 8.404917, 7.964792 |
| Retained paragraph measurement | RN Text | 2 | 8.410083, 8.548167, 8.319583, 8.533875, 8.267250, 8.587083, 8.407500, 8.280834, 8.563375 |
| Retained paragraph measurement | RN Text | 3 | 8.415916, 8.687250, 8.702958, 8.455417, 8.752625, 8.397792, 8.834875, 8.414708, 8.798750 |
| Retained paragraph measurement | TextView | 1 | 0.164458, 0.204250, 0.164208, 0.164125, 0.180000, 0.180125, 0.164125, 0.163708, 0.165834 |
| Retained paragraph measurement | TextView | 2 | 0.178333, 0.184625, 0.189167, 0.192000, 0.188583, 0.196875, 0.197208, 0.181166, 0.179833 |
| Retained paragraph measurement | TextView | 3 | 0.176625, 0.179416, 0.180583, 0.183541, 0.171292, 0.171500, 0.188167, 0.188167, 0.184042 |
| Short labels, natural line height | RN Text | 1 | 11.021500, 11.029083, 11.011583, 11.040667, 11.014666, 11.025459, 10.965833, 11.016209, 10.982000 |
| Short labels, natural line height | RN Text | 2 | 11.247667, 11.248042, 11.436958, 10.935542, 11.123333, 11.410041, 11.506167, 11.150875, 11.239875 |
| Short labels, natural line height | RN Text | 3 | 11.544500, 11.732292, 11.649708, 11.702584, 11.403250, 11.280584, 11.787584, 11.710125, 11.439042 |
| Short labels, natural line height | TextView | 1 | 4.765292, 4.733042, 4.678833, 4.762125, 4.783250, 4.657208, 4.756791, 4.702959, 4.760292 |
| Short labels, natural line height | TextView | 2 | 4.911375, 4.905208, 4.668291, 4.882459, 5.003000, 4.710333, 4.729458, 5.033667, 4.900250 |
| Short labels, natural line height | TextView | 3 | 4.744875, 4.910334, 4.913125, 4.714084, 5.089750, 5.123500, 4.904959, 4.940292, 5.097166 |
| Plain text creation and layout | RN Text | 1 | 63.429917, 64.193750, 63.512625, 63.171375, 63.781375, 64.010417, 63.104125, 63.231083, 64.331083 |
| Plain text creation and layout | RN Text | 2 | 65.830167, 66.079167, 65.972292, 65.704333, 65.982250, 66.315750, 65.719958, 65.802583, 66.130750 |
| Plain text creation and layout | RN Text | 3 | 67.818125, 67.718875, 68.005833, 67.531083, 67.753875, 68.398000, 67.592583, 67.764125, 67.709667 |
| Plain text creation and layout | TextView | 1 | 28.645709, 28.144125, 27.674459, 27.873875, 28.174500, 28.548375, 28.088375, 27.967958, 28.474709 |
| Plain text creation and layout | TextView | 2 | 29.930333, 29.691542, 29.792416, 30.725500, 29.260500, 29.557875, 29.974083, 29.982750, 29.497708 |
| Plain text creation and layout | TextView | 3 | 30.713083, 30.856000, 30.485250, 30.879375, 30.643459, 30.955292, 30.689083, 30.723958, 30.864709 |
| Manager queries, 768 keys | RN Text | 1 | 29.263500, 29.234792, 30.107541, 30.102375, 29.660416, 29.114334, 29.531417, 29.624416, 29.733542 |
| Manager queries, 768 keys | RN Text | 2 | 30.854542, 30.948000, 30.768084, 30.686125, 30.227667, 30.612167, 30.537542, 30.336834, 30.237208 |
| Manager queries, 768 keys | RN Text | 3 | 31.974542, 30.928167, 31.497667, 30.985708, 31.174000, 31.519458, 31.389250, 30.980875, 31.334125 |
| Manager queries, 768 keys | TextView | 1 | 5.332083, 5.521708, 5.280042, 5.022750, 5.289833, 5.541458, 5.488416, 5.127125, 5.190125 |
| Manager queries, 768 keys | TextView | 2 | 5.540667, 5.556584, 5.448834, 5.589416, 5.714917, 5.595542, 5.619791, 5.681750, 5.479000 |
| Manager queries, 768 keys | TextView | 3 | 5.627375, 5.765333, 5.496500, 5.534416, 5.651041, 5.508209, 5.624833, 5.569000, 5.466333 |
| Manager queries, 768 keys, two-line limit | RN Text | 1 | 29.523209, 29.586833, 30.099542, 29.655250, 29.799333, 29.881667, 29.138041, 28.702167, 29.236250 |
| Manager queries, 768 keys, two-line limit | RN Text | 2 | 31.289334, 30.265917, 30.870333, 30.248166, 31.561084, 31.388125, 30.475208, 31.429708, 30.639666 |
| Manager queries, 768 keys, two-line limit | RN Text | 3 | 30.999875, 31.182959, 31.771334, 30.634000, 31.291417, 30.932958, 31.348625, 31.219958, 31.695334 |
| Manager queries, 768 keys, two-line limit | TextView | 1 | 14.201625, 13.986291, 13.481041, 14.496792, 14.258833, 13.942875, 13.467125, 13.877250, 14.591917 |
| Manager queries, 768 keys, two-line limit | TextView | 2 | 15.742375, 14.638000, 14.935667, 14.763375, 14.970250, 15.375000, 15.199625, 14.707458, 14.805000 |
| Manager queries, 768 keys, two-line limit | TextView | 3 | 14.676833, 14.577792, 14.612209, 14.450125, 14.702125, 14.697167, 14.552000, 14.529375, 14.567000 |
| Styled text creation and layout | RN Text | 1 | 60.852583, 62.141416, 62.276167, 60.778209, 60.900459, 63.469209, 61.438167, 60.981709, 61.009542 |
| Styled text creation and layout | RN Text | 2 | 64.542708, 64.357666, 64.501666, 64.801958, 65.271167, 64.604375, 65.055250, 64.523375, 65.215500 |
| Styled text creation and layout | RN Text | 3 | 65.526542, 65.784250, 65.594792, 65.577625, 65.971375, 65.630709, 65.574792, 65.171875, 65.634333 |
| Styled text creation and layout | TextView | 1 | 25.822042, 25.961417, 25.973667, 25.750000, 25.874375, 25.887625, 25.752583, 25.969500, 27.391416 |
| Styled text creation and layout | TextView | 2 | 27.450708, 27.918000, 27.792792, 27.202750, 27.925292, 27.619125, 27.937250, 28.054791, 27.945250 |
| Styled text creation and layout | TextView | 3 | 28.030875, 28.288583, 28.610917, 27.889084, 27.979792, 28.188625, 28.052541, 28.203292, 28.122666 |

</details>

## Android

September 20, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.3.0, Release build.

### RN Text with default layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 153.815 ± 0.007 | 105.806 ± 0.366 | 0.688× |
| Native layout, mount, and first draw | 512 | 915.678 ± 4.756 | 432.433 ± 0.818 | 0.472× |
| Retained paragraph measurement | 16,384 | 19.137 ± 0.029 | 0.824 ± 0.003 | 0.043× |
| Short labels, natural line height | 512 | 53.545 ± 0.093 | 37.094 ± 0.055 | 0.693× |
| Plain text creation and layout | 512 | 141.763 ± 0.259 | 98.027 ± 0.116 | 0.691× |
| Manager queries, 768 keys | 6,144 | 3.905 ± 0.002 | 1.465 ± 0.008 | 0.375× |
| Manager queries, 768 keys, two-line limit | 6,144 | 3.920 ± 0.010 | 1.537 ± 0.003 | 0.392× |
| Styled text creation and layout | 384 | 317.546 ± 0.080 | 189.469 ± 0.528 | 0.597× |

### RN Text with prepared layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 161.066 ± 1.083 | 105.550 ± 0.022 | 0.655× |
| Native layout, mount, and first draw | 512 | 450.883 ± 0.107 | 434.793 ± 2.094 | 0.964× |
| Retained paragraph measurement | 16,384 | 0.246 ± 0.004 | 0.820 ± 0.000 | 3.328× |
| Short labels, natural line height | 512 | 58.638 ± 0.193 | 36.963 ± 0.023 | 0.630× |
| Plain text creation and layout | 512 | 146.336 ± 1.041 | 98.014 ± 0.043 | 0.670× |
| Manager queries, 768 keys | 6,144 | 1755.655 ± 14.022 | 1.469 ± 0.008 | 0.001× |
| Manager queries, 768 keys, two-line limit | 6,144 | 1835.468 ± 1.756 | 1.536 ± 0.004 | 0.001× |
| Styled text creation and layout | 384 | 301.476 ± 2.768 | 189.784 ± 1.467 | 0.630× |

The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T19:59:30.006Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `01db801b52c706e79defd1bca1b1e34e604b7ec35b72d3ef3cc5aafeeb7d311e`
- Git HEAD: `f6388ed66e66da7c4763294548373dd7780b72ff`
- Source checksum (SHA256): `bf3f3923fdf175d158982a42cbc3cba7e7972817d7dd677396724e44159889d9`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | RN configuration | Run | Samples (ms) |
| --- | --- | --- | ---: | --- |
| Chat list layout | RN Text | Default | 1 | 157.102824, 153.297526, 153.403524, 153.815430, 157.034424, 155.453654, 153.310954, 152.767986, 156.084066 |
| Chat list layout | RN Text | Default | 2 | 153.726969, 156.047974, 153.641561, 155.119914, 156.057455, 154.426921, 153.764730, 153.784993, 154.325440 |
| Chat list layout | RN Text | Default | 3 | 153.288086, 155.023641, 153.243490, 153.808390, 156.411011, 155.811279, 152.929524, 152.990967, 157.238932 |
| Chat list layout | RN Text | Prepared | 1 | 158.919555, 161.391073, 159.062622, 160.567708, 160.497355, 159.983398, 162.695231, 158.403117, 158.477539 |
| Chat list layout | RN Text | Prepared | 2 | 162.721354, 166.985636, 162.452068, 162.858724, 162.812215, 163.052205, 165.207723, 161.822347, 160.671713 |
| Chat list layout | RN Text | Prepared | 3 | 160.767741, 162.662394, 162.752482, 161.066325, 160.897258, 161.332113, 161.773274, 159.523478, 159.388509 |
| Chat list layout | TextView | Default | 1 | 103.382528, 105.128499, 105.820598, 105.806478, 105.631063, 105.682374, 105.923136, 105.922160, 105.861613 |
| Chat list layout | TextView | Default | 2 | 108.595337, 102.993530, 106.550090, 106.270508, 105.782837, 107.561645, 106.183064, 105.710408, 106.318360 |
| Chat list layout | TextView | Default | 3 | 104.697795, 104.977457, 105.440755, 105.426026, 105.718425, 105.597127, 105.614014, 106.045207, 105.109863 |
| Chat list layout | TextView | Prepared | 1 | 105.319173, 105.121093, 105.359985, 105.686646, 105.606852, 105.550008, 107.243733, 104.960815, 105.773519 |
| Chat list layout | TextView | Prepared | 2 | 105.836141, 105.151368, 106.029907, 105.163696, 106.148235, 106.806274, 105.915772, 106.537191, 105.470378 |
| Chat list layout | TextView | Prepared | 3 | 105.792237, 104.985759, 106.233969, 105.202312, 106.037313, 105.023519, 108.122315, 103.831868, 105.527914 |
| Native layout, mount, and first draw | RN Text | Default | 1 | 881.707317, 837.964437, 856.421021, 898.376953, 938.920086, 920.501587, 920.434083, 945.366903, 973.275920 |
| Native layout, mount, and first draw | RN Text | Default | 2 | 838.632121, 856.512940, 918.525636, 874.689779, 898.363078, 915.677613, 993.886068, 929.058635, 944.086792 |
| Native layout, mount, and first draw | RN Text | Default | 3 | 810.255981, 830.316895, 858.538086, 882.096436, 950.930786, 896.649536, 920.383545, 936.203899, 1069.728068 |
| Native layout, mount, and first draw | RN Text | Prepared | 1 | 450.456421, 453.986694, 449.201132, 449.761231, 450.976074, 452.612101, 450.856934, 450.883179, 457.046997 |
| Native layout, mount, and first draw | RN Text | Prepared | 2 | 460.256958, 456.339681, 454.989461, 458.480917, 455.683350, 453.151327, 455.571737, 455.449382, 456.420370 |
| Native layout, mount, and first draw | RN Text | Prepared | 3 | 455.401205, 452.610229, 449.330403, 455.562012, 450.121867, 450.776652, 450.321574, 450.634481, 452.205770 |
| Native layout, mount, and first draw | TextView | Default | 1 | 434.785848, 430.389119, 433.890056, 432.882406, 438.529908, 431.999227, 432.440918, 433.434327, 435.787842 |
| Native layout, mount, and first draw | TextView | Default | 2 | 432.377116, 433.922404, 439.330608, 431.114177, 431.867879, 432.432536, 435.955526, 437.648560, 431.398397 |
| Native layout, mount, and first draw | TextView | Default | 3 | 431.014608, 431.614298, 432.244833, 436.505087, 430.949259, 431.179159, 431.707316, 431.504150, 434.834270 |
| Native layout, mount, and first draw | TextView | Prepared | 1 | 434.339437, 438.121297, 434.607829, 436.454835, 437.656697, 439.462199, 436.887695, 437.556966, 435.152669 |
| Native layout, mount, and first draw | TextView | Prepared | 2 | 433.759969, 433.328369, 435.003256, 434.793457, 432.550293, 437.562459, 433.614502, 435.291260, 439.029012 |
| Native layout, mount, and first draw | TextView | Prepared | 3 | 436.104655, 430.412273, 435.470582, 431.780680, 431.654257, 434.593709, 429.248047, 432.491536, 430.721924 |
| Retained paragraph measurement | RN Text | Default | 1 | 19.099569, 19.174113, 19.174723, 20.230266, 19.130981, 19.135905, 19.238485, 19.137044, 19.136596 |
| Retained paragraph measurement | RN Text | Default | 2 | 19.023763, 19.091065, 19.014120, 18.977946, 18.968669, 19.008098, 19.111491, 19.003215, 19.107219 |
| Retained paragraph measurement | RN Text | Default | 3 | 19.165813, 19.166423, 19.124715, 19.138468, 19.522095, 19.149455, 20.895345, 19.664348, 20.803222 |
| Retained paragraph measurement | RN Text | Prepared | 1 | 0.290650, 0.251384, 0.250163, 0.250488, 0.250285, 0.250366, 0.250244, 0.250204, 0.250244 |
| Retained paragraph measurement | RN Text | Prepared | 2 | 0.236288, 0.239298, 0.235311, 0.235352, 0.235149, 0.235229, 0.235189, 0.235352, 0.235230 |
| Retained paragraph measurement | RN Text | Prepared | 3 | 0.246175, 0.246338, 0.246216, 0.250041, 0.246378, 0.246175, 0.246378, 0.246297, 0.246012 |
| Retained paragraph measurement | TextView | Default | 1 | 0.861898, 0.827718, 0.826538, 0.826457, 0.825887, 0.838582, 0.826660, 0.826620, 0.826661 |
| Retained paragraph measurement | TextView | Default | 2 | 0.823079, 0.858887, 0.825481, 0.824137, 0.846354, 0.823812, 0.834025, 0.823649, 0.823731 |
| Retained paragraph measurement | TextView | Default | 3 | 0.732341, 0.733886, 0.731893, 0.732788, 0.741944, 0.733114, 0.731608, 0.732788, 0.732951 |
| Retained paragraph measurement | TextView | Prepared | 1 | 0.820190, 0.820191, 0.847453, 0.819865, 0.818969, 0.820191, 0.819621, 0.950562, 0.819987 |
| Retained paragraph measurement | TextView | Prepared | 2 | 0.817179, 0.851970, 0.817546, 0.817749, 0.817016, 0.817342, 0.845703, 0.818156, 0.817545 |
| Retained paragraph measurement | TextView | Prepared | 3 | 0.819702, 0.917155, 0.820882, 0.819702, 0.819987, 0.819336, 0.837606, 0.819336, 0.819458 |
| Short labels, natural line height | RN Text | Default | 1 | 53.739339, 53.766601, 53.508993, 53.560588, 53.517090, 55.487264, 51.122437, 53.545207, 53.534546 |
| Short labels, natural line height | RN Text | Default | 2 | 53.991170, 53.789266, 53.824381, 53.946370, 53.849162, 56.833944, 50.820557, 55.547120, 53.843343 |
| Short labels, natural line height | RN Text | Default | 3 | 53.451782, 53.501994, 53.347005, 53.289836, 53.232625, 55.807291, 50.671875, 53.521606, 53.507365 |
| Short labels, natural line height | RN Text | Prepared | 1 | 58.176677, 58.329142, 58.057820, 58.184123, 58.357544, 60.742675, 58.049113, 58.213623, 58.055949 |
| Short labels, natural line height | RN Text | Prepared | 2 | 58.871989, 58.735758, 58.699096, 58.634319, 62.200276, 56.334758, 58.830851, 58.864868, 58.834514 |
| Short labels, natural line height | RN Text | Prepared | 3 | 58.536581, 58.627279, 58.520629, 60.269246, 58.637980, 61.028727, 58.803263, 58.797038, 58.575399 |
| Short labels, natural line height | TextView | Default | 1 | 37.432047, 39.495443, 35.242066, 34.618083, 37.003214, 37.149048, 37.229207, 37.153158, 37.010376 |
| Short labels, natural line height | TextView | Default | 2 | 36.994263, 37.154337, 37.011068, 36.991292, 37.122803, 37.134725, 37.094035, 37.042602, 37.154867 |
| Short labels, natural line height | TextView | Default | 3 | 37.061482, 37.024170, 37.040121, 36.820231, 36.895385, 36.934204, 38.959187, 34.118653, 35.705118 |
| Short labels, natural line height | TextView | Prepared | 1 | 37.214803, 41.061321, 36.542684, 34.732788, 36.533122, 37.138753, 37.027018, 36.963095, 36.861369 |
| Short labels, natural line height | TextView | Prepared | 2 | 37.116374, 37.416097, 39.884847, 34.742106, 34.768839, 36.986206, 37.017253, 36.909098, 36.935872 |
| Short labels, natural line height | TextView | Prepared | 3 | 36.831503, 36.846151, 36.839397, 36.754435, 36.767456, 36.838461, 36.688762, 38.461588, 38.852458 |
| Plain text creation and layout | RN Text | Default | 1 | 140.946655, 141.071533, 140.988485, 140.983806, 144.143473, 141.134440, 140.973226, 140.969076, 143.553671 |
| Plain text creation and layout | RN Text | Default | 2 | 145.802369, 141.565674, 141.518473, 143.079915, 144.670492, 142.464843, 142.021810, 141.453207, 141.775188 |
| Plain text creation and layout | RN Text | Default | 3 | 142.741211, 140.991821, 141.473999, 142.961182, 141.120565, 141.762859, 140.801026, 142.439168, 143.368612 |
| Plain text creation and layout | RN Text | Prepared | 1 | 146.442138, 143.268637, 143.621786, 142.789876, 142.647786, 145.295695, 145.649821, 145.706502, 145.520793 |
| Plain text creation and layout | RN Text | Prepared | 2 | 148.493408, 148.407552, 147.266724, 147.504476, 150.007243, 145.630493, 147.656616, 147.669678, 147.803223 |
| Plain text creation and layout | RN Text | Prepared | 3 | 147.247151, 145.655151, 146.154135, 146.484823, 146.336466, 146.654013, 146.177735, 146.748495, 146.136312 |
| Plain text creation and layout | TextView | Default | 1 | 95.391398, 98.026937, 97.862834, 97.817017, 98.052653, 98.101237, 98.085205, 97.771728, 99.174765 |
| Plain text creation and layout | TextView | Default | 2 | 98.371134, 98.060994, 98.142537, 96.689575, 99.893799, 98.255737, 97.866862, 98.001791, 98.329996 |
| Plain text creation and layout | TextView | Default | 3 | 97.711670, 97.426229, 97.243123, 98.033610, 97.676758, 97.910238, 97.649780, 97.928955, 98.147949 |
| Plain text creation and layout | TextView | Prepared | 1 | 97.758097, 97.755819, 97.806722, 97.775024, 97.890422, 97.919881, 97.714315, 99.179362, 95.149374 |
| Plain text creation and layout | TextView | Prepared | 2 | 98.013631, 97.608358, 98.056153, 97.847127, 98.012247, 98.053060, 99.696004, 97.535808, 99.382324 |
| Plain text creation and layout | TextView | Prepared | 3 | 98.117391, 97.504923, 98.548503, 98.789836, 99.405477, 97.586915, 96.655274, 98.056234, 97.823527 |
| Manager queries, 768 keys | RN Text | Default | 1 | 3.983236, 3.899862, 3.903035, 3.903402, 3.930298, 3.899007, 3.900309, 3.903565, 3.920817 |
| Manager queries, 768 keys | RN Text | Default | 2 | 3.907918, 3.907064, 3.895304, 3.919759, 3.905111, 3.893595, 3.903930, 3.920817, 3.900716 |
| Manager queries, 768 keys | RN Text | Default | 3 | 3.914755, 3.953287, 3.919799, 3.914551, 3.916097, 3.940185, 3.910237, 3.915446, 3.917196 |
| Manager queries, 768 keys | RN Text | Prepared | 1 | 1738.948365, 1742.187094, 1741.573813, 1741.633423, 1743.507447, 1756.457805, 1743.924602, 1728.675456, 1730.662151 |
| Manager queries, 768 keys | RN Text | Prepared | 2 | 1776.488404, 1771.924399, 1777.434450, 1774.720704, 1779.682007, 1773.749879, 1779.170208, 1759.893271, 1764.097169 |
| Manager queries, 768 keys | RN Text | Prepared | 3 | 1755.655112, 1756.769369, 1755.174602, 1755.557455, 1762.920655, 1756.151735, 1758.512248, 1745.619712, 1744.323202 |
| Manager queries, 768 keys | TextView | Default | 1 | 1.470907, 1.457194, 1.489705, 1.459554, 1.578206, 1.482056, 1.460815, 1.491618, 1.478597 |
| Manager queries, 768 keys | TextView | Default | 2 | 1.440592, 1.463826, 1.456990, 1.444905, 1.918539, 1.477539, 1.450317, 1.500081, 1.443807 |
| Manager queries, 768 keys | TextView | Default | 3 | 1.471150, 1.447510, 1.457641, 1.464559, 1.449829, 1.980916, 1.451619, 1.466553, 1.477092 |
| Manager queries, 768 keys | TextView | Prepared | 1 | 1.680868, 1.449870, 1.471395, 1.456299, 1.480998, 1.449829, 1.461060, 1.483561, 1.461019 |
| Manager queries, 768 keys | TextView | Prepared | 2 | 1.469401, 1.452515, 1.494141, 1.453898, 1.455160, 1.500935, 1.452311, 1.559529, 1.473592 |
| Manager queries, 768 keys | TextView | Prepared | 3 | 1.482666, 1.482381, 1.498942, 1.464966, 1.482096, 1.505982, 1.466512, 1.496826, 1.457031 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 1 | 3.939331, 3.946737, 3.913818, 3.911092, 3.903279, 3.972616, 3.920654, 3.919556, 3.908040 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 2 | 3.914999, 3.905395, 3.901123, 3.926839, 3.902304, 3.903971, 3.901367, 3.882121, 3.926269 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 3 | 3.978393, 3.929484, 3.932902, 3.886922, 3.907674, 3.937947, 3.929199, 3.923869, 3.920980 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 1 | 1954.377727, 1835.131471, 1831.190756, 1833.711102, 1837.053183, 1835.395875, 1829.926393, 1828.470297, 1828.257081 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 2 | 1872.307171, 1896.848918, 1881.228435, 1922.733277, 1856.875978, 1875.060181, 1860.575399, 1895.872397, 1886.391277 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 3 | 1841.788575, 1832.794679, 1846.568035, 1863.081747, 1853.596518, 1833.829997, 1832.006796, 1833.404949, 1835.467571 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 1 | 1.537272, 1.562500, 1.559327, 1.559855, 1.575359, 1.545898, 2.092408, 1.585612, 1.557902 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 2 | 1.529622, 1.530640, 2.103109, 1.668661, 1.537435, 1.513347, 1.724894, 1.685221, 1.509074 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 3 | 1.534261, 1.536418, 1.510539, 1.541097, 1.531941, 1.513469, 1.564656, 1.509481, 1.588420 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 1 | 1.524780, 1.563069, 1.526856, 1.535645, 1.566202, 1.527832, 1.554322, 1.531942, 1.527059 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 2 | 1.546753, 1.519978, 1.534994, 1.549439, 1.519246, 1.552450, 1.519938, 1.671184, 2.180338 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 3 | 1.532797, 1.687745, 1.543986, 1.535034, 1.552653, 1.529826, 1.569946, 1.527425, 1.535848 |
| Styled text creation and layout | RN Text | Default | 1 | 322.116048, 318.874797, 316.510417, 319.549560, 317.806193, 316.058472, 317.465617, 315.189209, 316.415568 |
| Styled text creation and layout | RN Text | Default | 2 | 319.114665, 316.142497, 321.116578, 319.205567, 315.992920, 318.726563, 316.193115, 322.665690, 325.062134 |
| Styled text creation and layout | RN Text | Default | 3 | 318.786052, 317.725790, 317.147664, 316.166789, 319.115601, 319.309734, 317.545818, 316.680786, 316.852621 |
| Styled text creation and layout | RN Text | Prepared | 1 | 298.737956, 300.035848, 298.015381, 301.834595, 305.097128, 298.549479, 303.257650, 301.475789, 304.433675 |
| Styled text creation and layout | RN Text | Prepared | 2 | 304.310751, 302.941447, 304.947592, 304.321330, 305.662598, 307.630290, 303.183879, 310.382569, 304.135742 |
| Styled text creation and layout | RN Text | Prepared | 3 | 300.615356, 300.637533, 297.311930, 302.941935, 297.949992, 298.708089, 297.467041, 296.642497, 299.065064 |
| Styled text creation and layout | TextView | Default | 1 | 189.730917, 190.322387, 190.106201, 190.295898, 190.034139, 192.490071, 189.322469, 188.990967, 188.942098 |
| Styled text creation and layout | TextView | Default | 2 | 189.869059, 189.469279, 188.853394, 190.962768, 189.359090, 189.176798, 189.109253, 190.051229, 193.916057 |
| Styled text creation and layout | TextView | Default | 3 | 189.196696, 191.961223, 188.526286, 188.431194, 188.577881, 188.792359, 189.731689, 189.270792, 188.940959 |
| Styled text creation and layout | TextView | Prepared | 1 | 193.596111, 190.077596, 192.215861, 191.330118, 193.785888, 189.659343, 189.674479, 190.133829, 191.736369 |
| Styled text creation and layout | TextView | Prepared | 2 | 191.136149, 189.389120, 189.165650, 189.065064, 189.654216, 189.866862, 193.665121, 189.783651, 191.419148 |
| Styled text creation and layout | TextView | Prepared | 3 | 188.826701, 190.361531, 188.316691, 188.286336, 190.103475, 188.278402, 187.754028, 187.927042, 193.538412 |

</details>
