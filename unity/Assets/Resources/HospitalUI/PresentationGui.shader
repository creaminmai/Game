Shader "SunshineHospital/PresentationGui"
{
    Properties
    {
        _MainTex ("Camera", 2D) = "black" {}
        _Opacity ("Opacity", Range(0, 1)) = 1
    }
    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _Opacity;

            v2f_img vert(appdata_img input)
            {
                v2f_img output;
                output.pos = UnityObjectToClipPos(input.vertex);
                output.uv = input.texcoord;
                return output;
            }

            half4 frag(v2f_img input) : SV_Target
            {
                half4 color = tex2D(_MainTex, input.uv);
                return half4(color.rgb, color.a * _Opacity);
            }
            ENDCG
        }
    }
}
