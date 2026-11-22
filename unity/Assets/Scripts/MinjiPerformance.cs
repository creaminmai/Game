using System.Collections.Generic;
using UnityEngine;

namespace SunshineHospital
{
    internal sealed class MinjiPerformance
    {
        private enum Expression { Blink, OpenSmile, Explain, Joy, Worry, Relief }

        private sealed class Face
        {
            internal readonly SkinnedMeshRenderer Renderer;
            internal readonly int[] Indices;
            internal readonly float[] FrameWeights;

            internal Face(SkinnedMeshRenderer renderer)
            {
                Renderer = renderer;
                var names = System.Enum.GetNames(typeof(Expression));
                Indices = new int[names.Length];
                FrameWeights = new float[names.Length];
                for (int i = 0; i < names.Length; i++)
                {
                    int index = Indices[i] = renderer.sharedMesh.GetBlendShapeIndex(names[i]);
                    if (index >= 0) FrameWeights[i] = renderer.sharedMesh.GetBlendShapeFrameWeight(index, 0);
                }
            }
        }

        private readonly struct Joint
        {
            private readonly Transform transform;
            private readonly Quaternion rest;

            internal Joint(Transform transform)
            {
                this.transform = transform;
                rest = transform.localRotation;
            }

            internal void Pose(Vector3 rotation, float blend)
            {
                transform.localRotation = Quaternion.Slerp(transform.localRotation, rest * Quaternion.Euler(rotation), blend);
            }
        }

        private readonly List<Face> face = new();
        private readonly float[] weights = new float[6];
        private readonly float[] target = new float[6];
        private readonly Joint head, torso, upperArm, forearm, hand;
        private string lastPose;
        private float poseTime;
        private float blinkTime;

        internal int ShapeRendererCount => face.Count;

        internal void EndScene() => lastPose = null;

        internal MinjiPerformance(Transform actor)
        {
            var joints = new Dictionary<string, Transform>();
            foreach (var part in actor.GetComponentsInChildren<Transform>(true)) joints[part.name] = part;
            head = new Joint(joints["Head"]);
            torso = new Joint(joints["Torso"]);
            upperArm = new Joint(joints["Arm_L"]);
            forearm = new Joint(joints["Forearm_L"]);
            hand = new Joint(joints["Hand_L"]);
            foreach (var renderer in actor.GetComponentsInChildren<SkinnedMeshRenderer>())
                if (renderer.sharedMesh != null && renderer.sharedMesh.blendShapeCount > 0) face.Add(new Face(renderer));
        }

        internal void Play(string pose, float deltaTime)
        {
            if (lastPose != pose)
            {
                lastPose = pose;
                poseTime = 0;
            }
            poseTime += deltaTime;
            blinkTime = (blinkTime + deltaTime) % 4.6f;
            System.Array.Clear(target, 0, target.Length);
            target[0] = blinkTime > 4.38f ? Mathf.Sin((blinkTime - 4.38f) / .22f * Mathf.PI) * 100 : 0;
            float blend = 1f - Mathf.Exp(-deltaTime * 12f);
            float pitch = 0, tilt = 0, lift = 0, elbow = 0;
            Vector3 wrist = Vector3.zero;
            switch (pose)
            {
                case "greeting":
                    target[(int)Expression.OpenSmile] = 96;
                    tilt = -8;
                    // A single lift, exactly two wrist oscillations, then rest.
                    lift = 75 * Mathf.SmoothStep(0, 1, poseTime / .25f) * (1 - Mathf.SmoothStep(0, 1, (poseTime - 1.28f) / .38f));
                    elbow = lift * .95f;
                    float wave = Mathf.Clamp01((poseTime - .26f) / .90f);
                    wrist = new Vector3(15, -12, -10 + 18 * Mathf.Sin(wave * Mathf.PI * 4) * Mathf.Sin(wave * Mathf.PI));
                    wrist *= lift / 75;
                    break;
                case "explaining":
                    target[(int)Expression.Explain] = 83;
                    tilt = 4;
                    lift = 35;
                    elbow = 43;
                    wrist = new Vector3(-22, 12, -12);
                    break;
                case "joyful":
                    target[(int)Expression.Joy] = 88;
                    pitch = 9 * Mathf.Sin(Mathf.Clamp01(poseTime / .60f) * Mathf.PI);
                    tilt = -5;
                    break;
                case "worried":
                    target[(int)Expression.Worry] = 98;
                    pitch = 9;
                    tilt = 10;
                    break;
                case "relief":
                    target[(int)Expression.Relief] = 86;
                    pitch = 8 * Mathf.Sin(Mathf.Clamp01(poseTime / .55f) * Mathf.PI);
                    tilt = 2;
                    break;
            }
            for (int i = 0; i < weights.Length; i++) weights[i] = Mathf.Lerp(weights[i], target[i], blend);
            // An eye-closure weight takes precedence over simultaneous eye shapes.
            float open = 1 - weights[0] / 100;
            foreach (var mesh in face)
                for (int i = 0; i < weights.Length; i++)
                {
                    if (mesh.Indices[i] < 0) continue;
                    float value = weights[i] * (i == 0 ? 1 : open) / 100;
                    mesh.Renderer.SetBlendShapeWeight(mesh.Indices[i], value * mesh.FrameWeights[i]);
                }
            head.Pose(new Vector3(pitch, 3, tilt), blend);
            torso.Pose(new Vector3(Mathf.Sin(blinkTime * 1.33f) * 1.4f, 0, 0), blend);
            upperArm.Pose(new Vector3(-12 * lift / 75f, 0, lift), blend);
            forearm.Pose(new Vector3(0, 0, elbow), blend);
            hand.Pose(wrist, blend);
        }
    }
}
