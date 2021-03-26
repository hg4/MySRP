using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class Shadows

{
    const string bufferName = "Shadow";
    CommandBuffer _buffer = new CommandBuffer { name = bufferName };
    CullingResults _cullingResults;
    ScriptableRenderContext _context;
    ShadowSettings _shadowSettings;
    public const int maxShadowedDirectionalLightCount = 4,maxCascades = 4;
    public int shadowedDirectionalLightCount;
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float nearPlaneOffset;
    }
    ShadowedDirectionalLight[] _shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];
    public static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
        dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
        dirShadowViewMatricesId = Shader.PropertyToID("_DirectionalShadowViewMatrices"),
        cascadeCountId = Shader.PropertyToID("_CascadeCount"),
        cascadeDataId = Shader.PropertyToID("_CascadeData"),
        shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize"),
        cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
        shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");
    static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };
    static string[] cascadeBlendKeywords = {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };
    public static Vector4[] cascadeData = new Vector4[maxCascades];
    public static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];
    public static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    public static Matrix4x4[] dirShadowViewMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings shadowSettings)
    {
        _cullingResults = cullingResults;
        _context = context;
        _shadowSettings = shadowSettings;
        shadowedDirectionalLightCount = 0;
    }

    public void Render()
    {
        if (shadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
        else
        {
            _buffer.GetTemporaryRT(
                dirShadowAtlasId, 1, 1,
                32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );//for solve webGL texture problem.
        }
    }

    private void RenderDirectionalShadows()
    {
        int atlasSize = (int)_shadowSettings.directional.atlasSize;
        _buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        _buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);//render to render texture
        _buffer.ClearRenderTarget(true, false, Color.clear);//clear after set(reset the renderTarget)
        _buffer.BeginSample(bufferName);
        ExecuteBuffer();
        int tiles = shadowedDirectionalLightCount * _shadowSettings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;
        for (int i = 0; i < shadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }
        float cf = 1f - _shadowSettings.directional.cascadeFade;
        _buffer.SetGlobalVector(shadowDistanceFadeId, new Vector4(1f / _shadowSettings.maxDistance,
            1f / _shadowSettings.distanceFade, 1f / (1f - cf * cf)));
       
        _buffer.SetGlobalInt(cascadeCountId, _shadowSettings.directional.cascadeCount);
        _buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);
        _buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        _buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        _buffer.SetGlobalMatrixArray(dirShadowViewMatricesId, dirShadowViewMatrices);
        SetKeywords(
            directionalFilterKeywords, (int)_shadowSettings.directional.filter - 1
        );
        SetKeywords(
            cascadeBlendKeywords, (int)_shadowSettings.directional.cascadeBlend - 1
        );
        _buffer.SetGlobalVector(
           shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize)
       );
        _buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void SetKeywords(string[] keywords, int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                _buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                _buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }

    //render single light shadow identified by light index
    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        ShadowedDirectionalLight light = _shadowedDirectionalLights[index];
        var shadowSettings =
            new ShadowDrawingSettings(_cullingResults, light.visibleLightIndex);
        int cascadeCount = _shadowSettings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = _shadowSettings.directional.CascadeRatios;
        float cullingFactor =
            Mathf.Max(0f, 0.8f - _shadowSettings.directional.cascadeFade);
        //i: cascade level , index: light index
        for (int i = 0; i < cascadeCount; i++)
        {
            _cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(light.visibleLightIndex, i, cascadeCount, ratios, tileSize, light.nearPlaneOffset,
            out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix, out ShadowSplitData splitData);
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            shadowSettings.splitData = splitData;
            if (index == 0)
            {
                Vector4 cullingSphere = splitData.cullingSphere;
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            int tileIndex = tileOffset + i;
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix,
                SetTileViewport(tileIndex, split, tileSize), split
            );
            dirShadowViewMatrices[tileIndex] = viewMatrix;
            _buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            _buffer.SetGlobalDepthBias(0f, light.slopeScaleBias);
            ExecuteBuffer();
            _context.DrawShadows(ref shadowSettings);
            _buffer.SetGlobalDepthBias(0f, 0f);
            ExecuteBuffer();
        }
       
       
    }

    private void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        float texelSize = 2f * cullingSphere.w / tileSize;
        float filterSize = texelSize * ((float)_shadowSettings.directional.filter + 1f);
        cullingSphere.w -= filterSize;
        cullingSphere.w *= cullingSphere.w;//sum r^2 here
        cascadeCullingSpheres[index] = cullingSphere;
        cascadeData[index] = new Vector4( 1f / cullingSphere.w, filterSize * 1.4142136f);
    }

    //make relation with light and shadow data. 
    public Vector3 ReserveDirectionalShadow(Light light, int visibleLightIndex)
    {
        if (shadowedDirectionalLightCount < maxShadowedDirectionalLightCount &&
            light.shadowStrength > 0.0f && light.shadows != LightShadows.None &&
            _cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            _shadowedDirectionalLights[shadowedDirectionalLightCount] = new ShadowedDirectionalLight() 
            { visibleLightIndex = visibleLightIndex,
                slopeScaleBias = light.shadowBias,
                nearPlaneOffset = light.shadowNearPlane };
            return new Vector4(Math.Max(0.0f, light.shadowStrength), _shadowSettings.directional.cascadeCount * shadowedDirectionalLightCount++,
                light.shadowNormalBias, light.shadowNearPlane);//return shadow strength and shadow index to light.
        }
        return Vector3.zero;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {

        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        //we do matrix convertion here to render all light shadow.
        //Otherwise,we have to set offset and split ,do matrix convertion in shader. 
        float scale = 1f / split;
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);
        _buffer.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
        return offset;
    }

    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    public void CleanUp()
    {
        _buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }
}
