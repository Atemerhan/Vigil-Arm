// vigil
// vigil finger flexion grip with a transverse band passage. Millimetres.
// Folder 03: 宽体双肩握把 / wide dual-shoulder grip.
// Historical preset id: grip_01. Folders 03–09 map to grip_01–grip_07
// (folder number minus 2). The cylindrical sleeve 02 in vigil.pdf is a
// different model and is not generated from this file.
variant = "folder_03"; // [folder_03, folder_04, folder_05, folder_06, folder_07, folder_08, folder_09]
custom_width = 0;       // [0:1:85]
custom_depth = 0;       // [0:1:80]
custom_height = 0;      // [0:1:155]
texture_enabled = true;
band_passage = true;
band_width = 40;       // [26:1:40]
band_stack = 6;        // [2:0.5:6]

include <../finger_flexor.scad>
