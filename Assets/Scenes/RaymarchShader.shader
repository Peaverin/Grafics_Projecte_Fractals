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
			uniform float _maxDistance; //Distància màxima a partir de la qual deixem de calcular el rayMarching
			uniform float3 _LightDir;
			//COSES MENUS:
			uniform float _fractalPower;
			uniform float _fractalScapeRatio;
			uniform int _fractalIterations;
			uniform float _fractalScale;
			uniform float _fractalOffset;
			uniform int _currentScene;

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

			//// TRANSFORMACIONS GEOMÈTRIQUES (http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#constructive-solid-geometry)
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
				//float t = dot(z,n1); if (t<0.0) { z-=2.0*t*n1; }// versió inicial
				p -= 2.0 * min(0.0, dot(p, n)) * n; //versió optimitzada
			}
			/////

			//SIGNED PRIMITIVES. Trobar més a https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
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

			float tetrahedronFractalDE_mod1(float3 p) //Modificat per poder després doblegar el pla (intento)
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


			float tetrahedronFractalDE(float3 p)  //http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
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

				return (length(p)) * pow(Scale, -float(n));
			}


			float mandelbulbDE(float3 pos) { //http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
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
				return 0.5*log(r)*r / dr;
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
			float distanceField(float3 p) {
				float scene;
				switch (_currentScene) {
				case 1:
					scene = singleSphere(p);
					break;
				case 2:
					scene = infiniteSpheres(p);
					break;
				case 3:
					scene = infiniteBoxFrames(p);
					break;
				case 4:
					scene = tetrahedronFractalDE(p);
					break;
				case 5:
					scene = scene3(p);
					break;
				case 6:
					scene = scene1(p);
					break;
				default:
					scene = mandelbulbDE(p);
					break;
				}
				return scene;
			}

			float3 getNormal(float3 p) { //Càlcul normal
				//La gradient del distanceField / distanceEstimator és la normal en aquell punt
				const float2 offset = float2(0.001, 0.0);

				float3 normal = float3(  //ofset.xyy = (ofset.x, ofset.y, ofset.y)
					distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
					distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
					distanceField(p + offset.yyx) - distanceField(p - offset.yyx));

				return normalize(normal);
			}

			fixed4 getBackgroundColor(float3 ray_origin,float3 ray_direction) {
				//idea: fer intersecció del raig amb un pla llunyà per poder fer fons fractal 2D? o altre tipus
				return fixed4(ray_origin, 1);
			}

			fixed4 getColor(float3 p, float3 ray_origin, float3 ray_direction, int t, int MAX_ITERATIONS) {
				fixed4 color;
				if (_currentScene == 3 && abs(p.x - 2.5) < 2.5 && abs(p.y - 2.5) < 2.5 && abs(p.z -2.5) < 2.5) {
					color = fixed4(1, 0, 0, 1);
				}
				else {
					color = fixed4(ray_direction, 1);
				}
				return color;
			}

			fixed4 raymarching(float3 ray_origin, float3 ray_direction)
			{
				fixed4 result = fixed4(1, 1, 1, 1);

				const int MAX_ITERATIONS = 200; //Max iterations del ray marching TODO: posar com a variable (potser no cal)

				float t = 0; //Distancia viatjada al llarg de la direcció del raig

				for (int i = 0; i < MAX_ITERATIONS; i++) {
					if (t > _maxDistance) {
						//Pîntem el fons
						result = getBackgroundColor(ray_origin, ray_direction);
						break;
					}

					float3 p = ray_origin + ray_direction * t; //Obtenim el punt actual 
															   //mirem si hi ha hit en el distance field (dist < epsilon)

					float dist = distanceField(p);
					if (dist < 0.01) {
						float3 normal = getNormal(p);
						float light = dot(-_LightDir, normal);//Lights (si s'expandeix, fer funció a part millor)
						fixed4 color = getColor(p, ray_origin, ray_direction, t, MAX_ITERATIONS);
						result = color * light; //Aquí es determina el color final
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
