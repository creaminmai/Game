using System.Collections.Generic;
using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private readonly List<Mesh> mapSurfaces = new();

        private void BuildMapLandscape(Transform stage)
        {
            Box(stage, "해안 수면", new Vector3(0, -.31f, 0), new Vector3(11.6f, .36f, 7.3f), new Color(.24f, .63f, .70f));
            var shore = new Color(.87f, .75f, .49f);
            var grass = new Color(.58f, .73f, .40f);
            // Opposing bank edges follow the same bend with a navigable gap.
            Land(stage, "본원 내륙", new[]
            {
                new Vector2(1.46f,-3.1f), new Vector2(3.6f,-3.34f), new Vector2(5.13f,-2.86f),
                new Vector2(5.39f,-.84f), new Vector2(5.15f,1.65f), new Vector2(3.62f,2.94f),
                new Vector2(2.47f,2.97f), new Vector2(1.68f,2.14f), new Vector2(1.96f,.88f),
                new Vector2(2.07f,-.58f), new Vector2(1.54f,-1.68f)
            }, grass, shore);
            Land(stage, "강변과 해안이 이어진 반도", new[]
            {
                new Vector2(-4.54f,-1.62f), new Vector2(-3.09f,-2.30f), new Vector2(-1.88f,-2.07f),
                new Vector2(-.46f,-2.70f), new Vector2(.83f,-3.03f), new Vector2(.94f,-1.57f),
                new Vector2(1.46f,-.59f), new Vector2(1.38f,.73f), new Vector2(1.05f,2.06f),
                new Vector2(1.46f,2.90f), new Vector2(-.4f,3.29f), new Vector2(-2.10f,2.62f),
                new Vector2(-2.72f,1.46f), new Vector2(-4.30f,1.22f), new Vector2(-4.83f,.03f)
            }, new Color(.62f, .74f, .43f), shore);

            Vector3[] path =
            {
                new(3.54f,.143f,-.55f), new(2.87f,.143f,.30f), new(2.05f,.23f,.58f),
                new(1.63f,.32f,.61f), new(1.26f,.22f,.64f), new(.60f,.143f,.83f), new(.12f,.143f,.95f),
                new(-.78f,.143f,.42f), new(-1.44f,.143f,.20f), new(-2.12f,.143f,.43f),
                new(-2.75f,.143f,.25f), new(-3.35f,.143f,-.19f)
            };
            MapStripe(stage, "밝은 돌 도로", path, .31f, new Color(.92f, .83f, .63f));
            MapStripe(stage, "연결선", path, .065f, new Color(.99f, .81f, .30f), .012f);
            foreach (int zSign in new[] { -1, 1 })
                MapStripe(stage, "다리 난간", new[]
                {
                    path[2] + new Vector3(0,.11f,zSign*.18f),
                    path[3] + new Vector3(0,.11f,zSign*.18f),
                    path[4] + new Vector3(0,.11f,zSign*.18f)
                }, .046f, Cream);

            (float X, float Z, float Scale)[] trees =
            {
                (4.26f,-2.01f,.54f), (4.70f,-1.62f,.39f), (3.33f,-2.32f,.43f),
                (4.28f,1.54f,.43f), (3.91f,2.12f,.58f), (2.94f,1.90f,.44f),
                (.52f,2.29f,.54f), (-.24f,2.48f,.42f), (-.9f,1.84f,.39f),
                (-.33f,-.75f,.49f), (-.58f,-1.34f,.59f), (-1.22f,-.91f,.38f),
                (-2.94f,1.07f,.45f), (-3.87f,.78f,.50f), (-4.11f,-.74f,.38f)
            };
            for (int i = 0; i < trees.Length; i++)
            {
                var (x,z,scale) = trees[i];
                var shade = i % 4 == 1 ? new Color(.85f,.58f,.56f) : i % 4 == 2 ?
                    new Color(.51f,.68f,.33f) : new Color(.33f,.59f,.30f);
                Shape(stage, "지도 나무 줄기", PrimitiveType.Cylinder, new Vector3(x,.25f,z), new Vector3(.075f,.14f,.075f), Wood);
                Shape(stage, "지도 나무 수관", PrimitiveType.Sphere, new Vector3(x,.37f,z), new Vector3(scale,scale * .91f,scale), shade);
                Shape(stage, "지도 나무 수관", PrimitiveType.Sphere, new Vector3(x+.13f,.46f,z-.07f), new Vector3(scale*.70f,scale*.73f,scale*.76f), shade);
            }
            Shape(stage, "내륙 언덕", PrimitiveType.Sphere, new Vector3(3.36f,.015f,2.21f), new Vector3(2.31f,.94f,1.27f), grass);
            Shape(stage, "강변 언덕", PrimitiveType.Sphere, new Vector3(-.83f,.01f,-1.80f), new Vector3(1.46f,.69f,1.32f), grass);
            for (int i = 0; i < 5; i++)
                Box(stage, "해안 잔물결", new Vector3(-3.3f - i*.31f,-.118f,-2.58f + i*.48f),
                    new Vector3(.22f+(i%2)*.18f,.009f,.027f), new Color(.61f,.86f,.82f));
        }

        private void Land(Transform stage, string name, Vector2[] contour, Color grass, Color sandstone)
        {
            int n = contour.Length;
            Vector2 center = Vector2.zero;
            foreach (Vector2 point in contour) center += point;
            center /= n;
            var vertices = new Vector3[n * 3 + 1];
            var face = new int[n * 3];
            var coast = new int[n * 12];
            vertices[n * 3] = new Vector3(center.x, .127f, center.y);
            for (int i = 0; i < n; i++)
            {
                Vector2 edge = contour[i];
                Vector2 top = Vector2.Lerp(edge, center, .050f);
                vertices[i] = new Vector3(edge.x,-.19f,edge.y);
                vertices[n+i] = new Vector3(edge.x,.042f,edge.y);
                vertices[n*2+i] = new Vector3(top.x,.127f,top.y);
                int next=(i+1)%n;
                face[i*3] = n*3;
                face[i*3+1] = n*2+next;
                face[i*3+2] = n*2+i;
                int cursor=i*12;
                for (int row=0; row<2; row++)
                {
                    int a=row*n+i, b=row*n+next;
                    coast[cursor++] = a;
                    coast[cursor++] = b;
                    coast[cursor++] = a+n;
                    coast[cursor++] = b;
                    coast[cursor++] = b+n;
                    coast[cursor++] = a+n;
                }
            }
            var mesh = new Mesh { name = name, subMeshCount = 2 };
            mesh.vertices = vertices;
            mesh.SetTriangles(face,0);
            mesh.SetTriangles(coast,1);
            mesh.RecalculateNormals();
            var node = Group(stage,name,Vector3.zero).gameObject;
            node.AddComponent<MeshFilter>().sharedMesh = mesh;
            node.AddComponent<MeshRenderer>().sharedMaterials = new[] { MaterialFor(grass), MaterialFor(sandstone) };
            mapSurfaces.Add(mesh);
        }

        private void MapStripe(Transform stage, string name, Vector3[] path, float width, Color color, float lift = 0)
        {
            for (int i=1; i<path.Length; i++)
            {
                Vector3 a=path[i-1], b=path[i];
                var piece=Shape(stage,name,PrimitiveType.Cube,(a+b)/2+Vector3.up*lift,
                    new Vector3(width,.023f,Vector3.Distance(a,b)+width*.36f),color);
                piece.transform.rotation=Quaternion.LookRotation(b-a);
            }
        }
    }
}
