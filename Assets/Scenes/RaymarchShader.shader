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
				float2 tmp = mod2(p.xz, factor) - 0.5*factor;
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

				while (n < _fractalIterations) {
					if (p.x + p.y < 0) p.xy = -p.yx; // fold 1
					if (p.x + p.z < 0) p.xz = -p.zx; // fold 2
					if (p.y + p.z < 0) p.zy = -p.yz; // fold 3	
					p = p * Scale - Offset * (Scale - 1.0);
					n++;
				}

				return float4((length(p)) * pow(Scale, -float(n)), -1 , -1, -1);
			}


			float4 mandelbulbDE(float3 pos) { //http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
				int Iterations = _fractalIterations;
				float Bailout = _fractalScapeRatio; //radi escapament
				float Power = _fractalPower; // z_{n+1} = (z_n)^Power + pos

				float3 z = pos;
				float dr = 1.0;
				float r = 0.0;
				for (int i = 0; i < Iterations; i++) {
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
				return float4(0.5*log(r)*r / dr, -1 , -1, -1);
			}

			float4 mengerSpongeDE(float3 p) { // https://www.iquilezles.org/www/articles/menger/menger.htm
				int Iterations = _fractalIterations;
				float Scale = _fractalScale;

				float d = sdBox(p, float3(0.0,0.0,0.0), float3(1.0, 1.0, 1.0) * Scale);

				float s = 1.0;
				for (int m = 0; m<_fractalIterations; m++)
				{
					float3 a = mod3(p*s, float3(2.0, 2.0, 2.0)) - 1.0;
					s *= 3.0;
					float3 r = abs(1.0 - 3.0*abs(a));

					float da = max(r.x, r.y);
					float db = max(r.y, r.z);
					float dc = max(r.z, r.x);
					float c = (min(da, min(db, dc)) - 1.0) / s;

					d = max(d, c);
				}

				return float4(d, -1 , -1 , -1);
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
				}
				float r = length(z);
				return float4((r - _linearDEOffset) / abs(dr), -1 , -1, -1);
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

			//Esferes amb "forats" a dins fets per capses
			float scene1(float3 p) {
				p = repeatXYZ(p, float3(5.0, 5.0, 5.0));
				float boxes1 = sdBox(p, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 2.52));
				float boxes2 = sdBox(p, float3(0.0, 0.0, 0.0), float3(2.52, 1.0, 1.0));
				float spheres = sdSphere(p, float3(0.0, 0.0, 0.0), 2.5);
				float diff = differenceSDF(spheres, boxes1);
				return differenceSDF(diff, boxes2);
			}

			//Fractal Tetrahedre plegant l'espai
			float scene2(float3 p) {
				p = repeatXYZ(p, float3(4.0, 4.0, 4.0));
				return tetrahedronFractalDE_mod1(p);
			}

			float scene3(float3 p) {
				p = repeatXYZ(p, float3(4.0, 4.0, 4.0));
				p = repeatXZ(p, float2(2.0, 2.0));
				return sdSphere(p, float3(0.0, 0.0, 0.0), 1.4);
			}

			//

			/**********************************************FUNCIONS PRINCIPAL************************************************/
			float4 distanceField(float3 p) {
				float4 scene = float4(0.0, -1.0, -1.0, -1.0);
				switch (_currentScene) {
				case 1:
					scene.x = singleSphere(p);
					break;
				case 2:
					scene.x = infiniteSpheres(p);
					break;
				case 3:
					scene.x = infiniteBoxFrames(p);
					break;
				case 4:
					scene = tetrahedronFractalDE(p);
					break;
				case 5:
					scene.x = scene3(p);
					break;
				case 6:
					scene.x = scene1(p);
					break;
				case 7:
					scene = mengerSpongeDE(p);
					break;
				case 8:
					scene = mandelbulbDE(p);
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

			fixed4 getColor(float3 p, float3 ray_origin, float3 ray_direction, int t, float3 DEColor) {
				//p: punt
				//t: tal que p = r_o + r_d * t
				//DEColor: arriba directament d'alguns algoritmes de DE
				fixed4 color;
				if (_currentScene == 3 && abs(p.x - 2.5) < 2.5 && abs(p.y - 2.5) < 2.5 && abs(p.z -2.5) < 2.5) {
					color = fixed4(1, 0, 0, 1);
				}
				else {
					if (DEColor.y > 0) {
						color = fixed4(DEColor, 1);
					}
					else {
						color = fixed4(ray_direction, 1);
					}
					
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
					if (dist < 0.01) {
						float3 normal = getNormal(p);
						float light = dot(-_LightDir, normal);//Lights (si s'expandeix, fer funci� a part millor)
						fixed4 color = getColor(p, ray_origin, ray_direction, t, distField.yzw);
						result = color * light; //Aqu� es determina el color final
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
