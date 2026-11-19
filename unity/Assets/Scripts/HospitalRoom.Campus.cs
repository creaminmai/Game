using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private Transform exterior;
        private Transform exteriorAnnex;
        private Transform researchLab;
        private Transform annex;
        private Transform annexHead;
        private Vector3 annexHeadRest;
        private Renderer annexLamp;

        internal void ApplyCampus(bool outside, bool expanded, bool hasLab)
        {
            if (expanded && annex == null) BuildAnnex();
            if (outside && exterior == null) BuildExterior();
            root.gameObject.SetActive(!outside);
            if (annex != null) annex.gameObject.SetActive(expanded);
            if (exterior != null)
            {
                exterior.gameObject.SetActive(outside);
                exteriorAnnex.gameObject.SetActive(expanded);
                if (hasLab && researchLab == null) BuildResearchLab();
                if (researchLab != null) researchLab.gameObject.SetActive(hasLab);
            }
            var shift = new Vector3(outside ? (hasLab ? 0f : 2f) : expanded ? 2.65f : 0f, 0, 0);
            Camera.transform.position = new Vector3(11, 18, 20) + shift;
            Camera.orthographicSize = outside ? (hasLab ? 11.1f : 9.8f) : expanded ? 10f : 8.6f;
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
            Box(exterior, "간판", new Vector3(0, 3.38f, 3.18f), new Vector3(1.48f, .66f, .23f), Coral);

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
