# 夹具载荷记录 / Fixture load-test record

空白记录表。表里没有实测数据，也不预填试验载荷或合格线。几何复核已经完成；打印、装配、载荷和疲劳记录仍按 [vigil.md](../vigil.md) 的「打印与验证」和 [vigil.pdf](../vigil.pdf) 第 5 页留待实物补充。试验载荷和通过标准由学校负责老师按实际使用条件填写。

Blank record. No measurements, test loads, or pass limits are filled in. Geometry has been checked; print, assembly, load, and fatigue records are still open, as described in [vigil.md](../vigil.md) and on page 5 of [vigil.pdf](../vigil.pdf). The responsible teacher sets the test load and the pass criteria from the actual conditions of use.

同一列也在 [load-test-record.csv](load-test-record.csv) 里。CSV 只有表头，每一行对应一次加载，并重复试样和打印栏，方便把多次加载记在同一张表上。

The same columns are in [load-test-record.csv](load-test-record.csv). That file has a header and no data rows. Each filled row is one load step and repeats the sample and print fields.

## 试样与打印 / Sample and print

打印栏对应说明里已经点名的项目：打印机型号、材料牌号、喷嘴、壁线、填充、打印方向，以及预定最大拉力。仿生握把的模型是直立的，纵向通道与打印 Z 轴平行。指屈把手在切片时查看横孔顶部的桥接或支撑，并确认孔内支撑能从两端清理。

These fields are the ones named in the notes: printer, material grade, nozzle, wall lines, infill, print orientation, and the planned maximum pull. The anatomical grip is modeled upright, with the longitudinal channel parallel to print Z. For a finger-flexor grip, check bridging or support at the crown of the transverse slot, and confirm that support inside the slot can be cleared from both ends.

| 栏 / Field | 值 / Value |
| --- | --- |
| sample_id 试样编号 | |
| model 款式（仿生握把，或 03–09） | |
| date 日期 | |
| printer 打印机型号 | |
| material 材料牌号 | |
| nozzle 喷嘴 | |
| wall_lines 壁线 | |
| infill 填充 | |
| print_orientation 打印方向 | |
| planned_max_pull 预定最大拉力 | |

## 空载配合 / Unloaded fit

空载时记录带宽、缝合或叠层厚度、开口尺寸，并查看侧窗边缘、外回程、接头与手指之间的间隙。指屈把手核对弹力带宽 26–40 mm、穿孔部分总厚不超过 6 mm；仿生握把核对 25 mm 织带、穿孔部分总厚不超过 6 mm。折叠处和较厚的端头单独测量。

Unloaded, record the band width, the stitched or stacked thickness, and the opening size, and look at the clearance between the side-window edges, the outer return, the connectors, and the fingers. Finger-flexor grips are designed for a band 26–40 mm wide and at most 6 mm thick at the pass-through. The anatomical grip is designed for 25 mm webbing, also at most 6 mm thick at the pass-through. Measure a fold or a thicker end on its own.

| 栏 / Field | 值 / Value |
| --- | --- |
| band_width 带宽或织带宽 | |
| stack_thickness 缝合或穿孔总厚 | |
| opening_size 开口尺寸 | |
| fit_notes 空载间隙 | |

## 加载步骤 / Load steps

在夹具上按实际拉力方向检验完整装配，先做无人握持的静载、保持和重复加载。每一步记录拉力、方向、保持时间、加载次数和变形，并观察侧窗旁、孔口和腰部有没有裂纹、层间开裂、永久变形或织带磨损。仿生握把的侧窗旁约 5.5 mm 是几何复核时的采样径向余量，实物受力时要特别看这里。旋前、提腕和侧压不沿用屈腕布置的结论，方向和力臂要单独记录。

On a fixture, test the complete assembly along the actual pull direction. Start with an unattended static load, a hold, and repeated loading. For each step record the pull, direction, hold time, number of cycles, and deformation. Watch beside the side windows, at the openings, and at the waist for cracks, layer separation, permanent set, or webbing wear. The anatomical grip's sampled radial margin beside the side window is about 5.5 mm; watch that region under load. Pronation, wrist raise, and side press need their own direction and moment arm, recorded separately from the wrist-flexion setup.

| step | direction | load | load_unit | hold_time | cycles | deflection | permanent_set | cracks | layer_split | webbing_wear | failure_mode | where_observed | result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |

`deflection` 记这一步的变形，`permanent_set` 记卸载后的永久变形。`failure_mode` 在出现破坏时填写，没有破坏就留空。`result` 对照老师写下的通过标准，标准本身写在试样备注或 `pass_criteria` 栏，不在这张空表里代填。

`deflection` is the deformation at that step. `permanent_set` is what remains after unloading. Fill `failure_mode` when something breaks, and leave it empty when nothing does. `result` is judged against the pass criteria the teacher wrote down. Put those criteria in the sample notes or in `pass_criteria`. This blank sheet does not supply them.
