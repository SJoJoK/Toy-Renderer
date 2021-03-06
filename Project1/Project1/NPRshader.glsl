#version 330 core
#define RENDER 0
#define NORMAL 1
#define AO 2
#define ALBEDO 3
#define SPECULAR 4
#define ROUGHNESS 5
#define MODEL 0
struct Material {
    vec3 diffuse;
    vec3 specular;
    float shininess;
    sampler2D texture_diffuse1;
    sampler2D texture_diffuse2;
    sampler2D texture_specular1;
    sampler2D texture_specular2;
    sampler2D texture_normal1;
    sampler2D texture_normal2;
    sampler2D texture_AO1;
    sampler2D texture_AO2;
    sampler2D texture_roughness1;
    sampler2D texture_roughness2;
};
struct DirLight {
    vec3 direction;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};
struct PointLight {
    vec3 position;
    float constant;
    float linear;
    float quadratic;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};
out vec4 FragColor;
in VS_OUT {
    vec3 FragPos;
    vec4 FragPosLightSpace;
    vec2 TexCoord;
    mat3 TBN;
} fs_in;
uniform sampler2D shadowMap;
uniform DirLight dirLight;
uniform PointLight pointLight;
uniform Material material;
uniform bool shadowOn;
uniform bool gammaOn;
uniform bool HDROn;
uniform vec3 viewPos;
uniform int renderMode;
vec3 CalcDirLight(DirLight light, vec3 normal, vec3 viewDir, float shadow);
vec3 CalcPointLight(PointLight light, vec3 normal, vec3 fragPos, vec3 viewDir);
float ShadowCalculation(DirLight dirLight, PointLight pointLight, vec3 normal, vec4 fragPosLightSpace);
void main()
{
    vec3 normal = texture(material.texture_normal1, fs_in.TexCoord).rgb;
    normal = normalize(normal * 2.0 - 1.0);   
    normal = normalize(fs_in.TBN * normal);
    vec3 viewDir = normalize(viewPos-fs_in.FragPos);
    float shadow = 0;
    if(shadowOn)
    {
        shadow = ShadowCalculation(dirLight, pointLight, normal, fs_in.FragPosLightSpace);
    }
    vec3 result = CalcDirLight(dirLight, normal, viewDir, shadow);  
    if(HDROn)
    {
        result = result / (result + vec3(1.0));
    }
    if(gammaOn)
    {
        float gamma = 2.2;
        result.rgb = pow(result.rgb, vec3(1.0/gamma));
    }
    if(renderMode==RENDER)
        FragColor = vec4(result,1.f);
    else if(renderMode==NORMAL)
        FragColor = vec4((normal+1)/2,1.f);
    else if(renderMode==AO)
        FragColor = vec4(texture(material.texture_AO1, fs_in.TexCoord).rrr,1);
    else if(renderMode==ALBEDO)
        FragColor = vec4(texture(material.texture_diffuse1, fs_in.TexCoord).rgb,1);
    else if(renderMode==SPECULAR)
        FragColor = vec4(texture(material.texture_specular1, fs_in.TexCoord).rgb,1);
    else if(renderMode==ROUGHNESS)
        FragColor = vec4(texture(material.texture_roughness1, fs_in.TexCoord).rrr,1);
}
vec3 CalcDirLight(DirLight light, vec3 normal, vec3 viewDir, float shadow)
{
    vec3 lightDir = normalize(-light.direction);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 halfwayDir = normalize(lightDir + viewDir);  
    float spec = pow(max(dot(normal, halfwayDir), 0.0), material.shininess);
    vec3 ambient  = light.ambient  * texture(material.texture_AO1, fs_in.TexCoord).r * vec3(texture(material.texture_diffuse1, fs_in.TexCoord));
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.texture_diffuse1, fs_in.TexCoord));
    vec3 specular = light.specular * spec * vec3(texture(material.texture_specular1, fs_in.TexCoord));
    return (ambient + (1-shadow) * (diffuse + specular));
}
vec3 CalcPointLight(PointLight light, vec3 normal, vec3 fragPos, vec3 viewDir)
{
    vec3 lightDir = normalize(light.position - fragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 halfwayDir = normalize(lightDir + viewDir);  
    float spec = pow(max(dot(normal, halfwayDir), 0.0), material.shininess);
    float distance    = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + 
                 light.quadratic * (distance * distance));    
    vec3 ambient  = light.ambient  * texture(material.texture_AO1, fs_in.TexCoord).r * vec3(texture(material.texture_diffuse1, fs_in.TexCoord));
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.texture_diffuse1, fs_in.TexCoord));
    vec3 specular = light.specular * spec * vec3(texture(material.texture_specular1, fs_in.TexCoord));
    ambient  *= attenuation;
    diffuse  *= attenuation;
    specular *= attenuation;
    return (ambient + diffuse + specular);
}
float ShadowCalculation(DirLight dirLight, PointLight pointLight, vec3 normal, vec4 fragPosLightSpace)
{
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;
    float closestDepth = texture(shadowMap, projCoords.xy).r; 
    float currentDepth = projCoords.z;
    float bias = max(0.05 * (1.0 - dot(normal, -dirLight.direction)), 0.005);
    float shadow = 0.0;
    vec2 texelSize = 1.0 / textureSize(shadowMap, 0);
    for(int x = -1; x <= 1; ++x)
    {
        for(int y = -1; y <= 1; ++y)
        {
            float pcfDepth = texture(shadowMap, projCoords.xy + vec2(x, y) * texelSize).r; 
            shadow += currentDepth - bias > pcfDepth ? 1.0 : 0.0;        
        }    
    }
    shadow /= 9.0;

    return shadow;
}