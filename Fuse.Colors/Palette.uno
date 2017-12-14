using Fuse.Controls;
using Uno.Collections;
using Uno;
using Uno.UX;
using Fuse.Scripting;
namespace Fuse.Colors{

    class ColorSpace{
        public static float3 RGB2HSV(float r, float g, float b) {
            var max = Math.Max(Math.Max(r, g), b);
            var min = Math.Min(Math.Min(r, g), b);
            var h = max;
            var s = max;
            var v = max;

            var d = max - min;
            s = max == 0f ? 0f : d / max;

            if (max == min) {
                h = 0f;
            } else {
                if(max==r){
                    h = (g - b) / d + (g < b ? 6 : 0); 
                }else if(max==g){
                    h = (b - r) / d + 2; 
                }else if(max==b){
                    h = (r - g) / d + 4; 
                }
                h /= 6;
            }

            return float3(h, s, v);
        }

        public static float3 HSV2RGB(float h, float s, float v) {
            //h = (h + 0.5f) * 2.0f / 2.0f;
            float r = 0f;
            float g = 0f;
            float b = 0f;
            float i = 0f;
            float f = 0f;
            float p = 0f;
            float q = 0f;
            float t = 0f;
            i = Math.Floor(h * 6);
            f = h * 6 - i;
            p = v * (1 - s);
            q = v * (1 - f * s);
            t = v * (1 - (1 - f) * s);
            var mod = Math.Mod(i,6);
            if(mod==0){
                r = v; g = t; b = p;
            }else if(mod==1){
                r = q; g = v; b = p; 
            }else if(mod==2){
                r = p; g = v; b = t; 
            }else if(mod==3){
                r = p; g = q; b = v; 
            }else if(mod==4){
                r = t; g = p; b = v; 
            }else if(mod==5){
                r = v; g = p; b = q;
            }
            return float3(r,g,b);
        }
    }
    class ColorWheel{
        
        public static float3 Sample(float2 vec, float sat, float val, float3 hsvOffset){
            float dist = Math.Sqrt(vec.X * vec.X + vec.Y * vec.Y);
            float saturation = hsvOffset.Y * dist;
            float angle = Math.Atan2(vec.Y, vec.X) / 6.28f;
            float v = hsvOffset.Z;
            if(dist>1f)
                saturation = val = 0f;
            return ColorSpace.HSV2RGB(angle+hsvOffset.X, saturation*sat, v*val);
        }
    }

    public enum ColorGenMode{
        Triad = 0,
        Complementary = 1,
        Shades = 2
    }

    struct SampleVec{
        public float2 vec;
        public float amp, v;
        public SampleVec(float2 inDirection, float inAmplitude, float inVal){
            vec = inDirection;
            amp = inAmplitude;
            v = inVal;
        }
    }

    public class Palette : Panel{

        
		static Palette()
		{
			ScriptClass.Register(typeof(Palette),
				new ScriptMethod<Palette>("getColors", (Func<Context, Palette, object[], object>)getColors, ExecutionThread.JavaScript),
				new ScriptMethod<Palette>("getSettings", (Func<Context, Palette, object[], object>)getSettings, ExecutionThread.JavaScript)
                );
		}
		
		static object getColors(Context c, Palette s, object[] args)
		{
            var a = c.NewArray();
            for(int i = 0; i<s.Colors.Length; i++){
                var ca = c.NewArray();
                ca[0] = s.Colors[i].X;
                ca[1] = s.Colors[i].Y;
                ca[2] = s.Colors[i].Z;
                ca[3] = s.Colors[i].W;
                a[i] = ca;
            }
            return a;
		}

        override protected void OnRooted(){
            Rebuild();
            base.OnRooted();
        }

        static object getSettings(Context c, Palette s, object[] args)
        {
            var ob = c.NewObject();
            ob["Hue"] = s.Hue;
            ob["Saturation"] = s.Saturation;
            ob["Value"] = s.Value;
            ob["Gain"] = s.Gain+"";
            ob["Mode"] = s.Mode+"";
            ob["Scale"] = s.Scale+"";
            return ob;
        }

        // Sample modes
        static SampleVec[] Complementary(SampleVec basis)
        {
            var output = new SampleVec[5];
            output[0] = new SampleVec(basis.vec, basis.amp, basis.v * 0.7f);
            output[1] = new SampleVec(basis.vec, basis.amp*0.8f, basis.v);

            var reflected = new SampleVec(Rotate(basis.vec, DegRad(180)), basis.amp*0.8f, basis.v);
            output[2] = reflected;
            output[3] = new SampleVec(reflected.vec, reflected.amp*0.7f, reflected.v * 0.7f);
            output[4] = new SampleVec(reflected.vec, reflected.amp*0.4f, reflected.v);

            return output;
        }

        static SampleVec[] Shades(SampleVec basis){
            var output = new SampleVec[5];
            output[0] = basis;
            output[1] = new SampleVec(basis.vec, basis.amp, basis.v * 0.9f);
            output[2] = new SampleVec(basis.vec, basis.amp, basis.v * 0.7f);
            output[3] = new SampleVec(basis.vec, basis.amp, basis.v * 0.5f);
            output[4] = new SampleVec(basis.vec, basis.amp, basis.v * 0.4f);
            return output;
        }

        static SampleVec[] Triad(SampleVec basis){
            var output = new SampleVec[5];

            output[0] = basis;

            float offsetAngle = DegRad(360.0f/3.0f-5.0f);
            var offsetA = new SampleVec(Rotate(basis.vec, offsetAngle), basis.amp*0.8f, 1.0f);
            output[1] = offsetA;
            output[2] = new SampleVec(offsetA.vec, offsetA.amp*0.8f, 0.7f);

            var offsetB = new SampleVec(Rotate(basis.vec, -offsetAngle), basis.amp*0.8f, 1.0f);
            output[3] = offsetB;
            output[4] = new SampleVec(offsetB.vec, offsetB.amp*0.7f, 0.7f);
            return output;
        }

        //
        
        static float DegRad(float deg){
            return deg * 3.14f/180f;
        }

        static float2 AngleToVec(float angle){
            var x = 1f;
            var y = 0f;
            return Normalize(Rotate(float2(x,y), angle));
        }

        static float LengthOf(float2 vec){
            return Math.Sqrt(vec.X*vec.X+vec.Y*vec.Y);
        }

        static float2 Normalize(float2 vec){
            var len = LengthOf(vec);
            return float2(vec.X/len, y:vec.Y/len);
        }

        static float Shape(float v, float d){
			var k = 2f * d / (1f - d);
			return (1f + k) * v / (1f + k * Math.Abs(v));
		}

        static float2 Rotate(float2 vec, float angle){
            float cs = Math.Cos(angle);
            float sn = Math.Sin(angle);
            float px = vec.X * cs - vec.Y * sn; 
            float py = vec.X * sn + vec.Y * cs;
            return float2(px, py);
        }
        
        void Rebuild(){
            _palette = new float4[5];
            SampleVec[] samples;
            var basis = new SampleVec(AngleToVec((float)Hue * 6.28f), 1f, 1f);
            switch(Mode){
                case ColorGenMode.Complementary:
                    samples = Complementary(basis);
                    break;
                case ColorGenMode.Triad:
                    samples = Triad(basis);
                    break;
                default:
                    samples = Shades(basis);
                    break;
            }
            for(int i = 0; i<5;i++){
                var s = samples[i];
                float3 clr = ColorWheel.Sample(
                    s.vec * s.amp, 
                    (float)_saturation, 
                    s.v * (float)_value,
                    _baseColorHSV);

                clr += Gain;
                clr *= Scale;

                _palette[i] = float4(clr, 1.0f);
            }
            OnPaletteChanged();
        }

        ColorGenMode _mode;
        public ColorGenMode Mode{
            get {
                return _mode;
            }
            set{
                _mode = value;
                Rebuild();
            }
        }

        float3 _baseColor;
        float3 _baseColorHSV = float3(0.0f, 1.0f, 1.0f);
        public float3 BaseColor{
            get { return _baseColor; }
            set { 
                _baseColor = value; 
                _baseColorHSV = ColorSpace.RGB2HSV(_baseColor.X, _baseColor.Y, _baseColor.Z);
                Rebuild();
            }
        }

        double _hue;
        public double Hue{
            get {
                return _hue;
            }
            set{
                _hue = value;
                Rebuild();
            }
        }

        double _saturation = 1.0;
        public double Saturation{
            get {
                return _saturation;
            }
            set{
                _saturation = value;
                Rebuild();
            }
        }

        float3 _gain;
        public float3 Gain{
            get{ return _gain; }
            set{ _gain = value; Rebuild(); }
        }

        public float GainR{
            get{ return _gain.X; }
            set{ _gain.X = value; Rebuild(); }
        }

        public float GainG{
            get{ return _gain.Y; }
            set{ _gain.Y = value; Rebuild(); }
        }

        public float GainB{
            get{ return _gain.Z; }
            set{ _gain.Z = value; Rebuild(); }
        }

        float3 _scale = float3(1.0f);
        public float3 Scale{
            get{ return _scale; }
            set{ _scale = value; Rebuild(); }
        }

        public float ScaleR{
            get{ return _scale.X; }
            set{ _scale.X = value; Rebuild(); }
        }

        public float ScaleG{
            get{ return _scale.Y; }
            set{ _scale.Y = value; Rebuild(); }
        }
        
        public float ScaleB{
            get{ return _scale.Z; }
            set{ _scale.Z = value; Rebuild(); }
        }

        double _value = 1.0;
        public double Value{
            get {
                return _value;
            }
            set{
                _value = value;
                Rebuild();
            }
        }

        void OnPaletteChanged() {
            OnPropertyChanged(_paletteName, this);
            OnPropertyChanged(_c1Name, this);
            OnPropertyChanged(_c2Name, this);
            OnPropertyChanged(_c3Name, this);
            OnPropertyChanged(_c4Name, this);
            OnPropertyChanged(_c5Name, this);
        }

        float4[] _palette;
        static Selector _paletteName = "Palette";
        public float4[] Colors{
            get {
                return _palette;
            }
        }

        static Selector _c1Name = "C1";
        public float4 C1{
            get {
                return _palette[0];
            }
            set {

            }
        }

        static Selector _c2Name = "C2";
        public float4 C2{
            get {
                return _palette[1];
            }
            set {
                
            }
        }

        static Selector _c3Name = "C3";
        public float4 C3{
            get {
                return _palette[2];
            }
            set {
                
            }
        }

        static Selector _c4Name = "C4";
        public float4 C4{
            get {
                return _palette[3];
            }
            set {
                
            }
        }

        static Selector _c5Name = "C5";
        public float4 C5{
            get {
                return _palette[4];
            }
            set {
                
            }
        }
    }
    
}