/*
<gt2_spiral_belt.scad>
Parametric spiral GT2 timing belt for OpenSCAD.

ORIGINAL DESIGN
  gt2.scad - GT2 belt profile, straight belt and pulley library
  Copyright (C) 2023  Alessandro Garosi (tdo_brandano@hotmail.com)
  The GT2 tooth geometry, the 2D vector helpers and the straight belt /
  pulley modules in this file are Alessandro Garosi's original work and
  are used here unchanged.

THIS VERSION (modified 2026-09-27)
  Co-created by Saad Chinoy and Stephane Godin.
  Changes from the original:
    - New spiral belt: the straight GT2 profile is wrapped onto an
      Archimedean spiral by exact arc length along the pitch line, so the
      2 mm GT2 pitch and tooth shape are preserved.
    - Parametric total belt length and overall spiral diameter, with a
      solver for the inner radius or the gap between turns.
    - Parameters exposed to the OpenSCAD Customizer.
    - Sanity checks and a summary printed to the console.
    - Original demo() and top-level straight belt call removed.

LICENSE
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

// ============================================================================
//  CUSTOMIZER PARAMETERS  (Window > Customizer in OpenSCAD)
// ============================================================================

/* [Belt] */
// Pitch length of the belt in mm (rounded down to whole 2 mm teeth unless "Keep partial" is ticked)
total_length = 400; // [20:2:5000]
// Belt width in mm = overall height of the part
belt_width = 6; // [2:0.5:30]
// Teeth face the centre (like a belt wound on a spool); untick for teeth facing out
teeth_inward = true;
// Keep a toothless tail if the length isn't a multiple of 2 mm
keep_partial = false;

/* [Spiral size] */
// Overall outside diameter of the finished spiral in mm
outer_diameter = 50; // [10:0.5:500]
// What gets solved so the belt fits exactly in the outer diameter
fit_mode = "inner"; // [inner:Solve inner radius - keep turn gap, gap:Solve turn gap - keep inner radius, manual:Manual - ignore outer diameter]
// Pitch-line radius where the spiral starts, in mm (used by "gap" and "manual")
inner_radius = 12; // [2:0.5:250]
// Air gap between adjacent turns in mm (used by "inner" and "manual")
turn_gap = 0.6; // [0.1:0.05:10]
// Smallest acceptable gap between turns in mm (print clearance check)
min_gap = 0.3; // [0:0.05:2]

/* [Quality] */
// Max chord length along the spiral in mm (smaller = smoother, slower)
max_seg = 0.25; // [0.05:0.05:1]
// Segments per full circle for the tooth arcs
tooth_resolution = 32; // [8:4:128]

/* [Hidden] */
$fn = tooth_resolution;


//Returns an inverted vector
function v_invert(v) = [for (i=[1:1:len(v)]) v[len(v)-i]];

//Tests if two points on an XY plane are the same with an error of delta. Plain bounding box test for speed
function p_match(p1, p2, delta=0.0001) = abs(p1[0]-p2[0]) <= delta && abs(p1[1]-p2[1]) <= delta;
    
//Removes consecutive duplicate points from a vector
function rm_dup(v) = [for (i=[0:1:len(v)-1]) if (i==0 || !p_match(v[i], v[i-1])) v[i]];

//Work out how many segments for an angle
//This does not exactly respect the $fa and $fn definition, but approximates it 
//so that it will always have an end point matching the end of the arch
function a2d_seg(a) = $fn ? ($fn/360)*a : a/$fa;

//Coordinates for a point at a set distance and angle from the origin
function a2d_pt(r, a) = [sin(a)*r,cos(a)*r];

//Coordinates for the points of an arch
function a2d(r, a) = [for (i=[0:(a/ceil(a2d_seg(a))):a]) a2d_pt(r, i)];

//Scale a list of 2d coordinate, can be used for mirroring
function v2d_scale(xy, v) = [for (p=v) [p[0]*xy[0], p[1]*xy[1]]];
function v2d_xflip(v) = v2d_scale([-1,1],v);
function v2d_yflip(v) = v2d_scale([1,-1],v);

//Translation of a list of 2d coordinates
function v2d_tx(xy, v) = [for (p=v) [p[0]+xy[0], p[1]+xy[1]]];
    
//Rotation of a list of 2d coordinates
function v2d_rot(a, v) = [for (p=v) [p[0]*cos(a)-p[1]*sin(a), p[1]*cos(a)+p[0]*sin(a)]];

//Translates by a radius and "bends" a list of points. This allows the creation of an arc of a circumference
//from a list of points. Good to make pulleys.
function v2d_bend(r, v) = [for (p=v, a=p[0]/((2*PI*r)/360))[(p[1]+r)*sin(a), (p[1]+r)*cos(a)]];

//Returns the coordinates for a GT2 tooth as the concatenation of two half-teeth
function gt2_t() = concat(
    v2d_xflip(gt2_ht()),
    v_invert(gt2_ht())
);

//Returns the coordinates for a GT2 half-tooth, shaped out of 3 arcs
//This is accurate, but can be probably done better with fewer "magic values"
//by actually calculating the end position of each arch
function gt2_ht() = v2d_xflip(concat(
    v2d_tx([-0.74,-0.404], a2d(0.15, 82.5)),
    v2d_tx([0.4, -0.254], v_invert(v2d_rot(116, a2d(1,18.5)))),
    v2d_tx([0,-0.449], v_invert(v2d_rot(180, a2d(0.555,64))))
));



//Profile of N gt2 teeth
function gt2_ts(tn) = [for (i=[0:tn-1], vtx=v2d_tx([2*i,0], gt2_t())) vtx];


module gt2_2d(teeth=10){
    tn=teeth;
    //Add the back of the belt to close the polygon
    pts = concat(gt2_ts(tn),[[(tn-1)*2.0+1,-0.254], [(tn-1)*2.0+1,0.376], [-1,0.376], [-1,-0.254]]);
    polygon(rm_dup(pts));
}

//gt2_2d(1);

module gt2_belt(length=10, h=6, center=false){
    dx=center?-length/2:0;
    dz=center?-h/2:0;
    translate([dx,0,dz]) difference(){
        translate([1,0,0])linear_extrude(height=h, convexity=10){
            gt2_2d(floor(abs(length)/2));
        };
        translate([abs(length),-2,-1]) cube([3, 4, h+2]);
    }
}

module gt2_pulley_2d(teeth=16, r=0, invert=false){
    //We must keep the distance between teeth at the "nominal" depth at 2mm, 
    //I leave the nominal depth at 0 in gt2_t, which makes this easy.
    //So we have to work out the radius.
    if(r>(teeth*2)/(2*PI)){
        //the teeth don't add up to a full circle, so we need to add a center point
        pts=concat(v2d_bend(r, v2d_scale([1,invert?-1:1],gt2_ts(teeth))),[[0,0]]);
        polygon(rm_dup(pts));
    }else{
        //constraining the radius to a full circle to actually make a pulley
        r=(teeth*2)/(2*PI);
        pts=v2d_bend(r, v2d_scale([1,invert?-1:1],gt2_ts(teeth)));// we are making a pulley, the "teeth" are actually "troughs"
        polygon(rm_dup(pts));
    }
}

//gt2_pulley_2d(teeth = 8, r=20);
module gt2_pulley(teeth=16, h=7, r=0, grow=-0.0, center=false, invert=false){
    translate([0,0,center?-h/2:0])linear_extrude(h)offset(grow)gt2_pulley_2d(teeth, r, invert);
}


// ============================================================================
//  SPIRAL GT2 BELT  (added by Saad Chinoy and Stephane Godin, 2026)
//  The library code between the Customizer parameters and this banner is
//  Alessandro Garosi's original gt2.scad (demo and straight-belt call removed).
//  Wraps the straight GT2 profile onto an Archimedean spiral.
//
//  How pitch stays true to GT2:
//  In gt2_t() the line y = 0 is the belt PITCH LINE (0.254 mm above the tooth
//  land, i.e. inside the tension-member layer, per the GT2 PLD spec).
//  Every x coordinate of the straight profile is mapped to an exact ARC LENGTH
//  along the spiral pitch line, and every y is laid off along the local
//  normal. So tooth centres sit exactly 2.000 mm apart measured along the
//  pitch line, and total_length is the true pitch length of the belt -
//  the same way a real belt keeps its pitch when it wraps a pulley.
//
//  Belt cross-section (from gt2_t): back at y=+0.376, land at y=-0.254,
//  tooth tip at y=-1.004 -> 1.38 mm total, 0.75 mm tooth height (GT2 nominal).
// ============================================================================

// GT2 profile constants (from gt2_t)
GT2_PITCH     = 2;
GT2_BACK      = 0.376; // pitch line -> belt back
GT2_LAND      = -0.254;// pitch line -> tooth land
GT2_TIP       = -1.004;// pitch line -> tooth tip
GT2_THICK     = GT2_BACK - GT2_TIP; // 1.38

// ---------------- Archimedean spiral maths ----------------
// Pitch line: r = a*phi,  a = turn_pitch / (2*PI),  polar angle t = phi - phi0
// Arc length from phi=0: S(phi) = a/2 * (phi*sqrt(1+phi^2) + asinh(phi))
function _asinh(x)       = ln(x + sqrt(x*x + 1));
function sp_S(a, phi)    = a/2 * (phi*sqrt(1+phi*phi) + _asinh(phi));

// Solve S(phi) - S(phi0) = s for phi with Newton's method
function sp_phi(a, phi0, s, phi, n=0) =
    let(f  = sp_S(a, phi) - sp_S(a, phi0) - s,
        nx = phi - f / (a*sqrt(1+phi*phi)))
    (n >= 12 || abs(f) < 1e-7) ? nx : sp_phi(a, phi0, s, nx, n+1);

// Map a straight-belt point [x (along pitch line), y (offset from pitch line)]
function sp_map(a, phi0, p) =
    let(phi = sp_phi(a, phi0, p[0], sqrt(phi0*phi0 + 2*p[0]/a)),
        t   = (phi - phi0) * 180 / PI,          // polar angle, degrees
        r   = a * phi,
        k   = 1 / sqrt(1 + phi*phi),
        // outward unit normal of the spiral
        n   = [ (sin(t) + phi*cos(t)) * k, (-cos(t) + phi*sin(t)) * k ])
    [ r*cos(t) + p[1]*n[0], r*sin(t) + p[1]*n[1] ];


// ---------------- fitting the spiral to an outer diameter ----------------
// Radial distance from the pitch line to the outermost edge of the belt
function gt2_outer_off(inward) = inward ? GT2_BACK : -GT2_TIP;
function gt2_inner_off(inward) = inward ? -GT2_TIP : GT2_BACK;

// Pitch-line length between radii r0 and R for turn pitch p
function sp_len(p, r0, R) = let(a = p/(2*PI)) sp_S(a, R/a) - sp_S(a, r0/a);

// Bisection on a monotonically decreasing function (dir=-1) or increasing (dir=+1)
function _bis_r0(p, R, L, lo, hi, n=0) =
    let(m = (lo+hi)/2)
    n >= 60 ? m : (sp_len(p, m, R) > L ? _bis_r0(p, R, L, m, hi, n+1)
                                        : _bis_r0(p, R, L, lo, m, n+1));
function _bis_p(r0, R, L, lo, hi, n=0) =
    let(m = (lo+hi)/2)
    n >= 60 ? m : (sp_len(m, r0, R) > L ? _bis_p(r0, R, L, m, hi, n+1)
                                         : _bis_p(r0, R, L, lo, m, n+1));

// Returns [r0 (start pitch radius), turn gap] for the chosen fit mode
function gt2_spiral_fit(L, od, mode, r0, gap, inward) =
    let(R = od/2 - gt2_outer_off(inward))   // pitch radius at the outer end
    mode == "manual" ? [r0, gap] :
    mode == "inner"  ? [_bis_r0(GT2_THICK+gap, R, L, 0, R), gap] :
    mode == "gap"    ? [r0, _bis_p(r0, R, L, GT2_THICK, 10*od) - GT2_THICK] :
    assert(false, "fit_mode must be \"inner\", \"gap\" or \"manual\"");

// ---------------- straight profile helpers ----------------
// Subdivide every edge of a closed polygon so no chord exceeds max_seg
function subdivide(v, m) = [
    for (i = [0:len(v)-1])
        let(p = v[i], q = v[(i+1) % len(v)],
            d = norm(q - p), k = max(1, ceil(d / m)))
        for (j = [0:k-1]) p + (q - p) * j / k
];

// Closed straight belt outline from x=0 to x=L, teeth pointing to -y
function gt2_strip(L, keep_tail) =
    let(tn    = floor(L / GT2_PITCH + 1e-9),
        Lend  = keep_tail ? L : tn * GT2_PITCH,
        teeth = v2d_tx([1, 0], gt2_ts(tn)))
    rm_dup(concat(
        [[0, GT2_LAND]],
        teeth,
        [[tn*GT2_PITCH, GT2_LAND]],
        (Lend > tn*GT2_PITCH) ? [[Lend, GT2_LAND]] : [],
        [[Lend, GT2_BACK], [0, GT2_BACK]]
    ));

// ---------------- modules ----------------
module gt2_spiral_2d(length=400, r0=12, gap=0.6, inward=true, keep_tail=false, seg=0.25){
    turn_pitch = GT2_THICK + gap;
    a    = turn_pitch / (2*PI);
    phi0 = r0 / a;
    // teeth face inward = teeth toward -normal (profile already has teeth at -y)
    pts  = v2d_scale([1, inward ? 1 : -1], subdivide(gt2_strip(length, keep_tail), seg));
    polygon([for (p = pts) sp_map(a, phi0, p)]);

    // sanity checks
    assert(gap > 0, "turn gap must be > 0 or turns will fuse");
    assert(r0 - gt2_inner_off(inward) > 1,
           "inner radius too small - increase outer_diameter, reduce total_length or turn_gap");
    tn = floor(length/GT2_PITCH + 1e-9);
    phi_end = sp_phi(a, phi0, length, sqrt(phi0*phi0 + 2*length/a));
    echo(str("GT2 spiral: ", tn, " teeth, pitch length ",
             keep_tail ? length : tn*GT2_PITCH, " mm, ",
             round((phi_end-phi0)/(2*PI)*100)/100, " turns, outer pitch radius ",
             round(a*phi_end*100)/100, " mm, turn pitch ", turn_pitch, " mm"));
    echo(str("GT2 spiral: inner radius (pitch) ", round(r0*100)/100, " mm, turn gap ",
             round(gap*1000)/1000, " mm, overall diameter ",
             round(2*(a*phi_end + gt2_outer_off(inward))*100)/100, " mm, hole diameter ",
             round(2*(r0 - gt2_inner_off(inward))*100)/100, " mm"));
}

module gt2_spiral_belt(length=400, h=6, r0=12, gap=0.6, inward=true, keep_tail=false, seg=0.25){
    linear_extrude(height=h, convexity=10)
        gt2_spiral_2d(length, r0, gap, inward, keep_tail, seg);
}

// ---------------- build ----------------
eff_length = keep_partial ? total_length
                          : floor(total_length/GT2_PITCH + 1e-9) * GT2_PITCH;
fit = gt2_spiral_fit(eff_length, outer_diameter, fit_mode,
                     inner_radius, turn_gap, teeth_inward);
assert(fit_mode == "manual" || fit[1] >= min_gap,
       str("outer_diameter too small for this length: gap would be ", fit[1],
           " mm (< min_gap ", min_gap, "). Increase outer_diameter or reduce total_length."));

color("darkslategray")
    gt2_spiral_belt(eff_length, belt_width, fit[0], fit[1],
                    teeth_inward, keep_partial, max_seg);
