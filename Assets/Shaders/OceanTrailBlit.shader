// Graphics.Blit 전용 유틸 셰이더 (Hidden - 일반 머티리얼 셰이더 목록에 안 뜨게 하려고 "Hidden/" 접두어).
// OceanTrailPainter.cs가 매 프레임 이 셰이더로 핑퐁 RenderTexture 한 쌍을 서로 Blit하면서
//   1) 이전 프레임 내용을 이동체가 움직인 만큼 반대로 밀어서(따라오는 창처럼) 다시 그리고
//   2) 서서히 어둡게 페이드시키고
//   3) 이동체의 현재 위치(텍스처 정중앙)에 새 스탬프(부드러운 원)를 찍는다.
// 결과 텍스처는 R채널 하나만 의미 있는 흑백 마스크(트레일 세기, 0~1)이고, Ocean.shader가 이걸
//   월드 좌표 기준으로 샘플링해서 포말/발광 색을 더하는 데 쓴다.
Shader "Hidden/OceanTrailBlit"
{
    Properties
    {
        _MainTex ("Previous Trail Texture", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float2 _Offset;         // 이번 프레임에 창이 이동한 만큼 = deltaWorld / areaSize (UV 단위)
            float _Fade;            // 이번 프레임에 곱할 감쇠율 (0~1, 1에 가까울수록 안 흐려짐)
            float2 _StampPos;       // 새 스탬프를 찍을 위치 (보통 텍스처 정중앙 0.5,0.5 - 이동체는 항상 창 중앙에 있음)
            float _StampRadius;     // 스탬프 반경 (UV 단위)
            float _StampStrength;   // 스탬프 최대 밝기

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // 1) 이전 텍스처를 반대 방향으로 밀어서 샘플링: 창(텍스처)이 이동체를 따라 옮겨간 것처럼
                //    보이려면, 새 프레임의 uv 위치에서 "이동한 만큼 되짚어 간" 옛 위치의 값을 가져와야 함.
                //    창 밖으로 나가서 정보가 없는 칸은 검은색(0) 처리 - 안 그러면 가장자리 픽셀이
                //    번져(streak) 나오는 아티팩트가 생김.
                float2 sampleUV = i.uv + _Offset;
                float shifted = 0.0;
                if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0)
                {
                    shifted = tex2D(_MainTex, sampleUV).r;
                }

                // 2) 시간에 따라 흐려지게 감쇠
                shifted *= _Fade;

                // 3) 이동체의 현재 위치에 새 스탬프(부드러운 원)를 찍음. max()를 쓰는 이유: 기존 트레일
                //    위에 또 스탬프가 찍혀도 더하기(+)면 계속 밝아져 과포화되는데, max는 "둘 중 밝은 값"만
                //    취해서 한 자리에 오래 머물러도 0~1 범위를 벗어나지 않음.
                float dist = distance(i.uv, _StampPos);
                float stamp = smoothstep(_StampRadius, 0.0, dist) * _StampStrength;

                float result = max(shifted, stamp);
                return float4(result, result, result, 1.0);
            }
            ENDHLSL
        }
    }
}
