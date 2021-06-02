Shader "PeerPlay/Raymarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0	

			#include "UnityCG.cginc"
			/********DADES ENVIADES DE CPU********/
			sampler2D _MainTex;
			uniform float4x4 _CamFrustum, _CamToWorld; //Cam Frustrum: 4 direccions (les 4 esquines de la pantalla)
			uniform float _maxDistance; //Dist�ncia m�xima a partir de la qual deixem de calcular el rayMarching
			uniform float3 _LightDir;
			//COSES MENUS:
			uniform float _fractalPower;
			uniform float _fractalScapeRatio;
			uniform int _fractalIterations;
			uniform float _fractalScale;
			uniform float _foldingLimit;
			uniform float _minRadius;
			uniform float _fixedRadius;
			uniform float _fractalOffset;
			uniform float _linearDEOffset;
			uniform int _currentScene;
			uniform int _numIterations;
			uniform int _enableLight;
			uniform int _enableShadows;
			uniform int _blinnPhong;
			uniform float _shadowFactor;
			uniform float _raymarchEpsilon;
			uniform float _shadowEpsilon;
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
			};
			/*********************************/
			/*********************VERTEX SHADER*********************/
			v2f vert(appdata v)
			{
				v2f o;
				half index = v.vertex.z;
				v.vertex.z = 0;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				o.ray = _CamFrustum[(int)index].xyz;

				o.ray /= abs(o.ray.z);

				o.ray = mul(_CamToWorld, o.ray);

				return o;
			}
			/***************************************************************************************************************************/
			/****************************************************FUNCIONS RAYMARCHING**************************************************/

			/// UTILS
			// Funcions mod de glsl (el fmod de hlsl != mod de glsl)
			float mod(float p, float factor) {
				return p - factor * floor(p / factor);
			}

			float2 mod2(float2 p, float2 factor) {
				return float2(mod(p.x, factor.x), mod(p.y, factor.y));
			}

			float3 mod3(float3 p, float3 factor) {
				return float3(mod(p.x, factor.x), mod(p.y, factor.y), mod(p.z, factor.z));
			}

			///
			//FUNCIONS PER "DOBLEGAR" EL PLA (idea de https://www.shadertoy.com/view/MsBGW1) 
			float3 repeatXZ(float3 p, float2 factor)
			{
				float2 tmp = mod2(p.xz, factor) -0.5*factor;
				return float3(tmp.x, p.y, tmp.y);
			}

			float3 repeatXYZ(float3 p, float3 factor) {
				float3 tmp = mod3(p, factor) - 0.5*factor;
				return float3(tmp.x, tmp.y, tmp.z);
			}

			//// TRANSFORMACIONS GEOM�TRIQUES (http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#constructive-solid-geometry)
			float intersectSDF(float distA, float distB) {
				return max(distA, distB);
			}

			float unionSDF(float distA, float distB) {
				return min(distA, distB);
			}

			float differenceSDF(float distA, float distB) {
				return max(distA, -distB);
			}

			float fold(float p, float n) { // Dopleguem pel pla amb normal n. http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
				//float t = dot(z,n1); if (t<0.0) { z-=2.0*t*n1; }// versi� inicial
				p -= 2.0 * min(0.0, dot(p, n)) * n; //versi� optimitzada
			}
			/////

			//SIGNED PRIMITIVES. Trobar m�s a https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
			//SPHERE
			float sdSphere(float3 p, float3 pos,float radius) // p: current point, pos: sphere pos
			{
				return length(p - pos) - radius;
			}
			//BOX
			float sdBox(float3 p, float3 pos, float3 b) // b:dimensions
			{
				p = p - pos;
				float3 q = abs(p) - b;
				return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
			}

			float sdCross(float3 p, float3 pos, float b)
			{
				float da = sdBox(p.xyz, pos, float3(b, b/2, b/2));
				float db = sdBox(p.yzx, pos, float3(b/2, b, b/2));
				float dc = sdBox(p.zxy, pos, float3(b/2, b/2, b));
				return min(da, min(db, dc));
			}

			//BOX FRAME
			float sdBoxFrame(float3 p, float3 pos, float3 b, float e) //p: current point. pos: box position b: dimensions. e : amplada costats
			{
				p = p - pos;
				p = abs(p) - b;
				float3 q = abs(p + e) - e;
				return min(min(
					length(max(float3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
					length(max(float3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
					length(max(float3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
			}

			//DISTANCE ESTIMATORS
			float tetrahedronFractalDE_firstApproach(float3 p) //http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
			{
				float Scale = _fractalScale;
				float3 a1 = float3(1, 1, 1);
				float3 a2 = float3(-1, -1, 1);
				float3 a3 = float3(1, -1, -1);
				float3 a4 = float3(-1, 1, -1);
				float3 c;
				int n = 0;
				float dist, d;
				while (n < _fractalIterations) {
					c = a1; dist = length(p - a1);
					d = length(p - a2); if (d < dist) { c = a2; dist = d; }
					d = length(p - a3); if (d < dist) { c = a3; dist = d; }
					d = length(p - a4); if (d < dist) { c = a4; dist = d; }
					p = Scale * p - c * (Scale - 1.0);
					n++;
				}

				return length(p) * pow(Scale, float(-n));
			}

			float tetrahedronFractalDE_mod1(float3 p) //Modificat per poder despr�s doblegar el pla (intento)
			{
				float Scale = _fractalScale;
				float3 a1 = float3(2, 2, 2);
				float3 a2 = float3(0, 0, 2);
				float3 a3 = float3(2, 0, 0);
				float3 a4 = float3(0, 2, 0);
				float3 c;
				int n = 0;
				float dist, d;
				while (n < _fractalIterations) {
					c = a1; dist = length(p - a1);
					d = length(p - a2); if (d < dist) { c = a2; dist = d; }
					d = length(p - a3); if (d < dist) { c = a3; dist = d; }
					d = length(p - a4); if (d < dist) { c = a4; dist = d; }
					p = Scale * p - c * (Scale - 1.0);
					n++;
				}

				return length(p) * pow(Scale, float(-n));
			}


			float4 tetrahedronFractalDE(float3 p)  //http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
			{
				float r;
				int n = 0;
				float Scale = _fractalScale;
				float Offset = _fractalOffset;
				float orbit = dot(p,p);
				float3 color = p;

				while (n < _fractalIterations) {
					if (p.x + p.y < 0) p.xy = -p.yx; // fold 1
					if (p.x + p.z < 0) p.xz = -p.zx; // fold 2
					if (p.y + p.z < 0) p.zy = -p.yz; // fold 3	
					p = p * Scale - Offset * (Scale - 1.0);
					//orbit = min(orbit, dot(p,p));
					if (dot(p,p) < orbit) {
						orbit = dot(p,p);
						color = p;
					}
					n++;
				}
				color = normalize(color);

				//return float4((length(p)) * pow(Scale, -float(n)), orbit , -1, -1);
				return float4((length(p)) * pow(Scale, -float(n)), 0.5 + color.x*0.5 , 0.5 + color.y*0.5, 0.5 + color.z*0.5);
			}


			float4 mandelbulbDE(float3 pos) { //http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
				int Iterations = _fractalIterations;
				float Bailout = _fractalScapeRatio; //radi escapament
				float Power = _fractalPower; // z_{n+1} = (z_n)^Power + pos

				float3 z = pos;
				float dr = 1.0;
				float r = 0.0;
				float iter = 0.0;
				for (int i = 0; i < Iterations; i++) {
					iter += 1.0;
					r = length(z);
					if (r > Bailout) break;

					// convert to polar coordinates
					float theta = acos(z.z / r);
					float phi = atan2(z.y, z.x);
					dr = pow(r, Power - 1.0)*Power*dr + 1.0;

					// scale and rotate the point
					float zr = pow(r, Power);
					theta = theta * Power;
					phi = phi * Power;

					// convert back to cartesian coordinates
					z = zr * float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
					z += pos;
					
				}
				return float4(0.5*log(r)*r / dr, iter, -1, -1);
			}

			float4 mengerSpongeDE(float3 p) { // Versió optimitzada de https://www.iquilezles.org/www/articles/menger/menger.htm a partir del concepte original de resta de creus a capses
				int Iterations = _fractalIterations;
				float Scale = _fractalScale;

				float d = sdBox(p, float3(0.0,0.0,0.0), float3(1.0, 1.0, 1.0) * Scale);

				float s = 1; //Error en l'algoritme de la pàgina: cal dividr inicialment per l'escala, si no després no obtindrem una primera creu gran
				float color = -1;
				for (int m = 0; m<_fractalIterations; m++)
				{
					float3 a = mod3(p*s, float3(2.0, 2.0, 2.0)) - 1.0;
					s *= 3.0;
					float3 r = abs(1.0 - 3.0*abs(a));

					float da = max(r.x, r.y);
					float db = max(r.y, r.z);
					float dc = max(r.z, r.x);
					float c = (min(da, min(db, dc)) - 1.0) / s;
					
					if (c>d)
					{
						d = c;
						//Color: iteracions / maxiteracions. Es calcularà el color en getColor
						color = (1.0 + float(m)) / float(Iterations + 1);

					}

				}

				return float4(d, color, -1, -1);
			}

			float4 mengerSpongeCommonDE(float3 p) { // Versió comuna amb un forat més gran al centre
				int Iterations = _fractalIterations;
				float Scale = _fractalScale;

				float d = sdBox(p, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0) * Scale);

				float s = 1 / Scale; 
				float color = -1;
				for (int m = 0; m<_fractalIterations; m++)
				{
					float3 a = mod3(p*s, float3(2.0, 2.0, 2.0)) - 1.0;
					s *= 3.0;
					float3 r = abs(1.0 - 3.0*abs(a));

					float da = max(r.x, r.y);
					float db = max(r.y, r.z);
					float dc = max(r.z, r.x);
					float c = (min(da, min(db, dc)) - 1.0) / s;

					if (c>d)
					{
						d = c;
						color = (1.0 + float(m)) / float(Iterations + 1);

					}

				}

				return float4(d, color, -1, -1);
			}

			float4 mandelboxDE(float3 p) { //http://blog.hvidtfeldts.net/index.php/2011/11/distance-estimated-3d-fractals-vi-the-mandelbox/
				int Iterations = _fractalIterations;
				float foldingLimit = _foldingLimit;
				float Scale = _fractalScale;

				float fixedRadius = _fixedRadius;
				float minRadius = _minRadius;
				float fixedRadius2 = fixedRadius*fixedRadius;
				float minRadius2 = minRadius*minRadius;
				float3 z = p;
				float3 offset = z;
				float dr = 1.0;
				float color = -1;
				for (int n = 0; n < Iterations; n++) {
					// Reflect
					z.x = clamp(z.x, -foldingLimit, foldingLimit) * 2.0 - z.x;
					z.y = clamp(z.y, -foldingLimit, foldingLimit) * 2.0 - z.y;
					z.z = clamp(z.z, -foldingLimit, foldingLimit) * 2.0 - z.z;

					float r2 = dot(z,z);
					float temp = 1.0;
					if (r2<minRadius2) { 
						// linear inner scaling
						temp = (fixedRadius2/minRadius2);
					} else if (r2<fixedRadius2) { 
						// this is the actual sphere inversion
						temp =(fixedRadius2/r2);
					}
					z *= temp;
					dr*= temp;
					
					z=Scale*z + offset;  // Scale & Translate
					dr = dr*abs(Scale)+1.0;

					color = (1.0 + float(n)) / float(Iterations + 1);
				}
				float r = length(z);
				return float4((r - _linearDEOffset) / abs(dr), color, -1, -1);
			}

			float4 mandelboxDE2(float3 p) { //http://www.fractalforums.com/programming/performance-for-fps-style-mandelbox-exploration/
				float mr2 = dot(_minRadius, _minRadius);
				float Iterations = _fractalIterations;
				float scalevec = _fractalScale;
				float C1 = abs(_fractalScale - 1.0);
				float C2 = pow(abs(_fractalScale), float(1.0 - _fractalIterations));
				//distance field formula was completely script-kiddied off of fractalforums
				//(knighty and Rrrola are some radical dudes)

				float4 z = float4(p, 1.0);
				float4 offset = z;

				//in this case, this z0 value could be replaced with offset...
				//...but i might play with non-default offsets later
				float3 z0 = z.xyz;

				//orbit trap:
				//square distance from current position to negative starting position,
				//added to current position's square length
				float orbit = dot(z.xyz + z0, z.xyz + z0) + dot(z.xyz, z.xyz);

				for (int i = 0; i<Iterations; i++) {
					//boxfold
					z.xyz = clamp(z.xyz, -1.0, 1.0)*2.0 - z.xyz;
					//spherefold
					z *= clamp(max(mr2 / dot(z.xyz, z.xyz), mr2), 0.0, 1.0);

					//orbit trap
					//performed before scale/offset because...
					//...i dunno, it's prettier
					orbit = min(orbit, dot(z.xyz + z0, z.xyz + z0) + dot(z.xyz, z.xyz));

					//scale+offset
					z = z * scalevec + offset;
				}
				return float4((length(z.xyz) - C1) / z.w - C2, orbit, -1, -1);
			}


			float clamp (float z, float minLim, float maxLim) {
				if (z > maxLim){
					return 1;
				} else if (z < minLim) {
					return -1;
				} else {
					return 0;
				}
			}

			//

			//ESCENES (combinacions de SD/DE)
			float singleSphere(float3 p) {
				float sphere = sdSphere(p, float3(0, 0, 0), 2.0);
				return sphere;
			}

			float infiniteSpheres(float3 p) {
				p = repeatXYZ(p, float3(5.0, 5.0, 5.0));
				float spheres = sdSphere(p, float3(0.0, 0.0, 0.2), 1.0);
				return spheres;
			}

			float infiniteBoxFrames(float3 p) {
				p = repeatXYZ(p, float3(5.0, 5.0, 5.0));
				float boxes = sdBoxFrame(p, float3(0.0, 0.0, 0.0), float3(2.5, 2.5, 2.5), 0.10);
				return boxes;
			}

			float infiniteBoxFramedSpheres(float3 p) {
				p = repeatXYZ(p, float3(5.0, 5.0, 5.0));
				float boxes = sdBoxFrame(p, float3(0.0, 0.0, 0.0), float3(2.5, 2.5, 2.5), 0.10);
				float spheres = sdSphere(p, float3(0.0, 0.0, 0.0), 1.0);
				return unionSDF(boxes, spheres);
			}

			//Esfera amb "forats" a dins fets per capses
			float scene0(float3 p) {
				float boxes1 = sdBox(p, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 2.52));
				float boxes2 = sdBox(p, float3(0.0, 0.0, 0.0), float3(2.52, 1.0, 1.0));
				float spheres = sdSphere(p, float3(0.0, 0.0, 0.0), 2.5);
				float diff = differenceSDF(spheres, boxes1);
				return differenceSDF(diff, boxes2);
			}


			//

			/**********************************************FUNCIONS PRINCIPAL************************************************/
			float4 distanceField(float3 p) {
				float4 scene = float4(0.0, -1.0, -1.0, -1.0);
				switch (_currentScene) {
				case 0:
					scene.x = scene0(p);
					break;
				case 1:
					scene.x = sdCross(p / 2, float3(0.0, 0.0, 0.0), 1.0) * 2;
					break;
				case 2:
					scene.x = mandelbulbDE(p / _fractalScale) * _fractalScale;
					break;
				case 3:
					scene.x = infiniteSpheres(p);
					break;
				case 4:
					scene = infiniteBoxFramedSpheres(p);
					break;
				case 5:
					scene = mengerSpongeDE(p);
					break;
				case 6:
					scene = mengerSpongeCommonDE(p);
					break;
				case 7:
					scene = tetrahedronFractalDE(p);
					break;
				case 8:
					scene = mandelboxDE(p);
					break;
				case 9:
					scene = mandelboxDE2(p / 20.0) * 20.0;
					break;
				case 10:
					scene = tetrahedronFractalDE(p);
					break;
				case 11:
					scene = mandelbulbDE(p / _fractalScale) * _fractalScale;
					break;
				default:
					scene = mandelboxDE(p);
					break;//
				}
				return scene;
			}

			float3 getNormal(float3 p) { //C�lcul normal
				//La gradient del distanceField / distanceEstimator �s la normal en aquell punt
				const float2 offset = float2(0.001, 0.0);

				float3 normal = float3(  //ofset.xyy = (ofset.x, ofset.y, ofset.y)
					distanceField(p + offset.xyy).x - distanceField(p - offset.xyy).x,
					distanceField(p + offset.yxy).x - distanceField(p - offset.yxy).x,
					distanceField(p + offset.yyx).x - distanceField(p - offset.yyx).x);

				return normalize(normal);
			}

			fixed4 getBackgroundColor(float3 ray_origin,float3 ray_direction) {
				//idea: fer intersecci� del raig amb un pla lluny� per poder fer fons fractal 2D? o altre tipus
				float3 color1 = float3(0.5, 0.7, 1);
				float3 color2 = float3(1, 1, 1);
				// TODO: A canviar el càlcul del color en les diferents fases
				float y = 0.5*(ray_direction.y + 1);
				float3 color = (float)y*color1 + (float)(1 - y)*color2;
				return fixed4(color.x, color.y, color.z, 1.0);
			}

			fixed4 blinnPhong(fixed4 color, float3 normal, float3 ray_direction) {
				fixed4 outColor;
				float3 lightAmbient = float3(0.1, 0.1, 0.1);
				float3 lightDiffuse = float3(1.0, 1.0, 1.0);
				float3 lightSpecular = float3(1.0, 1.0, 1.0); 
				float shininess = 10.0;

				float3 V = -ray_direction;
				float3 L = normalize(-_LightDir);

				float H = normalize(V + L);

				float3 ca = (color.xyz / 1.0) * lightAmbient;
				float3 cd = lightDiffuse * color.xyz * max(dot(normal, L), 0.0);
				float3 cs = lightSpecular * color.xyz * pow(max(dot(normal, H), 0.0), shininess)*0.05;

				return fixed4(ca+cd+cs, 1);
			}

			float softShadow(float3 ro, float3 rd, float k ){
				float res = 1.0;
				float t = 0.005; //Distancia viatjada al llarg de la direcci� del raig
				for (int i = 0; i < _numIterations; i++) {
					float h = distanceField(ro + rd*t).x;
					if( h < _shadowEpsilon )
						return 0.0;
					res = min( res, k*h/t );
					t += h;
				}
				return res;
			}

			fixed4 getColor(float3 p, float3 ray_origin, float3 ray_direction, int t, float3 DEColor, int iters) {
				//p: punt
				//t: tal que p = r_o + r_d * t
				//DEColor: arriba directament d'alguns algoritmes de DE

				float3 normal = getNormal(p);
				fixed4 color;
				if (_currentScene == 4 ){ //Escena de boxFrames amb esferes
					if (abs(p.x - 2.5) < 2.5 && abs(p.y - 2.5) < 2.5 && abs(p.z - 2.5) < 2.5){
						color = fixed4(1, 0, 0, 1);
					}
					else {
						if (abs(mod(p.x, 5.0)-2.5) > 2.4) { //les capses
							color = fixed4(mod3(p, float3(5.0, 5.0, 5.0)) / 5.0, 1);
						} 
						else{//esferes
							color = fixed4(ray_direction, 1);
						}
						
					}
					
				}
				else if (_currentScene == 5 || _currentScene == 6) {//MengerSponge
					color = fixed4(DEColor.x, 0, 1 - DEColor.x, 1);
				}
				else if (_currentScene == 8) {//Mandelbox
					color = fixed4(DEColor.x, 0, 1 - DEColor.x, 1);
				}
				else if (_currentScene == 7) {//Sierp. Tetrahedron point color
					color = fixed4(p, 1);
				}
				else if (_currentScene == 9) {//Mandelbox segona implementació
					float ca = 1.0 - float(iters) / float(_numIterations);
					float3 c = float3(ca, ca, ca);
					float orbit = DEColor.x;
					float ct = abs(frac(orbit*1.0) - 0.5)*2.0*0.35 + 0.65;
					float ct2 = abs(frac(orbit*.071) - 0.5)*2.0;
					c *= lerp(fixed3(0.8, 0.7, 0.4)*ct, fixed3(0.7, 0.15, 0.2)*ct, ct2);
					color = fixed4(c, 1);
				}

				else if (_currentScene == 10) {//Sierp. Tetrahedron millora color
					color = fixed4(DEColor.x, DEColor.y, DEColor.z, 1);
				}
				else if (_currentScene == 11) {//MandelBulb millora color
					float index = DEColor.x;
					float n = 2.0;
					color = fixed4(n / (index + n - 1), 2 * n / (index + 2 * n - 1), 3 * n / (index + 3 * n - 1), 1);
					//color.xyz *= normalize(p + normal).xyz;

					//color = fixed4(sqrt(n/(DEColor.x + n - 1 )), 1.0 - sqrt(n/(DEColor.x + n - 1 )), n*3/(DEColor.x + n*3 - 1 ), 1);
				}
				else {
					color = fixed4(ray_direction, 1);
				}

				//Càlcul normal i llum
				if (_enableLight == 1) {
					if (_blinnPhong == 1) {
						color = blinnPhong(color, normal, ray_direction);
					}
					else { //Basic light
						float light = dot(-_LightDir, normal); 
						color *= light;
					} 
				}
				if (_enableShadows) {
					color *= softShadow(p, normalize(-_LightDir), _shadowFactor);
				}
				
				return color;
			}

			fixed4 raymarching(float3 ray_origin, float3 ray_direction)
			{
				fixed4 result = fixed4(1, 1, 1, 1);

				float t = 0; //Distancia viatjada al llarg de la direcci� del raig

				for (int i = 0; i < _numIterations; i++) {
					if (t > _maxDistance) {
						//P�ntem el fons
						result = getBackgroundColor(ray_origin, ray_direction);
						break;
					}

					float3 p = ray_origin + ray_direction * t; //Obtenim el punt actual 
															   //mirem si hi ha hit en el distance field (dist < epsilon)

					float4 distField = distanceField(p); //result.x es la distancia, yzt es el color que arriba de l'escena per alguns mètodes
					float dist = distField.x;
					if (dist < _raymarchEpsilon) {
						fixed4 color = getColor(p, ray_origin, ray_direction, t, distField.yzw, i);
						result = color;
						break;
					}

					t += dist;
				}

				return result;
			}
			/*********************************************************************************************************/
		
			

			/*********************FRAGMENT SHADER***************************/
            fixed4 frag (v2f i) : SV_Target
            {
				float3 rayDirection = normalize(i.ray.xyz);

				float3 rayOrigin = _WorldSpaceCameraPos;

				fixed4 result = raymarching(rayOrigin, rayDirection);

				return result;
            }
            ENDCG
        }
    }
}
