using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private Transform exterior;
        private Transform exteriorAnnex;
        private Transform expansionPlot;
        private Transform expansionPreview;
        private Transform riverbank;
        private Transform seafront;
        private readonly System.Collections.Generic.List<Renderer> roofPanels = new();
        private Transform researchLab;
        private Transform annex;
        private Transform annexHead;
        private Vector3 annexHeadRest;
        private Renderer annexLamp;

        internal void ApplyCampus(bool outside, bool expanded, bool hasLab, HospitalSite site = HospitalSite.Main, bool preview = false)
        {
            bool regional = site != HospitalSite.Main;
            if (expanded && annex == null) BuildAnnex();
            if (outside && exterior == null) BuildExterior();
            root.gameObject.SetActive(!outside);
            if (annex != null) annex.gameObject.SetActive(expanded);
            if (exterior != null)
            {
                exterior.gameObject.SetActive(outside);
                exteriorAnnex.gameObject.SetActive(expanded);
                expansionPlot.gameObject.SetActive(!expanded);
                expansionPreview.gameObject.SetActive(!expanded && preview);
                riverbank.gameObject.SetActive(site == HospitalSite.Riverside);
                seafront.gameObject.SetActive(site == HospitalSite.Coast);
                if (site != roofSite)
                {
                    roofSite = site;
                    var color = site == HospitalSite.Coast ? Coral : regional ? new Color(.27f, .62f, .68f) : Mint;
                    foreach (var roof in roofPanels) roof.material.color = color;
                }
                if (hasLab && researchLab == null) BuildResearchLab();
                if (researchLab != null) researchLab.gameObject.SetActive(hasLab);
            }
            var shift = new Vector3(outside ? (hasLab || regional ? 0f : 2f) : expanded ? 2.65f : 0f, 0, 0);
            Camera.transform.position = new Vector3(11, 18, 20) + shift;
            Camera.orthographicSize = outside ? (hasLab || regional ? 11.1f : 9.8f) : expanded ? 10f : 8.6f;
        }

        internal void SetAnnexActivity(float lift, bool active)
        {
            if (annexHead != null) annexHead.localPosition = annexHeadRest + Vector3.up * (.55f * lift);
            if (annexLamp != null) SetLamp(annexLamp, active);
        }

        private void BuildAnnex()
        {
            annex = Group(root, "치료별관 내부", Vector3.zero);
            var model = UsesOriginalArt ? LoadArt("treatment-annex") : null;
            if (model != null)
            {
                var instance = PlaceArt(model, annex, Vector3.zero, originalArtMirrorsX);
                foreach (Transform part in instance.GetComponentsInChildren<Transform>(true))
                {
                    if (part.name != "TreatmentHead") continue;
                    annexHead = part;
                    annexHeadRest = part.localPosition;
                    break;
                }
            }
            else
            {
                Floor(annex, "치료별관 바닥", 10f, 3f, Mint);
                Couch(annex, "별관 침대", 10f, 3f, Mint);
                Box(annex, "치료기", new Vector3(11.15f, 1, 3), new Vector3(.8f, 2, .9f), Cream);
                Box(annex, "치료 헤드", new Vector3(10.55f, 1.9f, 3), new Vector3(1.2f, .38f, .8f), Coral);
            }
            Box(annex, "연결 통로", new Vector3(7.4f, .01f, 5.48f), new Vector3(3.5f, .08f, 1.6f), Cream);
            annexLamp = Lamp(annex, new Vector3(11.25f, 1.8f, 3.05f));
        }

        private HospitalSite roofSite;

        private void BuildExterior()
        {
            exterior = Group(root.parent, "병원 외부", Vector3.zero);
            Box(exterior, "정원", new Vector3(.5f, -.3f, .5f), new Vector3(25f, .4f, 15f), new Color(.65f, .73f, .48f));
            Box(exterior, "앞뜰 보행로", new Vector3(2, -.03f, 5.05f), new Vector3(18f, .15f, 2.5f), Wood);
            Box(exterior, "본원", new Vector3(0, 2.2f, 0), new Vector3(9, 4.4f, 6), Cream);
            for (int side = -1; side <= 1; side += 2)
            {
                var roof = Shape(exterior, "민트 지붕", PrimitiveType.Cube, new Vector3(side * 2.35f, 4.83f, 0),
                    new Vector3(4.9f, .23f, 6.65f), Mint);
                roofPanels.Add(roof.GetComponent<Renderer>());
                roof.transform.rotation = Quaternion.Euler(0, 0, side * -11f);
                Window(exterior, side * 2.45f, 1.18f, 3.08f);
                Window(exterior, side * 2.45f, 3.31f, 3.08f);
                Plant(exterior, side * 7.8f, 5.1f);
                Shape(exterior, "나무", PrimitiveType.Sphere, new Vector3(side * 7.8f, 2.1f, 5.1f), new Vector3(1.55f, 2.4f, 1.55f), Mint);
                Box(exterior, "외벽 원목 기둥", new Vector3(side * 4.22f, 2.2f, 3.04f), new Vector3(.23f, 4.4f, .22f), Wood);
            }
            Box(exterior, "입구 유리문", new Vector3(0, 1.06f, 3.11f), new Vector3(1.68f, 2.12f, .2f), Mint);
            Box(exterior, "입구 차양", new Vector3(0, 2.39f, 3.54f), new Vector3(2.65f, .23f, 1.38f), Mint);
            Box(exterior, "입구 계단", new Vector3(0, .08f, 3.75f), new Vector3(2.42f, .14f, 1.05f), White);
            var sign = Shape(exterior, "해바라기 입구 간판", PrimitiveType.Sphere, new Vector3(0, 3.43f, 3.21f),
                new Vector3(2.35f, 1.48f, .27f), Cream);
            var badge = Group(sign.transform.parent, "입구 해바라기", new Vector3(0, 3.48f, 3.39f));
            for (int i = 0; i < 8; i++)
            {
                float angle = i * Mathf.PI / 4;
                Shape(badge, "골드 꽃잎", PrimitiveType.Sphere, new Vector3(Mathf.Cos(angle) * .32f, Mathf.Sin(angle) * .32f, 0),
                    new Vector3(.26f, .26f, .1f), new Color(.98f, .70f, .26f));
            }
            Shape(badge, "꽃 중심", PrimitiveType.Sphere, Vector3.forward * .05f, new Vector3(.39f, .39f, .15f), Wood);
            for (int side = -1; side <= 1; side += 2)
            {
                Box(exterior, "현관 난간", new Vector3(side * 1.26f, .58f, 4.31f), new Vector3(.07f, .1f, 1.2f), Wood);
                Box(exterior, "현관 기둥", new Vector3(side * 1.26f, .3f, 4.76f), new Vector3(.09f, .61f, .09f), Wood);
                Box(exterior, "대기 벤치", new Vector3(side * 3.08f, .46f, 4.46f), new Vector3(1.45f, .26f, .53f), Coral);
            }

            expansionPlot = Group(exterior, "치료별관 예정지", new Vector3(7f, 0, 0));
            Box(expansionPlot, "별관 부지", new Vector3(0, -.04f, 0), new Vector3(4.4f, .12f, 5.4f), Wood);
            for (int side = -1; side <= 1; side += 2)
            {
                Box(expansionPlot, "부지 표시", new Vector3(side * 2.1f, .05f, 0), new Vector3(.16f, .12f, 5.3f), Coral);
                Box(expansionPlot, "부지 표시", new Vector3(0, .05f, side * 2.57f), new Vector3(4.3f, .12f, .16f), Coral);
            }

            expansionPreview = Group(expansionPlot, "별관 3D 골조 미리보기", Vector3.zero);
            for (int side = -1; side <= 1; side += 2)
            {
                for (int end = -1; end <= 1; end += 2)
                    Box(expansionPreview, "예상 벽 모서리", new Vector3(side * 1.95f, 1.45f, end * 2.45f),
                        new Vector3(.13f, 2.9f, .13f), Mint);
                Box(expansionPreview, "예상 지붕 경계", new Vector3(side * 2.03f, 2.97f, 0),
                    new Vector3(.15f, .15f, 5.05f), Mint);
                Box(expansionPreview, "예상 지붕 경계", new Vector3(0, 2.97f, side * 2.45f),
                    new Vector3(4.08f, .15f, .15f), Mint);
            }

            riverbank = Group(exterior, "물빛 분원 강변과 정류장", Vector3.zero);
            Box(riverbank, "강물", new Vector3(-9.6f, -.06f, -.5f), new Vector3(4.9f, .11f, 12f), new Color(.43f, .71f, .77f));
            Box(riverbank, "강변 다리", new Vector3(-8.5f, .14f, 1.4f), new Vector3(5f, .30f, 1.65f), Wood);
            Box(riverbank, "정류장 기둥", new Vector3(-5.1f, 1.05f, 4.66f), new Vector3(.13f, 2.1f, .13f), Cream);
            Box(riverbank, "정류장 표지", new Vector3(-5.1f, 2.06f, 4.66f), new Vector3(.7f, .45f, .19f), Coral);
            Box(riverbank, "정류장 벤치", new Vector3(-4.5f, .47f, 5.3f), new Vector3(1.7f, .19f, .51f), Wood);

            seafront = Group(exterior, "해안 산책로", Vector3.zero);
            Box(seafront, "수평선", new Vector3(-7.8f, -.05f, -3.9f), new Vector3(8.4f, .11f, 6f), new Color(.34f, .65f, .76f));
            Box(seafront, "모래 언덕", new Vector3(-8f, .01f, -.8f), new Vector3(8f, .12f, 1.7f), new Color(.92f, .79f, .55f));
            Shape(seafront, "등대 몸체", PrimitiveType.Cylinder, new Vector3(-7.7f, 1.4f, -.9f), new Vector3(1.05f, 1.4f, 1.05f), Cream);
            Shape(seafront, "등대 전망층", PrimitiveType.Cylinder, new Vector3(-7.7f, 2.9f, -.9f), new Vector3(1.25f, .18f, 1.25f), Coral);
            Shape(seafront, "등대 등불", PrimitiveType.Sphere, new Vector3(-7.7f, 3.28f, -.9f), new Vector3(.66f, .67f, .66f), Wood);

            exteriorAnnex = Group(exterior, "치료별관 외부", new Vector3(7f, 0, 0));
            Box(exteriorAnnex, "별관 벽", new Vector3(0, 1.45f, 0), new Vector3(4, 2.9f, 5), Cream);
            Box(exteriorAnnex, "별관 지붕", new Vector3(0, 3.04f, 0), new Vector3(4.4f, .28f, 5.4f), Mint);
            Window(exteriorAnnex, -.9f, 1.55f, 2.58f);
            Window(exteriorAnnex, .85f, 1.55f, 2.58f);
        }

        private void BuildResearchLab()
        {
            var site = new Vector3(-8.2f, 0, -.8f);
            researchLab = Group(exterior, "연구소", site);
            var model = LoadArt("research-lab");
            if (model != null) PlaceArt(model, researchLab, Vector3.zero, originalArtMirrorsX);
            else
            {
                Box(researchLab, "연구소 벽", new Vector3(0, 1.35f, 0), new Vector3(4.6f, 2.7f, 3.9f), Cream);
                Box(researchLab, "코랄 지붕", new Vector3(0, 2.8f, 0), new Vector3(4.9f, .25f, 4.2f), Coral);
            }
            var researcher = LoadArt("researcher");
            if (researcher != null)
                PlacePerson(researcher, researchLab, new Vector3(.75f, .45f, 1f), false, originalArtMirrorsX);
        }

        private void Window(Transform parent, float x, float y, float z)
        {
            Box(parent, "원목 창틀", new Vector3(x, y, z), new Vector3(1.4f, 1.02f, .14f), Wood);
            Box(parent, "창 유리", new Vector3(x, y, z + .08f), new Vector3(1.19f, .81f, .06f), new Color(.48f, .69f, .69f));
            Box(parent, "창살", new Vector3(x, y, z + .13f), new Vector3(.08f, .88f, .04f), White);
        }
    }
}
