// vigil
// vigil finger flexion grip with a transverse band passage. Millimetres.
variant = "grip_01"; // [grip_01, grip_02, grip_03, grip_04, grip_05, grip_06, grip_07]
custom_width = 0;       // [0:1:85]
custom_depth = 0;       // [0:1:80]
custom_height = 0;      // [0:1:155]
texture_enabled = true;
band_passage = true;
band_width = 40;       // [26:1:40]
band_stack = 6;        // [2:0.5:6]

/* [Hidden] */
// Name, W, D, H, rear rail width ratio, profile power, recess depth,
// front texture, shallow guide marks, two end recess diameters.
presets = [
    ["grip_01", 68,62,123, .60, .82,16, "fine_grid", true, [26,12]],
    ["grip_02",    53,52,113, .51, 1.0,17, "smooth", false, [24,12]],
    ["grip_03",       64,58,117, .50, 1.0,14, "fine_grid", false, [24,12]],
    ["grip_04",     68,61,123, .63, .74,15, "vertical", true, [0,0]],
    ["grip_05",          65,61,118, .48, .91,16, "coarse_grid", true, [0,0]],
    ["grip_06",        68,64,120, .75, .75,15, "horizontal", false, [27,13]],
    ["grip_07",       60,49,110, .73, .65, 4, "fine_grid", true, [0,0]]
];

p = [for (item=presets) if(item[0]==variant) item][0];
assert(!is_undef(p), "Choose a named preset.");
w = custom_width > 0 ? custom_width : p[1];
d = custom_depth > 0 ? custom_depth : p[2];
h = custom_height > 0 ? custom_height : p[3];
assert(w>=45 && d>=43 && h>=92, "Minimum fit model size is 45 x 43 x 92 mm.");
assert(!band_passage || (w==p[1] && d==p[2] && h==p[3]),
       "Recheck clearances before enabling the band passage at custom body sizes.");
assert(band_width>=26 && band_width<=40 && band_stack>=2 && band_stack<=6);
$fn=36;
band_slot_width = band_width+4;
band_slot_height = band_stack+2;
band_slot_center_y = d*.23;
band_slot_center_z = h*.515;
band_lip = 1.25;
rail_half_width = w*p[4]/2;
sides=96;
bands=floor((h-10)/(p[7]=="coarse_grid" ? 6 : 3.5));
z_step=(h-10)/bands;
is_grid=p[7]=="fine_grid" || p[7]=="coarse_grid";
axial=p[7]=="horizontal" || is_grid;
pattern_amplitude = !texture_enabled || p[7]=="smooth" ? 0 : p[7]=="coarse_grid" ? 0.65 : 0.38;
lip=1.25;

function wave(i) = i%4==1 || i%4==2 ? 1 : 0;
function signed_power(v,power) = sign(v)*pow(abs(v),power);
function span_point(ring,j) =
    let(a=j*360/sides, x=cos(a), y=sin(a),
        azimuth=p[7]=="horizontal" ? 1 : wave(j),
        mask=pow(max(0,-y),2),
        bump=pattern_amplitude*ring[2]*azimuth*mask,
        rim=ring[1])
    [(w/2-rim)*signed_power(x,p[5]),
     -(d*.14)+(d*.36-rim)*signed_power(y,p[5])-bump,ring[0]];

rings = concat([[0,lip,0],[lip,0,0]],
    axial ? [for (b=[0:bands-1], k=[0:3])
        [5+(b+[0,.20,.70,.92][k])*z_step,0,wave(k)]] : [[5,0,1],[h-5,0,1]],
    axial ? [[h-5,0,0],[h-lip,0,0],[h,lip,0]] : [[h-lip,0,0],[h,lip,0]]
);

module grip_face() {
    base = len(rings)*sides;
    t = len(rings)-1;
    polyhedron(
        points=concat([for (ring=rings,j=[0:sides-1]) span_point(ring,j)], [[0,-d*.14,0],[0,-d*.14,h]]),
        faces=concat(
            [for(k=[0:t-1],j=[0:sides-1])
                let(a=k*sides+j,b=k*sides+(j+1)%sides,c=b+sides,e=a+sides)
                each [[a,c,b],[a,e,c]]],
            [for(j=[0:sides-1]) [base,j,(j+1)%sides]],
            [for(j=[0:sides-1]) [base+1,t*sides+(j+1)%sides,t*sides+j]]
        ), convexity=8);
}

module rail_profile() {
    rail_width = w*p[4];
    y_center = d*.25;
    corner = variant=="grip_06" ? 2.4 : 4;
    hull()
        for (x=[-1,1],y=[-1,1])
            translate([x*(rail_width/2-corner),y_center+y*(d/4-corner)]) circle(r=corner);
}

module blind_seat(y,diam) {
    if (diam>0)
        translate([0,y,-1]) cylinder(h=9,d1=diam+1.4,d2=max(0.1,diam-11));
}

module guide_mark(z) {
    hull()
        for (off=[-6,6])
            translate([w*p[4]*.20,d/2+.75,z+off]) sphere(r=2.1);
}

// The band lies in the YZ plane and passes along X through the rear rail.
module band_slot_profile(flare) {
    let(radius=min(3,band_slot_height/2-.5))
        offset(r=radius+flare)
            square([band_slot_width-2*radius,band_slot_height-2*radius],center=true);
}

module band_slot_slice(x,flare) {
    translate([x,band_slot_center_y,band_slot_center_z])
        rotate([0,90,0])
            linear_extrude(height=.035,center=true) band_slot_profile(flare);
}

module transverse_passage() {
    inner = rail_half_width-band_lip;
    translate([0,band_slot_center_y,band_slot_center_z])
        rotate([0,90,0])
            linear_extrude(height=2*inner+.05,center=true) band_slot_profile(0);
    for (side=[-1,1]) {
        for (i=[0:7]) {
            hull() {
                for (t=[i/8,(i+1)/8])
                    band_slot_slice(side*(inner+band_lip*t),band_lip*(1-sqrt(1-t*t)));
            }
        }
        hull() {
            band_slot_slice(side*rail_half_width,band_lip);
            band_slot_slice(side*(w/2+1),band_lip);
        }
    }
}

difference() {
    union() {
        grip_face();
        linear_extrude(height=h) rail_profile();
    }
    translate([0,-d*.045,h+9])
        rotate([0,90,0]) cylinder(h=w+4,r=p[6]+9,center=true,$fn=60);
    if (band_passage) transverse_passage();
    blind_seat(-d*.14,p[9][0]);
    blind_seat(d*.34,p[9][1]);
    if (p[8]) {
        guide_mark(h*.25);
        guide_mark(h*.78);
    }
}
