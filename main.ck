@import "chodash.ck"

public class GlobalData // sending data between classes using this, kinda scuffed but i didn't know what events were
{
    static int leftid;
    0 => static int leftidflag; // flag means that a change has happened
    static int rightid;
    0 => static int rightidflag;

    static int keycolor;
    0 => static int keycolorflag;
    
    0 => static int minusflag;

    0 => static int onflag;
    0 => static int offflag;
}

// when left click, send the index to create/send balls
public class LeftClickCommand extends MouseCommand {
    fun void click(MouseTarget target) { (target $ ExtendedMouseTarget).id => GlobalData.leftid; 1 => GlobalData.leftidflag;}
}

// same for right click, here to turn on/off nodes manually
public class RightClickCommand extends MouseCommand {
    fun void click(MouseTarget target) { (target $ ExtendedMouseTarget).id => GlobalData.rightid; 1 => GlobalData.rightidflag;}
}

// this also holds the index of the target
public class ExtendedMouseTarget extends MouseTarget {
    int id;
    fun @construct(GGen ggen, vec2 size, int id)
    {
        ggen @=> this.ggen;
        size @=> this.size;
        id => this.id;
    }
}

// when pressing numbers 1-4 change color (and waveform)
public class ColorCommand extends KeyboardCommand
{
    int key;
    fun @construct(int i) {i => key;}
    fun void run() {key => GlobalData.keycolor; 1 => GlobalData.keycolorflag;}
}

// when pressing minus, remove most recent ball
public class RemoveCommand extends KeyboardCommand
{
    fun void run() {1 => GlobalData.minusflag;}
}

// when pressing ], turn all nodes on
public class AllOnCommand extends KeyboardCommand
{
    fun void run() {1 => GlobalData.onflag;}
}

// when pressing [, turn all nodes off
public class AllOffCommand extends KeyboardCommand
{
    fun void run() {1 => GlobalData.offflag;}
}

// this quantizes everything
10::ms => dur update;
200::ms => dur tick;

// fullscreen
GWindow.fullscreen();

// bloom it up
GG.bloom(true);
GG.bloomPass().intensity(0.5);
GG.bloomPass().radius(0.5);
GG.bloomPass().levels(9);

// external ring
GTorus ring;
ring.geometry() $ TorusGeometry @=> TorusGeometry ring_geo;
ring_geo.build(
1, // radius
0.001, // inner radius
1000,
1000,
2*Math.pi
);
ring --> GG.scene();

// gets position from index, just going in a circle
fun vec3 index_pos(int i)
{
   12 %=> i;
   return @(Math.cos(2 * Math.pi / 12 * i), Math.sin(2 * Math.pi / 12 * i), 0); 
}

// stores position, text, ggen, and hitbox for all 12 nodes
vec3 positions[12];
GText text[12];
GSphere points[12];
GGen hitboxes[12];

// lock to prevent overlapping animations
int lock[12];

// enable for on/off nodes
int enable[12];

// keeping track of most recent ball
-1 => int most_recent_ball;

// how long the trail behind each point should be
10 => int num_trail_points;

// change color/waveform between 4 different options
ColorCommand colorCommand1(1);
ColorCommand colorCommand2(2);
ColorCommand colorCommand3(3);
ColorCommand colorCommand4(4);
Keyboard.bind(colorCommand1, GWindow.KEY_1);
Keyboard.bind(colorCommand2, GWindow.KEY_2);
Keyboard.bind(colorCommand3, GWindow.KEY_3);
Keyboard.bind(colorCommand4, GWindow.KEY_4);

// remove most recent ball when pressing minus
RemoveCommand removeCommand();
Keyboard.bind(removeCommand, GWindow.KEY_MINUS);

// turn all on when pressing ]
AllOnCommand onCommand();
Keyboard.bind(onCommand, GWindow.KEY_RIGHTBRACKET);

// turn all off when pressing [
AllOffCommand offCommand();
Keyboard.bind(offCommand, GWindow.KEY_LEFTBRACKET);

// text for each node
["C", "G", "D", "A", "E", "B", "F#", "C#", "Ab", "Eb", "Bb", "F"] @=> string textword[];

// midi values corresponding to each note
[60, 55, 50, 57, 52, 59, 54, 49, 56, 51, 58, 53] @=> int sounds[];

// color options for four waveforms
[2 * Color.BLUE, 2 * Color.YELLOW, 2 * Color.DARKGREEN, 2 * Color.PINK] @=> vec3 colors[];

// initialize arrays
for (0 => int i; i < 12; i++)
{
    1 => enable[i];
    0 => lock[i];
    index_pos(i)=> vec3 pos;
    
    pos => points[i].pos;
    FlatMaterial f;
    f.color(Color.WHITE);
    points[i].mat(f);
    points[i].sca(0.025);
    points[i] --> GG.scene();


    pos => hitboxes[i].pos;
    hitboxes[i] --> GG.scene();

    ExtendedMouseTarget t(hitboxes[i], @(0.25, 0.25), i);
    LeftClickCommand leftClickCommand();
    Mouse.bind(leftClickCommand, Mouse.LEFT, t);
    RightClickCommand rightClickCommand();
    Mouse.bind(rightClickCommand, Mouse.RIGHT, t);


    text[i].text(textword[i]);
    pos * 1.1 => text[i].pos;
    text[i].size(0.1);

    text[i] --> GG.scene();

}



// geometry for each point
SphereGeometry point_geo;
point_geo.build(
.05,        // radius
 32,         // # segments along width of sphere (default 32)
 16,          // # segments along vertical arc of sphere (default 16)
 0,          // phiStart
 Math.PI * 2, // phiLength   (phi in spherical coordinates)
 0,          // thetaStart
 Math.PI     // thetaLength (theta in spherical coordinates)
);

// geometry for each trail point, arbitrary size
fun Geometry getTrailGeo(int size) // size ranges from 0 to num_trail_points
{
    SphereGeometry trail_geo;
    trail_geo.build(
     .01 + ((0.05 - 0.01) / num_trail_points) * size,        // radius
     32,         // # segments along width of sphere (default 32)
     16,          // # segments along vertical arc of sphere (default 16)
     0,          // phiStart
     Math.PI * 2, // phiLength   (phi in spherical coordinates)
     0,          // thetaStart
     Math.PI     // thetaLength (theta in spherical coordinates)
    );

    return trail_geo;
}

// animation to scale up and down the nodes when making sound to respond
fun TweenAnimation scaleAnimation(GMesh item, int col_index)
{
    TweenAnimation animation;
    animation.add(Tween.color(item, colors[col_index],0::second));
    animation.add(Tween.scale(item, 0.2, 0.1::second));
    animation.add(Tween.scale(item, 0.025, 0.1::second));
    animation.add(Tween.color(item, Color.WHITE, 0::second));

    return animation;

}

// animation to delete a ball when removed
fun TweenAnimation deleteAnimation(GMesh item)
{
    TweenAnimation animation;
    animation.add(Tween.scale(item, 0., 0::second, 0));
    return animation;

}

// count the absolute value of the difference modulo 12
fun int diff(int start, int target)
{
    (target - start) % 12 => int diffIndex;
    if (diffIndex < 0)
    {
        12 +=> diffIndex;
    }
    if (diffIndex > 6)
    {
        2 * (diffIndex - 6) -=> diffIndex;
    }

    return diffIndex;
}

// dot product of two vectors
fun float dot(vec3 vec1, vec3 vec2)
{
    return vec1.x * vec2.x + vec1.y * vec2.y + vec1.z * vec2.z;
}


// norm of a vector
fun float norm(vec3 vec)
{
    return Math.sqrt(dot(vec, vec));
}

// bounce a point and its trails between start_index and target_index
fun int[] bounce(GGen point, GGen trail_points[], int start_index, int target_index)
{
    diff(start_index, target_index) => int d;
    index_pos(start_index) => vec3 start_pos;
    index_pos(target_index) => vec3 target_pos;
    target_pos - start_pos => vec3 displacement;
    norm(displacement) => float dist;

    Math.round((d * tick) / update) $ int => int numSteps;

    for (0 => int i; i < numSteps; i++)
    {
        // trail updates to the position of the next one so it follows it
        for (0 => int j; j < num_trail_points - 1; j++)
        {
            trail_points[j].pos(trail_points[j+1].pos());
        }
        trail_points[num_trail_points - 1].pos(point.pos());
        point.pos(start_pos +  ((i $ float) / numSteps) * displacement);

        update => now;
    }
    return [target_index, (2 * target_index - start_index) % 12];
}

// bounce forever starting at start_index in the direction of target_index, with waveform osc_num
fun void bounce_forever(int start_index, int target_index, int osc_num)
{
    1 +=> most_recent_ball;
    most_recent_ball => int own_number;

    GMesh point(point_geo, FlatMaterial mat(colors[osc_num]));
    point.pos(index_pos(start_index));
    GMesh @ trail_points[num_trail_points];
    for (0 => int i; i < num_trail_points; i++)
    {
        GMesh trail_point(getTrailGeo(i), FlatMaterial mat(colors[osc_num])) @=> trail_points[i];
        trail_points[i].pos(index_pos(start_index));
        trail_points[i] --> GG.scene();
    }
    Osc @ oscs[4];
    SinOsc sin @=> oscs[0];
    TriOsc tri @=> oscs[1];
    SqrOsc sqr @=> oscs[2];
    SawOsc saw @=> oscs[3];
    oscs[osc_num] @=> Osc osc;
    0.1 => osc.gain;
 
    
    tick - (now % tick) => now; // snap to tick
    
    
    point --> GG.scene();
 
    if (start_index == target_index)
    {
        <<<"ERROR, START AND END ARE SAME">>>;
        return;
    }
    while (!(own_number == most_recent_ball && GlobalData.minusflag)) // while i haven't been removed, keep bouncin
    {
        if (enable[start_index])
        {
            spork ~ playSound(start_index, osc, osc_num);
        }
        bounce(point, trail_points, start_index, target_index) @=> int shit[];
        shit[0] => start_index;
        shit[1] => target_index;
    }
    
    1 -=> most_recent_ball;
    0 => GlobalData.minusflag;
  
    TweenAnimation @ final_anim;
    // catch everything up to the node and then delete
    for (-1 => int i; i < num_trail_points; i++)
    {
        if (i == -1)
        {
            spork ~ Tween.play(deleteAnimation(point));
        }
        else
        {
            deleteAnimation(trail_points[i])  @=> final_anim; // this is a stupid implementation sorry
            spork ~ Tween.play(final_anim);
        }
        for (0 => int j; j < num_trail_points - 1; j++)
        {
            trail_points[j].pos(trail_points[j+1].pos());
        }
        trail_points[num_trail_points - 1].pos(point.pos());
        update => now;
    }

    final_anim.done => now; // wait for anim to finish then ungruck
    point --< GG.scene();

    for (num_trail_points - 1 => int i; i >= 0;  i--)
    {
        trail_points[i] --< GG.scene();
    }
}

// play the sound of Osc, also do the node scaling to react to it
fun void playSound(int i, Osc osc, int col_index)
{
    TweenAnimation @ anim;
    if (!lock[i])
    {
        1 => lock[i];
        scaleAnimation(points[i], col_index) @=> anim; 
        Tween.play(anim);
        
        0 => lock[i];
    }
     
     
    osc => Envelope env =>  OnePole pole => dac;
    //SinOsc osc1 => Envelope env => dac;
    10::ms => env.duration;
    Std.mtof(sounds[i]) => osc.freq;
    env.keyOn();
    100::ms => now;
    env.keyOff();
    10::ms => now;

    osc =< env;

    anim.done => now;
    if (!enable[i])
    {
        (points[i].mat() $ FlatMaterial).color(Color.RED);
    }
}

// waits until user left clicks with start and target, and also inputs waveform with numbers
fun int[] pollLeftClickInputs()
{
    int ret[3];
    int start, target, osc;
    int key; 

    1 => key;
    do
    {
        while (GlobalData.leftidflag == 0){10::ms => now;}
        0 => GlobalData.leftidflag;
        GlobalData.leftid => start;

        index_pos(start) => temp_point.pos;
        temp_point --> GG.scene();

        while (GlobalData.leftidflag == 0)
        {
            if (GlobalData.keycolorflag != 0)
            {
                GlobalData.keycolor => key;
                0 => GlobalData.keycolorflag;
                (temp_point.mat() $ FlatMaterial).color(colors[key - 1]);
            }
            10::ms => now;
        }
        0 => GlobalData.leftidflag;
        key - 1=> osc;
        GlobalData.leftid => target;
        temp_point --< GG.scene();
        (temp_point.mat() $ FlatMaterial).color(colors[0]);
    } while (target==start); // if they click the same one then cancel it
    start => ret[0];
    target => ret[1];
    osc => ret[2];

    return ret;
}

// wait until user right clicks a node, then return which index
fun int pollRightClickInputs()
{
    while (GlobalData.rightidflag == 0){10::ms => now;}
    0 => GlobalData.rightidflag;
    return GlobalData.rightid;
}

// once they right click, toggle on/off the correct node
fun void rightClickDisableNodes()
{
    while (true)
    {
        pollRightClickInputs() => int node;

        if (enable[node])
        {
            0 => enable[node];
            (points[node].mat() $ FlatMaterial).color(Color.RED);
        }
        else
        {
            1 => enable[node];
            (points[node].mat() $ FlatMaterial).color(Color.WHITE);
        }
    }
}

// when user presses [ or ], turn off or turn on all nodes respectively
fun void allOnOffDisableNodes()
{
    while (true)
    {
        if (GlobalData.onflag)
        {
            0 => GlobalData.onflag;
            for (0 => int i; i < 12; i++)
            {
                1 => enable[i];
                (points[i].mat() $ FlatMaterial).color(Color.WHITE);
            }
        }
        if (GlobalData.offflag)
        {
            0 => GlobalData.offflag;
            for (0 => int i; i < 12; i++)
            {
                0 => enable[i];
                (points[i].mat() $ FlatMaterial).color(Color.RED);
            } 
        }
        10::ms => now;
    }
}

// start up by sporking all the input polling, then bounce some balls
fun void startSequence()
{
    spork ~ rightClickDisableNodes();
    spork ~ allOnOffDisableNodes();
    while(true)
    {
        pollLeftClickInputs() @=> int data[];
        spork ~ bounce_forever(data[0], data[1], data[2]);
    }
}

// material for temporary point while clicking, default to blue
FlatMaterial mat();
mat.color(@(colors[0].x, colors[0].y, colors[0].z, 0.5)); 
GMesh temp_point(point_geo, mat);


spork ~ startSequence(); // run the sequence

while (true)
{
    GG.nextFrame() => now; // update frame
    Mouse.update(); // chodash stuff
    Tween.update();
    Keyboard.update();
}
