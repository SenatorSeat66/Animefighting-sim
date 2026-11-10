using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
namespace ShadowFighting.Editor
{
    public static class BuildAndroid
    {
        [MenuItem("Shadow Fighting/Build Android APK")]
        public static void Build()
        {
            if(!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android,BuildTarget.Android))
                throw new InvalidOperationException("Install Unity 6 Android Build Support, including its matching SDK, NDK, and JDK.");
            Directory.CreateDirectory("Assets/Scenes"); Directory.CreateDirectory("Builds");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene,"Assets/Scenes/Duel.unity");
            PlayerSettings.companyName="SenatorSeat66"; PlayerSettings.productName="Shadow Fighting";
            PlayerSettings.bundleVersion="0.1.0";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.senatorseat66.shadowfighting");
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetSdkVersion=AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.Android.bundleVersionCode=1;
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.LandscapeLeft;
            PlayerSettings.use32BitDisplayBuffer=true;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,new[]{UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3});
            QualitySettings.vSyncCount=0;
            EditorUserBuildSettings.buildAppBundle=false;
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android,BuildTarget.Android);
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes=new[]{"Assets/Scenes/Duel.unity"},locationPathName="Builds/ShadowFighting.apk",
                target=BuildTarget.Android,options=BuildOptions.None
            });
            if(report.summary.result!=BuildResult.Succeeded) throw new Exception("Android build failed: "+report.summary.result);
            Debug.Log("APK built: "+report.summary.totalSize+" bytes. Device validation and content-size gates are still required.");
        }
    }
    class ArtImport : AssetPostprocessor
    {
        void OnPreprocessTexture()
        {
            if(!assetPath.StartsWith("Assets/Resources/Art/")) return;
            var t=(TextureImporter)assetImporter;t.textureType=TextureImporterType.Default;
            t.maxTextureSize=4096;t.mipmapEnabled=false;t.alphaIsTransparency=true;
            t.textureCompression=TextureImporterCompression.CompressedHQ;
        }
    }
}
