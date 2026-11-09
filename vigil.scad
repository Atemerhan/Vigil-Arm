// vigil | Contoured training handle development model. Millimetres.
hand_width = 108;       // [85:1:125]
hand_height = 140;      // [110:1:165]
hand_depth = 64;        // [50:1:82]
// Window sizes are nominal at the default overall envelope.
window_width = 22;      // [17:1:25]
window_height = 34;     // [26:1:40]
back_texture = true;
webbing_width = 25;     // [18:1:25]
webbing_stack = 6;      // [3:0.5:8]
axial_passage = true;

/* [Hidden] */
$fn = 48;
steps = 76;
assert(webbing_width >= 18 && webbing_width <= 25);
assert(webbing_stack >= 3 && webbing_stack <= 8);
// The passage is validated against the default body dimensions.
assert(!axial_passage || (hand_width==108 && hand_height==140 && hand_depth==64 &&
                        window_width==22 && window_height==34),
       "Recheck the passage ligaments before changing body dimensions.");
passage_width = webbing_width+4;
passage_depth = webbing_stack+4;
sides = 96;
profile = [
    [0, 26, 20], [4, 27.5, 21], [17, 28, 22], [25, 33, 25],
    [40, 46, 29], [59, 53, 32], [75, 54, 32], [90, 51, 30],
    [109, 47, 27], [123, 45, 24], [134, 39, 21], [140, 34, 18]
];

function limit(value, low, high) = min(high, max(low, value));
function smooth(value) = let(t = limit(value, 0, 1)) t*t*(3-2*t);

function section(z, i=0) =
    i >= len(profile)-2 || z <= profile[i+1][0] ? i : section(z, i+1);

function slope(i, col) =
    let(a = max(i-1, 0), b = min(i+1, len(profile)-1))
    (profile[b][col]-profile[a][col])/(profile[b][0]-profile[a][0]);

function span(z, col) =
    let(i = section(z), a = profile[i], b = profile[i+1],
        d = b[0]-a[0], t = (z-a[0])/d)
    limit((2*t*t*t-3*t*t+1)*a[col] + (t*t*t-2*t*t+t)*d*slope(i,col)
          + (-2*t*t*t+3*t*t)*b[col] + (t*t*t-t*t)*d*slope(i+1,col),
          min(a[col],b[col]), max(a[col],b[col]));

function surface(z, a) =
    let(front = max(0, -sin(a)),
        palm = 11*pow(front, 5)*smooth((z-24)/25)*smooth((127-z)/22),
        pattern = back_texture ? 0.48*pow(max(0,sin(a)), 2)*
                  smooth((z-18)/8)*smooth((121-z)/12)*
                  pow(abs(cos(a*12)), 3)*pow(abs(cos(z*180/4.5)), 2) : 0)
    [span(z,1)*cos(a), (span(z,2)+pattern)*sin(a)+palm, z];

loft = [for (k=[0:steps], j=[0:sides-1]) surface(k*140/steps, j*360/sides)];
loft_y = [for (point=loft) point[1]];
loft_depth = max(loft_y)-min(loft_y);

module body() {
    vertices = concat(loft, [[0,0,0], [0,0,140]]);
    bottom = (steps+1)*sides;
    top = bottom+1;
    faces = concat(
        [for (k=[0:steps-1], j=[0:sides-1])
            let(a=k*sides+j, b=k*sides+(j+1)%sides, c=b+sides, d=a+sides)
            each [[a,c,b],[a,d,c]]],
        [for (j=[0:sides-1]) [bottom,j,(j+1)%sides]],
        [for (j=[0:sides-1]) [top,steps*sides+(j+1)%sides,steps*sides+j]]
    );
    polyhedron(points=vertices, faces=faces, convexity=8);
}

module thumb_window(x) {
    // Soft entry tapers. Nominal oval at the middle of the cut.
    translate([x,0,105])
        rotate([90,0,0]) scale([window_width/2,window_height/2,1])
            cylinder(h=34.4,r=1,center=true);
    union() {
        translate([x,-17,105])
            rotate([90,0,0]) scale([window_width/2,window_height/2,1])
                cylinder(h=16,r1=1,r2=1.13);
        translate([x,17,105])
            rotate([-90,0,0]) scale([window_width/2,window_height/2,1])
                cylinder(h=16,r1=1,r2=1.13);
    }
}

// Normalize the original loft envelope before applying fit dimensions.
module contoured_body() {
    scale([hand_width/108, hand_depth/loft_depth, hand_height/140])
    difference() {
        body();
        for (side=[-1,1]) {
            thumb_window(side*31);
            translate([side*23,-29,64])
                rotate([0,side*9,0]) scale([12.5,15,25]) sphere(1);
        }
        translate([0,0,148])
            rotate([90,0,0]) cylinder(r=20,h=100,center=true);
    }

}

// Local lead-ins at the two ends preserve the hand contour.
// The upper mouth follows the original curved saddle.
module passage_slice(z, flare) {
    translate([0,0,z])
        linear_extrude(height=.04,center=true)
            offset(r=2+flare)
                square([passage_width-4,passage_depth-4],center=true);
}

module webbing_passage() {
    levels = [[-1,2],[0,2],[1,1.1],[2.5,.35],[4,0],
              [123,0],[125,.2],[127,.65],[129,1.3],[132,2],[142,2]];
    for (i=[0:len(levels)-2]) {
        hull() {
            passage_slice(levels[i][0],levels[i][1]);
            passage_slice(levels[i+1][0],levels[i+1][1]);
        }
    }
}

difference() {
    contoured_body();
    if(axial_passage) webbing_passage();
}
