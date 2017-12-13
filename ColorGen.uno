using Fuse;
using Fuse.Controls;
using Uno.Collections;
using Uno;
using Uno.UX;

class ColorWheel{
	
	static float3 HSVtoRGB(float h, float s, float v) {
		h = (h + 0.5f) * 2.0f / 2.0f;
		float r = 0.0f;
		float g = 0.0f;
		float b = 0.0f;
		float i = 0.0f;
		float f = 0.0f;
		float p = 0.0f;
		float q = 0.0f;
		float t = 0.0f;
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


	public static float3 Sample(float x, float y, float sat = 1.0f, float val = 1.0f){
		float dist = Math.Sqrt(x * x + y * y);
		float saturation = dist;
		float angle = Math.Atan2(y, x) / 6.28f;
		float v = 1.0f;
		if(dist>1.0f)
			saturation = val = 0.0f;
		return HSVtoRGB(angle, saturation*sat, v*val);
	}
}

enum ColorGenMode{
    Triad,
    Complementary,
    Shades
}

public struct Sample{
    public float2 vec;
    public float amp, v;
    public Sample(float2 inDirection, float inAmplitude, float inVal){
        vec = inDirection;
        amp = inAmplitude;
        v = inVal;
    }
}

class ColorGen : Panel{
    // Sample modes
    Sample[] Complementary(Sample basis)
    {
        var output = new Sample[5];
        output[0] = new Sample(basis.vec, basis.amp, basis.v * 0.7f);
        output[1] = new Sample(basis.vec, basis.amp*0.8f, basis.v);

        var reflected = new Sample(rotate(basis.vec, degRad(180)), basis.amp*0.8f, basis.v);
        output[2] = reflected;
        output[3] = new Sample(reflected.vec, reflected.amp*0.7f, reflected.v * 0.7f);
        output[4] = new Sample(reflected.vec, reflected.amp*0.4f, reflected.v);

        return output;
    }

    Sample[] Shades(Sample basis){
        var output = new Sample[5];
        output[0] = basis;
        output[1] = new Sample(basis.vec, basis.amp, basis.v * 0.9f);
        output[2] = new Sample(basis.vec, basis.amp, basis.v * 0.7f);
        output[3] = new Sample(basis.vec, basis.amp, basis.v * 0.5f);
        output[4] = new Sample(basis.vec, basis.amp, basis.v * 0.4f);
        return output;
    }

    Sample[] Triad(Sample basis){
        var output = new Sample[5];

        output[0] = basis;

        float offsetAngle = degRad(360.0f/3.0f-5.0f);
        var offsetA = new Sample(rotate(basis.vec, offsetAngle), basis.amp*0.8f, 1.0f);
        output[1] = offsetA;
        output[2] = new Sample(offsetA.vec, offsetA.amp*0.8f, 0.7f);

        var offsetB = new Sample(rotate(basis.vec, -offsetAngle), basis.amp*0.8f, 1.0f);
        output[3] = offsetB;
        output[4] = new Sample(offsetB.vec, offsetB.amp*0.7f, 0.7f);
        return output;
    }

    //
	
    float degRad(float deg){
		return deg * 3.14f/180f;
	}

	float2 angleToVec(float angle){
		var x = 1.0f;
		var y = 0.0f;
		return normalize(rotate(float2(x,y), angle));
	}

    float length(float2 vec){
		return Math.Sqrt(vec.X*vec.X+vec.Y*vec.Y);
	}

	float2 normalize(float2 vec){
		var len = length(vec);
		return float2(vec.X/len, y:vec.Y/len);
	}

	float2 rotate(float2 vec, float angle){
		float cs = Math.Cos(angle);
		float sn = Math.Sin(angle);
		float px = vec.X * cs - vec.Y * sn; 
		float py = vec.X * sn + vec.Y * cs;
		return float2(px, py);
	}

    override protected void OnRooted(){
        init();
        base.OnRooted(); 
    }

    void init(){
        Mode = ColorGenMode.Complementary;
    }
    
    void rebuild(){
        _palette = new float4[5];
        Sample[] samples;
        Sample basis = new Sample(angleToVec((float)Hue), 1.0f, 1.0f);
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
            float3 clr = ColorWheel.Sample(s.vec.X*s.amp, s.vec.Y*s.amp, (float)_saturation, s.v * (float)_value);
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
            rebuild();
        }
    }

    double _hue;
    public double Hue{
        get {
            return _hue;
        }
        set{
            _hue = value;
            rebuild();
        }
    }

    double _saturation = 0.0;
    public double Saturation{
        get {
            return _saturation;
        }
        set{
            _saturation = value;
            rebuild();
        }
    }

    double _value = 0.0;
    public double Value{
        get {
            return _value;
        }
        set{
            _value = value;
            rebuild();
        }
    }

    void OnPaletteChanged(){
		OnPropertyChanged(_paletteName, this);
		OnPropertyChanged(_c1Name, this);
		OnPropertyChanged(_c2Name, this);
		OnPropertyChanged(_c3Name, this);
		OnPropertyChanged(_c4Name, this);
		OnPropertyChanged(_c5Name, this);
    }

    float4[] _palette;
	static Selector _paletteName = "Palette";
    public float4[] Palette{
        get {
            return _palette;
        }
    }

	static Selector _c1Name = "C1";
    public float4 C1{
        get {
            return _palette[0];
        }
    }

	static Selector _c2Name = "C2";
    public float4 C2{
        get {
            return _palette[1];
        }
    }

	static Selector _c3Name = "C3";
    public float4 C3{
        get {
            return _palette[2];
        }
    }

	static Selector _c4Name = "C4";
    public float4 C4{
        get {
            return _palette[3];
        }
    }

	static Selector _c5Name = "C5";
    public float4 C5{
        get {
            return _palette[4];
        }
    }
}