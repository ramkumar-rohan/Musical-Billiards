@import "chodash.ck"

public class GlobalData // wtf is this bro
{
    static int leftid;
    0 => static int leftidflag;
    static int rightid;
    0 => static int rightidflag;

    static int key;
    0 => static int keyflag;
}
public class LeftClickCommand extends MouseCommand {
    fun void click(MouseTarget target) { (target $ ExtendedMouseTarget).id => GlobalData.leftid; 1 => GlobalData.leftidflag;}
}
public class RightClickCommand extends MouseCommand {
    fun void click(MouseTarget target) { (target $ ExtendedMouseTarget).id => GlobalData.rightid; 1 => GlobalData.rightidflag;}
}

public class ExtendedMouseTarget extends MouseTarget {
    int id;
    fun @construct(GGen ggen, vec2 size, int id)
    {
        ggen @=> this.ggen;
        size @=> this.size;
        id => this.id;
    }
}

public class ColorCommand extends KeyboardCommand
{
    int key;
    fun @construct(int i) {i => key;}
    fun void run() {key => GlobalData.key; 1 => GlobalData.keyflag;}
}


10::ms => dur update;
200::ms => dur tick;

// GWindow.fullscreen();

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

fun vec3 index_pos(int i)
{
   12 %=> i;
   return @(Math.cos(2 * Math.pi / 12 * i), Math.sin(2 * Math.pi / 12 * i), 0); 
}

vec3 positions[12];
GText text[12];
GSphere points[12];
GGen hitboxes[12];

int lock[12];
int enable[12];

ColorCommand colorCommand1(1);
ColorCommand colorCommand2(2);
ColorCommand colorCommand3(3);
ColorCommand colorCommand4(4);
Keyboard.bind(colorCommand1, GWindow.KEY_1);
Keyboard.bind(colorCommand2, GWindow.KEY_2);
Keyboard.bind(colorCommand3, GWindow.KEY_3);
Keyboard.bind(colorCommand4, GWindow.KEY_4);

["C", "G", "D", "A", "E", "B", "F#", "C#", "Ab", "Eb", "Bb", "F"] @=> string textword[];

[60, 55, 50, 57, 52, 59, 54, 49, 56, 51, 58, 53] @=> int sounds[];

[Color.BLUE, Color.YELLOW, Color.DARKGREEN, Color.PINK] @=> vec3 colors[];


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


fun TweenAnimation scaleAnimation(GMesh item, int col_index)
{
    TweenAnimation animation;
    animation.add(Tween.color(item, colors[col_index],0::second));
    animation.add(Tween.scale(item, 0.2, 0.1::second));
    animation.add(Tween.scale(item, 0.025, 0.1::second));
    animation.add(Tween.color(item, Color.WHITE, 0::second));


    return animation;

}


fun int numSteps(int start, int target)
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

fun int[] bounce(GGen point, int start_index, int target_index)
{
    numSteps(start_index, target_index) => int d;
    index_pos(start_index) => vec3 start_pos;
    index_pos(target_index) => vec3 target_pos;
    target_pos - start_pos => vec3 displacement;
    norm(displacement) => float dist;

    Math.round((d * tick) / update) $ int => int numSteps;

    for (0 => int i; i < numSteps; i++)
    {
        point.pos(start_pos +  ((i $ float) / numSteps) * displacement);
        update => now;
    }
    return [target_index, (2 * target_index - start_index) % 12];
}

fun void bounce_forever(int start_index, int target_index, int osc_num)
{
    GMesh point(point_geo, FlatMaterial mat(colors[osc_num]));
    Osc @ oscs[4];
    SinOsc sin @=> oscs[0];
    TriOsc tri @=> oscs[1];
    SqrOsc sqr @=> oscs[2];
    SawOsc saw @=> oscs[3];
    oscs[osc_num] @=> Osc osc;
    0.1 => osc.gain;
 
    
    tick - (now % tick) => now;
    
    
    point --> GG.scene();
 
    if (start_index == target_index)
    {
        <<<"ERROR, START AND END ARE SAME">>>;
        return;
    }
    while (true)
    {
        if (enable[start_index])
        {
            spork ~ playSound(start_index, osc, osc_num);
        }
        bounce(point, start_index, target_index) @=> int shit[];
        shit[0] => start_index;
        shit[1] => target_index;
    }
}

fun void playSound(int i, Osc osc, int col_index)
{
    if (!lock[i])
    {
        1 => lock[i];
        Tween.play(scaleAnimation(points[i], col_index));
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

}

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
            if (GlobalData.keyflag != 0)
            {
                GlobalData.key => key;
                0 => GlobalData.keyflag;
                (temp_point.mat() $ FlatMaterial).color(colors[key - 1]);
            }
            10::ms => now;
        }
        0 => GlobalData.leftidflag;
        key - 1=> osc;
        GlobalData.leftid => target;
        temp_point --< GG.scene();
        (temp_point.mat() $ FlatMaterial).color(colors[0]);
    } while (target==start);
    start => ret[0];
    target => ret[1];
    osc => ret[2];

    return ret;
}

fun int pollRightClickInputs()
{
    while (GlobalData.rightidflag == 0){10::ms => now;}
    0 => GlobalData.rightidflag;
    return GlobalData.rightid;
}

fun void disableNodes()
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

fun void startSequence()
{
    spork ~ disableNodes();
    while(true)
    {
        pollLeftClickInputs() @=> int data[];
        spork ~ bounce_forever(data[0], data[1], data[2]);
    }
}

FlatMaterial mat();
mat.color(@(colors[0].x, colors[0].y, colors[0].z, 0.5)); 
GMesh temp_point(point_geo, mat);


spork ~ startSequence();

while (true)
{
    GG.nextFrame() => now;
    Mouse.update();
    Tween.update();
    Keyboard.update();
}
